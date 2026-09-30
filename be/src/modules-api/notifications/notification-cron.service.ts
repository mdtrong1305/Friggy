/**
 * NotificationCronService — Dynamic Cron Job Manager
 *
 * Load cron configs từ DB khi khởi động → đăng ký dynamic jobs via SchedulerRegistry
 * Admin có thể thay đổi schedule / bật tắt / trigger thủ công qua API — không cần restart.
 *
 * Cron Jobs:
 *   - expiry_warning     (default: 0 8 * * *)  — Cảnh báo nguyên liệu sắp hết hạn
 *   - weekly_plan_remind (default: 0 9 * * 0)  — Nhắc lập thực đơn tuần mới
 */
import { Injectable, Logger, OnModuleInit, Inject } from '@nestjs/common';
import { SchedulerRegistry } from '@nestjs/schedule';
import { CronJob } from 'cron';
import { PrismaService } from 'src/modules-system/prisma/prisma.service';
import { FcmService } from 'src/modules-system/fcm/fcm.service';
import type { ClientProxy } from '@nestjs/microservices';

// ─── Tên cron job (phải khớp với seed data trong DB) ──────────────────
export const CRON_EXPIRY_WARNING = 'expiry_warning';
export const CRON_WEEKLY_REMIND = 'weekly_plan_remind';
export const CRON_SUBSCRIPTION_REMINDER = 'subscription_renewal_reminder';

// ─── Mặc định nếu DB chưa có seed ─────────────────────────────────────────
const DEFAULT_CRON_CONFIGS = [
  {
    name: CRON_EXPIRY_WARNING,
    cronExpression: '0 8 * * *',
    isEnabled: true,
    description: 'Cảnh báo nguyên liệu sắp hết hạn — hàng ngày 8:00',
  },
  {
    name: CRON_WEEKLY_REMIND,
    cronExpression: '0 9 * * 0',
    isEnabled: true,
    description: 'Nhắc lập thực đơn tuần mới — Chủ Nhật 9:00',
  },
  {
    name: CRON_SUBSCRIPTION_REMINDER,
    cronExpression: '0 9 * * *',
    isEnabled: true,
    description: 'Nhắc gia hạn gói có phí — hàng ngày 9:00 (gửi email nếu còn 7 ngày)',
  },
];

@Injectable()
export class NotificationCronService implements OnModuleInit {
  private readonly logger = new Logger(NotificationCronService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly schedulerRegistry: SchedulerRegistry,
    private readonly fcmService: FcmService,
    @Inject('EMAIL_SERVICE') private readonly emailClient: ClientProxy,
  ) {}

  // ─────────────────────────────────────────────────────────
  // Khởi động: seed defaults + đăng ký tất cả dynamic jobs
  // ─────────────────────────────────────────────────────────
  async onModuleInit() {
    try {
      await this.seedDefaultConfigs();
      await this.registerAllJobs();
    } catch (err) {
      this.logger.error(`⚠️ Khởi tạo cron service thất bại (sẽ tiếp tục chạy): ${(err as Error)?.message}`);
    }
  }

  /** Seed các config mặc định nếu DB chưa có, retry nếu pool chưa sẵn sàng */
  private async seedDefaultConfigs(retries = 3, delayMs = 3000) {
    for (let attempt = 1; attempt <= retries; attempt++) {
      try {
        for (const config of DEFAULT_CRON_CONFIGS) {
          await this.prisma.cronJobConfig.upsert({
            where: { name: config.name },
            create: config,
            update: {}, // Không ghi đè nếu đã tồn tại (admin có thể đã sửa)
          });
        }
        return; // thành công
      } catch (err) {
        this.logger.warn(`⏳ Seed cron configs attempt ${attempt}/${retries} failed, retry sau ${delayMs}ms...`);
        if (attempt === retries) throw err;
        await new Promise((r) => setTimeout(r, delayMs));
        delayMs *= 2; // exponential backoff
      }
    }
  }

