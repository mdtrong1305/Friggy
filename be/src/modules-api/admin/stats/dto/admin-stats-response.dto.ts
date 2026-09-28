import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

// ─── GET /admin/stats/overview ────────────────────────────────────────────────

export class StatsOverviewDto {
  @ApiProperty({ example: 1200 }) totalUsers!: number;
  @ApiProperty({ example: 1100 }) activeUsers!: number;
  @ApiProperty({ example: 50 }) suspendedUsers!: number;
  @ApiProperty({ example: 80, description: 'Users mới trong tháng này' }) newUsersThisMonth!: number;
  @ApiProperty({ example: 350 }) activeSubscriptions!: number;
  @ApiProperty({ example: 5800000, description: 'Doanh thu tháng này (VND)' }) revenueThisMonthVnd!: number;
  @ApiProperty({ example: 48000000, description: 'Tổng doanh thu toàn thời gian (VND)' }) totalRevenueVnd!: number;
}

// ─── GET /admin/stats/ai-usage ────────────────────────────────────────────────

export class AiUsageBreakdownItemDto {
  @ApiProperty({ example: 'recipe_suggestion' }) featureType!: string;
  @ApiProperty({ example: 420 }) count!: number;
}

export class AiUsageDto {
  @ApiProperty({ example: '7 ngày gần nhất' }) period!: string;
  @ApiProperty({ example: 1500 }) totalCalls!: number;
  @ApiProperty({ type: [AiUsageBreakdownItemDto] }) breakdown!: AiUsageBreakdownItemDto[];
}

// ─── GET /admin/stats/subscriptions ──────────────────────────────────────────

export class SubscriptionPlanInfoDto {
  @ApiProperty({ example: 1 }) id!: number;
  @ApiProperty({ example: 'individual_pro' }) name!: string;
  @ApiPropertyOptional({ example: 'Individual Pro' }) displayName?: string | null;
}

export class SubscriptionBreakdownItemDto {
  @ApiProperty({ type: SubscriptionPlanInfoDto }) plan!: SubscriptionPlanInfoDto;
  @ApiProperty({ example: 120 }) activeSubscribers!: number;
}
