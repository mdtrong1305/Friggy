import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsInt, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class ListStatsQueryDto {
  @ApiPropertyOptional({ description: 'Số ngày nhìn lại (AI usage)', example: 7 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Type(() => Number)
  days?: number = 7;
}
