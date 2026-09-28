import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, IsInt, Min, Max } from 'class-validator';
import { Type } from 'class-transformer';

export class ListTransactionsQueryDto {
  @ApiPropertyOptional({ example: 1 })
  @IsOptional() @IsInt() @Min(1) @Type(() => Number)
  page?: number = 1;

  @ApiPropertyOptional({ example: 20 })
  @IsOptional() @IsInt() @Min(1) @Max(100) @Type(() => Number)
  limit?: number = 20;

  @ApiPropertyOptional({ description: 'Filter theo userId cụ thể' })
  @IsOptional() @IsString()
  userId?: string;

  @ApiPropertyOptional({ enum: ['pending', 'paid', 'expired', 'cancelled'], description: 'Filter theo trạng thái' })
  @IsOptional() @IsString()
  status?: string;
}
