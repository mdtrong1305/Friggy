import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsOptional, IsString, Matches } from 'class-validator';

export class UpdateCronJobDto {
  @ApiPropertyOptional({
    description: 'Biểu thức cron mới (5 fields: phút giờ ngày tháng thứ)',
    example: '0 6 * * *',
  })
  @IsOptional()
  @IsString()
  @Matches(/^(\*|[0-9,\-\/]+)\s+(\*|[0-9,\-\/]+)\s+(\*|[0-9,\-\/]+)\s+(\*|[0-9,\-\/]+)\s+(\*|[0-9,\-\/]+)$/, {
    message: 'cronExpression không hợp lệ — phải có đúng 5 fields',
  })
  cronExpression?: string;

  @ApiPropertyOptional({
    description: 'Bật (true) hoặc tắt (false) cron job',
    example: true,
  })
  @IsOptional()
  @IsBoolean()
  isEnabled?: boolean;
}
