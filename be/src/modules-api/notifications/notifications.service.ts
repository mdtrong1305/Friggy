import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from 'src/modules-system/prisma/prisma.service';
import type {
  ListNotificationsQueryDto,
  UpdateNotificationSettingsDto,
} from './dto/notifications.dto';
import type {
  NotificationResponseDto,
  PaginatedNotificationsDto,
  UnreadCountResponseDto,
  MarkAllReadResponseDto,
  NotificationSettingsResponseDto,
} from './dto/notifications-response.dto';
import type { RegisterFcmTokenDto, FcmTokenResponseDto } from './dto/fcm-token.dto';

@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  // ─────────────────────────────────────────────────────────
  // GET / — Danh sách thông báo
  // ─────────────────────────────────────────────────────────

  async findAll(userId: string, query: ListNotificationsQueryDto): Promise<PaginatedNotificationsDto> {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;

    const where: any = { userId, deletedAt: null };
    if (query.isRead !== undefined) where.isRead = query.isRead;

    const [items, total, unreadCount] = await Promise.all([
      this.prisma.notification.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.notification.count({ where }),
      this.prisma.notification.count({ where: { userId, deletedAt: null, isRead: false } }),
    ]);

    return {
      data: items.map(this.mapNotification),
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
      unreadCount,
    };
  }

  // ─────────────────────────────────────────────────────────
  // GET /unread-count — Số chưa đọc
  // ─────────────────────────────────────────────────────────

  async getUnreadCount(userId: string): Promise<UnreadCountResponseDto> {
    const count = await this.prisma.notification.count({
      where: { userId, deletedAt: null, isRead: false },
    });
    return { count };
  }

  // ─────────────────────────────────────────────────────────
  // PATCH /:id/read — Đánh dấu đã đọc
  // ─────────────────────────────────────────────────────────

  async markOneRead(userId: string, id: string): Promise<NotificationResponseDto> {
    const notif = await this.prisma.notification.findFirst({
      where: { id, userId, deletedAt: null },
    });
    if (!notif) throw new NotFoundException('Không tìm thấy thông báo');

    const updated = await this.prisma.notification.update({
      where: { id },
      data: { isRead: true, readAt: new Date() },
    });
    return this.mapNotification(updated);
  }

  // ─────────────────────────────────────────────────────────
  // PATCH /read-all — Đánh dấu tất cả đã đọc
  // ─────────────────────────────────────────────────────────

  async markAllRead(userId: string): Promise<MarkAllReadResponseDto> {
    const result = await this.prisma.notification.updateMany({
      where: { userId, deletedAt: null, isRead: false },
      data: { isRead: true, readAt: new Date() },
    });
    return { updated: result.count };
  }

  // ─────────────────────────────────────────────────────────
  // DELETE /:id — Soft delete
  // ─────────────────────────────────────────────────────────

  async remove(userId: string, id: string): Promise<void> {
    const notif = await this.prisma.notification.findFirst({
      where: { id, userId, deletedAt: null },
    });
    if (!notif) throw new NotFoundException('Không tìm thấy thông báo');

    await this.prisma.notification.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
  }

  // ─────────────────────────────────────────────────────────
  // GET /me/notification-settings — Lấy cài đặt
  // ─────────────────────────────────────────────────────────

  async getNotificationSettings(userId: string): Promise<NotificationSettingsResponseDto> {
    let pref = await this.prisma.userPreference.findUnique({ where: { userId } });

    if (!pref) {
      // Tạo mặc định nếu chưa có
      pref = await this.prisma.userPreference.create({
        data: { id: require('uuid').v4(), userId },
      });
    }

    return {
      pushNotifications: pref.pushNotifications,
      expiryAlert: pref.expiryAlert,
      shoppingReminder: pref.shoppingReminder,
    };
  }

  // ─────────────────────────────────────────────────────────
  // PATCH /me/notification-settings — Cập nhật
  // ─────────────────────────────────────────────────────────

  async updateNotificationSettings(userId: string, dto: UpdateNotificationSettingsDto): Promise<NotificationSettingsResponseDto> {
    const pref = await this.prisma.userPreference.upsert({
      where: { userId },
      create: {
        id: require('uuid').v4(),
        userId,
        pushNotifications: dto.pushNotifications ?? true,
        expiryAlert: dto.expiryAlert ?? true,
        shoppingReminder: dto.shoppingReminder ?? true,
      },
      update: {
        ...(dto.pushNotifications !== undefined && { pushNotifications: dto.pushNotifications }),
        ...(dto.expiryAlert !== undefined && { expiryAlert: dto.expiryAlert }),
        ...(dto.shoppingReminder !== undefined && { shoppingReminder: dto.shoppingReminder }),
      },
    });

    return {
      pushNotifications: pref.pushNotifications,
      expiryAlert: pref.expiryAlert,
      shoppingReminder: pref.shoppingReminder,
    };
  }

  // ─────────────────────────────────────────────────────────
  // HELPER
  // ─────────────────────────────────────────────────────────

  private mapNotification(n: any): NotificationResponseDto {
    return {
      id: n.id,
      type: n.type,
      title: n.title,
      body: n.body,
      isRead: n.isRead,
      readAt: n.readAt?.toISOString() ?? null,
      metadata: n.metadata ?? null,
      createdAt: n.createdAt.toISOString(),
    };
  }

  // ─────────────────────────────────────────────────────────
  // FCM Token Management
  // ─────────────────────────────────────────────────────────

  async registerFcmToken(
    userId: string,
    dto: RegisterFcmTokenDto,
  ): Promise<FcmTokenResponseDto> {
    await this.prisma.userDevice.upsert({
      where: { fcmToken: dto.token },
      create: {
        userId,
        fcmToken: dto.token,
        platform: dto.platform,
        deviceName: dto.deviceName ?? null,
        isActive: true,
      },
      update: {
        userId,         // cập nhật userId nếu token được dùng lại trên device khác
        platform: dto.platform,
        deviceName: dto.deviceName ?? null,
        isActive: true, // kích hoạt lại nếu trước đó bị deactivate
      },
    });
    return { message: 'Đã đăng ký thiết bị thành công' };
  }

  async removeFcmToken(
    userId: string,
    token: string,
  ): Promise<FcmTokenResponseDto> {
    await this.prisma.userDevice.updateMany({
      where: { fcmToken: token, userId },
      data: { isActive: false },
    });
    return { message: 'Đã hủy đăng ký thiết bị' };
  }
}
