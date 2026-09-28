import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CronJobDto {
  @ApiProperty({ example: 'expiry_warning' }) name!: string;
  @ApiProperty({ example: '0 8 * * *' }) cronExpression!: string;
  @ApiProperty({ example: true }) isEnabled!: boolean;
  @ApiProperty({ example: true, description: 'Job có đang register trong SchedulerRegistry không' }) isRunning!: boolean;
  @ApiPropertyOptional({ example: 'Cảnh báo nguyên liệu sắp hết hạn' }) description!: string | null;
  @ApiPropertyOptional({ example: '2026-09-28T10:00:00Z' }) lastRunAt!: string | null;
  @ApiPropertyOptional({ example: 'success', enum: ['success', 'failed'] }) lastRunStatus!: string | null;
  @ApiProperty({ example: '2026-09-28T08:00:00Z' }) updatedAt!: string;
}

export class CronJobUpdateResponseDto {
  @ApiProperty({ example: 'expiry_warning' }) name!: string;
  @ApiProperty({ example: '0 8 * * *' }) cronExpression!: string;
  @ApiProperty({ example: true }) isEnabled!: boolean;
  @ApiProperty({ example: 'Cron [expiry_warning] đang chạy với schedule: 0 8 * * *' }) message!: string;
}
