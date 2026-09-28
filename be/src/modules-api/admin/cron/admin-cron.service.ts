/**
 * AdminCronService — Xử lý business logic cron job management
 *
 * - getCronJobs(): lấy từ DB + trạng thái live từ SchedulerRegistry
 * - updateCronJob(): update DB + re-register job ngay lập tức
 * - triggerCronJob(): gọi handler thủ công
 */
import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { SchedulerRegistry } from '@nestjs/schedule';
import { PrismaService } from 'src/modules-system/prisma/prisma.service';
import { NotificationCronService } from 'src/modules-api/notifications/notification-cron.service';
import { UpdateCronJobDto } from './dto/admin-cron.dto';

@Injectable()
export class AdminCronService {
  private readonly logger = new Logger(AdminCronService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly schedulerRegistry: SchedulerRegistry,
    private readonly cronService: NotificationCronService,
  ) {}

  // ─────────────────────────────────────────────────────────
  // GET — Danh sách cron jobs (DB + live status)
  // ─────────────────────────────────────────────────────────
  async getCronJobs() {
    const configs = await this.prisma.cronJobConfig.findMany({
      orderBy: { id: 'asc' },
    });

    return configs.map((config) => {
      // Kiểm tra job có đang chạy trong SchedulerRegistry không
      let isRunning = false;
      try {
        const job = this.schedulerRegistry.getCronJob(config.name);
        isRunning = job != null;
      } catch {
        /* job không tồn tại */
      }

      return {
        name: config.name,
        cronExpression: config.cronExpression,
        isEnabled: config.isEnabled,
        isRunning,
        description: config.description,
        lastRunAt: config.lastRunAt?.toISOString() ?? null,
        lastRunStatus: config.lastRunStatus ?? null,
        updatedAt: config.updatedAt.toISOString(),
      };
    });
  }

  // ─────────────────────────────────────────────────────────
  // PATCH — Cập nhật schedule / bật tắt → re-register ngay
  // ─────────────────────────────────────────────────────────
  async updateCronJob(name: string, dto: UpdateCronJobDto) {
    const config = await this.prisma.cronJobConfig.findUnique({
      where: { name },
    });
    if (!config)
      throw new NotFoundException(`Cron job "${name}" không tồn tại`);

    const newExpression = dto.cronExpression ?? config.cronExpression;
    const newEnabled = dto.isEnabled ?? config.isEnabled;

    // Cập nhật DB
    const updated = await this.prisma.cronJobConfig.update({
      where: { name },
      data: {
        cronExpression: newExpression,
        isEnabled: newEnabled,
      },
    });

    // Re-register job ngay lập tức
    if (newEnabled) {
      this.cronService.registerJob(name, newExpression);
      this.logger.log(
        `🔄 Cron [${name}] đã cập nhật → schedule: ${newExpression}`,
      );
    } else {
      this.cronService.unregisterJob(name);
      this.logger.log(`🛑 Cron [${name}] đã bị tắt`);
    }

    return {
      name: updated.name,
      cronExpression: updated.cronExpression,
      isEnabled: updated.isEnabled,
      message: newEnabled
        ? `Cron [${name}] đang chạy với schedule: ${newExpression}`
        : `Cron [${name}] đã bị tắt`,
    };
  }

  // ─────────────────────────────────────────────────────────
  // POST /:name/trigger — Chạy thủ công ngay
  // ─────────────────────────────────────────────────────────
  async triggerCronJob(name: string) {
    const config = await this.prisma.cronJobConfig.findUnique({
      where: { name },
    });
    if (!config)
      throw new NotFoundException(`Cron job "${name}" không tồn tại`);

    this.logger.log(`🚀 [Admin] Trigger thủ công cron: ${name}`);
    const result = await this.cronService.triggerJob(name);

    return result;
  }
}
