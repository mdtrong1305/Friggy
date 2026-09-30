/**
 * FcmService — Firebase Cloud Messaging
 *
 * Gửi push notification đến thiết bị mobile qua Firebase Admin SDK.
 * - sendToUser(): gửi tất cả devices active của 1 user
 * - sendToMultipleDevices(): multicast (tối đa 500 tokens)
 * - Auto cleanup token stale khi FCM báo invalid
 */
import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { initializeApp, getApps, cert } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import type { ServiceAccount } from 'firebase-admin/app';
import { PrismaService } from '../prisma/prisma.service';
import { FIREBASE_SERVICE_ACCOUNT_JSON } from 'src/common/constants/app.constant';

export interface FcmPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
  imageUrl?: string;
}

@Injectable()
export class FcmService implements OnModuleInit {
  private readonly logger = new Logger(FcmService.name);
  private initialized = false;

  constructor(private readonly prisma: PrismaService) {}

  onModuleInit() {
    if (!FIREBASE_SERVICE_ACCOUNT_JSON) {
      this.logger.warn('⚠️ FIREBASE_SERVICE_ACCOUNT_JSON chưa được cấu hình — FCM bị vô hiệu hoá');
      return;
    }

    try {
      const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON) as ServiceAccount;
      if (!getApps().length) {
        initializeApp({ credential: cert(serviceAccount) });
      }
      this.initialized = true;
      this.logger.log('✅ Firebase Admin SDK đã khởi tạo thành công');
    } catch (err) {
      this.logger.error(`❌ Lỗi khởi tạo Firebase Admin SDK: ${(err as Error).message}`);
    }
  }

  // ─────────────────────────────────────────────────────────
  // Gửi notification cho tất cả devices active của 1 user
  // ─────────────────────────────────────────────────────────

  async sendToUser(userId: string, payload: FcmPayload): Promise<void> {
    if (!this.initialized) return;

    const devices = await this.prisma.userDevice.findMany({
      where: { userId, isActive: true },
      select: { id: true, fcmToken: true },
    });

    if (devices.length === 0) return;

    const tokens = devices.map((d) => d.fcmToken);
    await this.sendToMultipleDevices(tokens, payload);
  }

  // ─────────────────────────────────────────────────────────
  // Multicast — gửi cho nhiều tokens cùng lúc (tối đa 500)
  // ─────────────────────────────────────────────────────────

  async sendToMultipleDevices(fcmTokens: string[], payload: FcmPayload): Promise<void> {
    if (!this.initialized || fcmTokens.length === 0) return;

    // Chia batch tối đa 500 token/lần (giới hạn FCM)
    const chunks = this.chunkArray(fcmTokens, 500);

    for (const chunk of chunks) {
      try {
        const response = await getMessaging().sendEachForMulticast({
          tokens: chunk,
          notification: {
            title: payload.title,
            body: payload.body,
            imageUrl: payload.imageUrl,
          },
          data: payload.data,
          android: { priority: 'high' },
          apns: {
            payload: { aps: { sound: 'default', badge: 1 } },
          },
        });

        // Cleanup stale tokens
        const staleTokens: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            const code = resp.error?.code ?? '';
            if (
              code === 'messaging/registration-token-not-registered' ||
              code === 'messaging/invalid-registration-token'
            ) {
              staleTokens.push(chunk[idx]);
            }
          }
        });

        if (staleTokens.length > 0) {
          await this.deactivateStaleTokens(staleTokens);
        }

        this.logger.log(
          `📤 FCM: ${response.successCount} thành công, ${response.failureCount} thất bại`,
        );
      } catch (err) {
        this.logger.error(`❌ FCM multicast lỗi: ${(err as Error).message}`);
      }
    }
  }

  // ─────────────────────────────────────────────────────────
  // Đánh dấu token stale → isActive = false
  // ─────────────────────────────────────────────────────────

  private async deactivateStaleTokens(tokens: string[]): Promise<void> {
    await this.prisma.userDevice.updateMany({
      where: { fcmToken: { in: tokens } },
      data: { isActive: false },
    });
    this.logger.warn(`🗑️ Đã deactivate ${tokens.length} FCM token stale`);
  }

  // ─────────────────────────────────────────────────────────
  // Helper: chia mảng thành chunks
  // ─────────────────────────────────────────────────────────

  private chunkArray<T>(arr: T[], size: number): T[][] {
    const chunks: T[][] = [];
    for (let i = 0; i < arr.length; i += size) {
      chunks.push(arr.slice(i, i + size));
    }
    return chunks;
  }
}
