import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class SubscriptionPlanDto {
  @ApiProperty({ example: 1 }) id!: number;
  @ApiProperty({ example: 'individual_pro' }) name!: string;
  @ApiPropertyOptional({ example: 'Individual Pro' }) displayName!: string | null;
  @ApiProperty({ example: 29000, description: 'Giá gói (VND)' }) priceVnd!: number;
  @ApiProperty({ example: 5, description: 'Số lượt AI/tuần (-1 = không giới hạn)' }) aiUsagePerWeek!: number;
  @ApiProperty({ type: [String], example: ['Tính năng A', 'Tính năng B'] }) features!: string[];
  @ApiProperty({ example: true }) isActive!: boolean;
  @ApiProperty({ example: '2026-09-01T00:00:00Z' }) createdAt!: string;
}