  /** Load tất cả configs từ DB và đăng ký vào SchedulerRegistry */
  private async registerAllJobs() {
    const configs = await this.prisma.cronJobConfig.findMany();

    for (const config of configs) {
      if (config.isEnabled) {
        this.registerJob(config.name, config.cronExpression);
      }
    }

    this.logger.log(
      `✅ Đã đăng ký ${configs.filter((c) => c.isEnabled).length}/${configs.length} cron jobs`,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Public: đăng ký / hủy 1 job (dùng bởi Admin service)
  // ─────────────────────────────────────────────────────────

  registerJob(name: string, cronExpression: string) {
    // Xóa job cũ nếu đang chạy
    try {
      this.schedulerRegistry.deleteCronJob(name);
    } catch { /* chưa có job — bỏ qua */ }

    const handler = this.getHandler(name);
    if (!handler) {
      this.logger.warn(`⚠️ Không có handler cho cron: ${name}`);
      return;
    }

    const job = new CronJob(cronExpression, () => {
      handler().catch((err) =>
        this.logger.error(`❌ Cron [${name}] lỗi: ${err?.message}`),
      );
    });

    this.schedulerRegistry.addCronJob(name, job as any);
    job.start();

    this.logger.log(`⏰ Đã đăng ký cron [${name}] với schedule: ${cronExpression}`);
  }

  unregisterJob(name: string) {
    try {
      this.schedulerRegistry.deleteCronJob(name);
      this.logger.log(`🛑 Đã hủy cron [${name}]`);
    } catch { /* job không tồn tại — bỏ qua */ }
  }

  /** Trigger 1 job thủ công ngay lập tức */
  async triggerJob(name: string): Promise<{ success: boolean; message: string }> {
    const handler = this.getHandler(name);
    if (!handler) {
      return { success: false, message: `Không có handler cho cron: ${name}` };
    }

    try {
      await handler();
      return { success: true, message: `Cron [${name}] đã chạy thủ công thành công` };
    } catch (err: any) {
      return { success: false, message: err?.message ?? 'Lỗi không xác định' };
    }
  }

  // ─────────────────────────────────────────────────────────
  // Map tên job → handler function
  // ─────────────────────────────────────────────────────────
  private getHandler(name: string): (() => Promise<void>) | null {
    switch (name) {
      case CRON_EXPIRY_WARNING:
        return () => this.checkExpiringItems();
      case CRON_WEEKLY_REMIND:
        return () => this.remindWeeklyPlan();
      case CRON_SUBSCRIPTION_REMINDER:
        return () => this.sendSubscriptionRenewalReminders();
      default:
        return null;
    }
  }

  // ─────────────────────────────────────────────────────────
  // Handler 1: Cảnh báo nguyên liệu sắp hết hạn
  // Default: hàng ngày 8:00 AM
  // ─────────────────────────────────────────────────────────
  async checkExpiringItems(): Promise<void> {
    const jobName = CRON_EXPIRY_WARNING;
    this.logger.log(`🔔 [Cron:${jobName}] Bắt đầu kiểm tra nguyên liệu sắp hết hạn`);

    const withinDays = 3;
    const thresholdDate = new Date();
    thresholdDate.setDate(thresholdDate.getDate() + withinDays);

    // Tìm nguyên liệu sắp hết hạn, group theo userId
    const expiringItems = await this.prisma.fridgeItem.findMany({
      where: {
        expiresAt: { lte: thresholdDate, gte: new Date() },
        deletedAt: null,
      },
      select: {
        userId: true,
        ingredient: { select: { name: true } },
        expiresAt: true,
      },
    });

    if (expiringItems.length === 0) {
      this.logger.log(`✅ [Cron:${jobName}] Không có nguyên liệu sắp hết hạn`);
      await this.updateLastRun(jobName, 'success');
      return;
    }

    // Group theo userId
    const byUser = new Map<string, string[]>();
    for (const item of expiringItems) {
      const list = byUser.get(item.userId) ?? [];
      list.push(item.ingredient.name);
      byUser.set(item.userId, list);
    }

    // Ngày hôm nay để check duplicate
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    let notifCreated = 0;

    for (const [userId, items] of byUser.entries()) {
      // Tránh duplicate — kiểm tra đã có notification hôm nay chưa
      const alreadySent = await this.prisma.notification.findFirst({
        where: {
          userId,
          type: 'expiry_warning',
          createdAt: { gte: todayStart },
          deletedAt: null,
        },
      });

      if (alreadySent) continue;

      // Tạo notification
      const count = items.length;
      const preview = items.slice(0, 3).join(', ');
      const suffix = count > 3 ? ` và ${count - 3} mặt hàng khác` : '';

      await this.prisma.notification.create({
        data: {
          userId,
          type: 'expiry_warning',
          title: `⚠️ Có ${count} nguyên liệu sắp hết hạn`,
          body: `${preview}${suffix} sẽ hết hạn trong ${withinDays} ngày. Lên thực đơn ngay để tránh lãng phí!`,
          metadata: { items, withinDays },
        },
      });

      // ── Gửi FCM push notification ────────────────────────────
      await this.fcmService.sendToUser(userId, {
        title: `⚠️ Có ${count} nguyên liệu sắp hết hạn`,
        body: `${preview}${suffix} sẽ hết hạn trong ${withinDays} ngày`,
        data: { type: 'expiry_warning', screen: 'fridge' },
      });

      notifCreated++;
    }

    this.logger.log(`✅ [Cron:${jobName}] Đã tạo ${notifCreated} notifications`);
    await this.updateLastRun(jobName, 'success');
  }

  // ─────────────────────────────────────────────────────────
  // Handler 2: Nhắc lập thực đơn tuần mới
  // Default: Chủ Nhật 9:00 AM (0 9 * * 0)
  // ─────────────────────────────────────────────────────────
  async remindWeeklyPlan(): Promise<void> {
    const jobName = CRON_WEEKLY_REMIND;
    this.logger.log(`📅 [Cron:${jobName}] Bắt đầu kiểm tra thực đơn tuần`);

    // Tính thứ 2 của tuần tới
    const today = new Date();
    const daysUntilMonday = (8 - today.getDay()) % 7 || 7;
    const nextMonday = new Date(today);
    nextMonday.setDate(today.getDate() + daysUntilMonday);
    nextMonday.setHours(0, 0, 0, 0);
    const weekStartDate = nextMonday.toISOString().split('T')[0];

    // Tìm users active subscription (không phải free — free aiUsagePerWeek = 2)
    const activeUsers = await this.prisma.userSubscription.findMany({
      where: {
        status: 'active',
        endDate: { gte: new Date() },
      },
      select: { userId: true },
    });

    let notifCreated = 0;

    for (const { userId } of activeUsers) {
      // Kiểm tra đã có plan tuần tới chưa
      const hasplan = await this.prisma.weeklyPlan.findFirst({
        where: {
          userId,
          weekStartDate: nextMonday,
          deletedAt: null,
        },
      });

      if (hasplan) continue;

      // Kiểm tra đã nhắc tuần này chưa
      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);
      const alreadySent = await this.prisma.notification.findFirst({
        where: {
          userId,
          type: 'plan_ready',
          createdAt: { gte: todayStart },
          deletedAt: null,
        },
      });

      if (alreadySent) continue;

      await this.prisma.notification.create({
        data: {
          userId,
          type: 'plan_ready',
          title: '📅 Tuần mới sắp tới!',
          body: 'Bạn chưa lên thực đơn cho tuần tới. Để Friggy AI lập thực đơn ngay nhé!',
          metadata: { weekStartDate },
        },
      });

      // ── Gửi FCM push notification ────────────────────────────
      await this.fcmService.sendToUser(userId, {
        title: '📅 Tuần mới sắp tới!',
        body: 'Bạn chưa lên thực đơn cho tuần tới. Để Friggy AI lập thực đơn ngay nhé!',
        data: { type: 'weekly_remind', screen: 'meal_planning' },
      });

      notifCreated++;
    }

    this.logger.log(`✅ [Cron:${jobName}] Đã tạo ${notifCreated} reminders`);
    await this.updateLastRun(jobName, 'success');
  }

  // ─────────────────────────────────────────────────────────
  // Helper: cập nhật lastRunAt + lastRunStatus sau mỗi lần chạy
  // ─────────────────────────────────────────────────────────
  private async updateLastRun(name: string, status: 'success' | 'failed') {
    await this.prisma.cronJobConfig.update({
      where: { name },
      data: { lastRunAt: new Date(), lastRunStatus: status },
    });
  }

  // ─────────────────────────────────────────────────────────
  // Handler 3: Nhắc gia hạn + hạ cấp gói hết hạn
  // Default: hàng ngày 9:00 AM
  // ─────────────────────────────────────────────────────────
  async sendSubscriptionRenewalReminders(): Promise<void> {
    const jobName = CRON_SUBSCRIPTION_REMINDER;
    this.logger.log(`[Cron:${jobName}] Bắt đầu kiểm tra gói sắp hết hạn`);

    const now = new Date();
    // Chỉ lấy đúng ngày hôm nay + 7 (cả ngày) để tránh bỏ sót
    const startOf7Days = new Date(now);
    startOf7Days.setDate(startOf7Days.getDate() + 7);
    startOf7Days.setHours(0, 0, 0, 0);

    const endOf7Days = new Date(startOf7Days);
    endOf7Days.setHours(23, 59, 59, 999);

    try {
      // ── 1. Nhắc user có autoRenew=true (sắp bị trừ tiền) ─────────────
      // Theo plan: "Tìm subscription có endDate = hôm nay + 7 ngày VÀ autoRenew = true"
      const autoRenewSubs = await this.prisma.userSubscription.findMany({
        where: {
          status: 'active',
          autoRenew: true,
          endDate: { gte: startOf7Days, lte: endOf7Days },
          plan: { name: { not: 'free' } },
          deletedAt: null,
        },
        include: { user: true, plan: true },
      });

      // ── 2. Nhắc user có autoRenew=false (gói sắp hết, sẽ về Free) ─────
      const cancelledSubs = await this.prisma.userSubscription.findMany({
        where: {
          status: 'active',
          autoRenew: false,
          endDate: { gte: startOf7Days, lte: endOf7Days },
          plan: { name: { not: 'free' } },
          deletedAt: null,
        },
        include: { user: true, plan: true },
      });

      const allSubs = [...autoRenewSubs, ...cancelledSubs];
      let emailSent = 0;
      let notifCreated = 0;

      for (const sub of allSubs) {
        if (!sub.endDate) continue;

        const isAutoRenew = sub.autoRenew;
        const bodyText = isAutoRenew
          ? `Gói ${sub.plan.displayName} sẽ tự động gia hạn vào ${sub.endDate.toLocaleDateString('vi-VN')}. Kiểm tra thanh toán để tránh gián đoạn.`
          : `Gói ${sub.plan.displayName} sẽ hết hạn vào ${sub.endDate.toLocaleDateString('vi-VN')}. Gia hạn để tiếp tục sử dụng đầy đủ tính năng.`;

        // Gửi email
        if (sub.user.email) {
          this.emailClient.emit('email.send', {
            type: 'subscription_reminder',
            to: sub.user.email,
            data: {
              name: sub.user.name ?? 'bạn',
              planName: sub.plan.displayName,
              endDate: sub.endDate.toISOString(),
            },
          });
          emailSent++;
        }

        // Tạo in-app Notification trong DB
        await this.prisma.notification.create({
          data: {
            userId: sub.userId,
            type: 'subscription_reminder',
            title: `Gói ${sub.plan.displayName} sắp hết hạn`,
            body: bodyText,
            isRead: false,
            metadata: {
              planId: sub.planId,
              endDate: sub.endDate.toISOString(),
              autoRenew: isAutoRenew,
            },
          },
        });

        // ── Gửi FCM push notification ────────────────────────
        await this.fcmService.sendToUser(sub.userId, {
          title: `💳 Gói ${sub.plan.displayName} sắp hết hạn`,
          body: bodyText,
          data: { type: 'subscription_reminder', screen: 'subscription' },
        });

        notifCreated++;
      }

      // ── 3. Hạ cấp về Free các gói đã hết hạn (autoRenew=false) ────────
      const expiredSubs = await this.prisma.userSubscription.findMany({
        where: {
          status: 'active',
          autoRenew: false,
          endDate: { lt: now },
          plan: { name: { not: 'free' } },
          deletedAt: null,
        },
        include: { plan: true },
      });

      const freePlan = await this.prisma.subscriptionPlan.findFirst({
        where: { name: 'free', isActive: true },
      });

      let downgraded = 0;
      if (freePlan) {
        for (const sub of expiredSubs) {
          await this.prisma.userSubscription.update({
            where: { id: sub.id },
            data: { planId: freePlan.id, status: 'active', endDate: null, autoRenew: false },
          });
          downgraded++;
          this.logger.log(`Hạ cấp userId=${sub.userId} từ ${sub.plan.name} → free`);
        }
      }

      this.logger.log(
        `[Cron:${jobName}] Gửi ${emailSent} email, tạo ${notifCreated} notifications, hạ cấp ${downgraded} gói hết hạn`,
      );
      await this.updateLastRun(jobName, 'success');
    } catch (err: any) {
      this.logger.error(`[Cron:${jobName}] Lỗi: ${err?.message}`);
      await this.updateLastRun(jobName, 'failed');
    }
  }
}
