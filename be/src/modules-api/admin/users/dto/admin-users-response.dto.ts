import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

// ─── User list item ───────────────────────────────────────────────────────────

export class UserSubscriptionSummaryDto {
  @ApiProperty({ example: 'active', enum: ['active', 'expired', 'cancelled'] }) status!: string;
  @ApiPropertyOptional({ example: '2027-01-01T00:00:00Z' }) endDate!: string | null;
  @ApiPropertyOptional() plan!: { name: string; displayName: string } | null;
}

export class UserListItemDto {
  @ApiProperty({ example: 'usr_abc123' }) id!: string;
  @ApiPropertyOptional({ example: 'Nguyễn Văn A' }) name!: string | null;
  @ApiPropertyOptional({ example: 'user@example.com' }) email!: string | null;
  @ApiPropertyOptional({ example: 'user@gmail.com' }) googleEmail!: string | null;
  @ApiProperty({ example: 'email', enum: ['email', 'google'] }) authProvider!: string;
  @ApiProperty({ example: 'active', enum: ['active', 'suspended', 'pending'] }) status!: string;
  @ApiProperty({ example: '2026-09-01T00:00:00Z' }) createdAt!: string;
  @ApiPropertyOptional({ example: '2026-09-28T10:00:00Z' }) lastLoginAt!: string | null;
  @ApiPropertyOptional({ type: UserSubscriptionSummaryDto }) subscription!: UserSubscriptionSummaryDto | null;
}

export class PaginatedUsersDto {
  @ApiProperty({ type: [UserListItemDto] }) data!: UserListItemDto[];
  @ApiProperty({ example: 1200 }) total!: number;
  @ApiProperty({ example: 1 }) page!: number;
  @ApiProperty({ example: 20 }) limit!: number;
  @ApiProperty({ example: 60 }) totalPages!: number;
}

// ─── User detail ──────────────────────────────────────────────────────────────

export class UserDetailDto extends UserListItemDto {
  @ApiProperty({ example: true }) isOnboardingCompleted!: boolean;
  @ApiPropertyOptional() profile!: Record<string, any> | null;
  @ApiPropertyOptional() preferences!: {
    dietaryStyle: string | null;
    skillLevel: string | null;
    householdSize: number | null;
    weeklyBudget: number | null;
  } | null;
  @ApiProperty({ example: 12, description: 'Số lượt AI đã dùng trong 7 ngày qua' }) aiUsageThisWeek!: number;
}

// ─── Action response ─────────────────────────────────────────────────────────

export class UserActionResponseDto {
  @ApiProperty({ example: 'Đã khóa tài khoản user usr_abc123' }) message!: string;
}
