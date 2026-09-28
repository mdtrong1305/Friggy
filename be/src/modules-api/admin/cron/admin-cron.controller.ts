/**
 * AdminCronController — Quản lý Cron Jobs động
 *
 * Prefix: /api/v1/admin/cron-jobs
 * Auth: Admin only
 */
import { Controller, Get, Patch, Post, Param, Body } from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiParam,
} from '@nestjs/swagger';
import { Roles } from 'src/common/decorators/roles.decorator';
import { AdminCronService } from './admin-cron.service';
import { UpdateCronJobDto } from './dto/admin-cron.dto';
import { CronJobDto, CronJobUpdateResponseDto } from './dto/admin-cron-response.dto';

@ApiTags('Admin / Cron')
@ApiBearerAuth('access-token')
@Roles('admin')
@Controller('admin/cron-jobs')
export class AdminCronController {
  constructor(private readonly adminCronService: AdminCronService) {}

  // ─────────────────────────────────────────────────────────
  // GET /admin/cron-jobs — Danh sách cron jobs
  // ─────────────────────────────────────────────────────────

  @Get()
  @ApiOperation({
    summary: '[Admin] Danh sách cron jobs',
    description:
      'Xem tất cả cron jobs, schedule, trạng thái bật/tắt, lần chạy cuối.',
  })
  @ApiResponse({ status: 200, type: [CronJobDto] })
  async getCronJobs(): Promise<CronJobDto[]> {
    return this.adminCronService.getCronJobs();
  }

  // ─────────────────────────────────────────────────────────
  // PATCH /admin/cron-jobs/:name — Cập nhật schedule / bật tắt
  // ─────────────────────────────────────────────────────────

  @Patch(':name')
  @ApiOperation({
    summary: '[Admin] Cập nhật cron job',
    description:
      'Thay đổi cronExpression hoặc bật/tắt job. Có hiệu lực ngay, không cần restart.',
  })
  @ApiParam({
    name: 'name',
    description: 'Tên cron job: expiry_warning | weekly_plan_remind | subscription_renewal_reminder',
  })
  @ApiResponse({ status: 200, type: CronJobUpdateResponseDto })
  @ApiResponse({ status: 404, description: 'Không tìm thấy cron job' })
  async updateCronJob(
    @Param('name') name: string,
    @Body() dto: UpdateCronJobDto,
  ) {
    return this.adminCronService.updateCronJob(name, dto);
  }

  // ─────────────────────────────────────────────────────────
  // POST /admin/cron-jobs/:name/trigger — Chạy thủ công
  // ─────────────────────────────────────────────────────────

  @Post(':name/trigger')
  @ApiOperation({
    summary: '[Admin] Trigger cron job thủ công',
    description:
      'Chạy ngay một cron job mà không cần chờ đến lịch. Dùng để test.',
  })
  @ApiParam({ name: 'name', description: 'Tên cron job cần trigger' })
  @ApiResponse({ status: 200, description: 'Kết quả thực thi' })
  async triggerCronJob(@Param('name') name: string) {
    return this.adminCronService.triggerCronJob(name);
  }
}
