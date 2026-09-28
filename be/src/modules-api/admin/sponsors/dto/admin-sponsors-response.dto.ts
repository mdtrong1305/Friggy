import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class SponsorDto {
  @ApiProperty({ example: 'spo_abc123' }) id!: string;
  @ApiProperty({ example: 'Shopee Food' }) name!: string;
  @ApiPropertyOptional({ example: 'https://shopee.vn' }) websiteUrl!: string | null;
  @ApiPropertyOptional({ example: 'contact@shopee.vn' }) contactEmail!: string | null;
  @ApiProperty({ example: 'active', enum: ['active', 'paused', 'terminated'] }) status!: string;
  @ApiProperty({ example: 3, description: 'Số chiến dịch' }) campaignCount!: number;
  @ApiProperty({ example: '2026-09-01T00:00:00Z' }) createdAt!: string;
}

export class CampaignDto {
  @ApiProperty({ example: 'cam_abc123' }) id!: string;
  @ApiProperty({ example: 'spo_abc123' }) sponsorId!: string;
  @ApiProperty({ example: 'Flash Sale Tết 2026' }) title!: string;
  @ApiPropertyOptional({ example: 'Mô tả chiến dịch' }) description!: string | null;
  @ApiProperty({ example: 'banner', enum: ['banner', 'recipe_highlight', 'ingredient_promo'] }) campaignType!: string;
  @ApiProperty({ example: '2026-01-01T00:00:00Z' }) startDate!: string;
  @ApiPropertyOptional({ example: '2026-01-31T23:59:59Z' }) endDate!: string | null;
  @ApiProperty({ example: 'scheduled', enum: ['scheduled', 'active', 'ended'] }) status!: string;
  @ApiProperty({ example: 5, description: 'Số recipe trong chiến dịch' }) recipeCount!: number;
  @ApiProperty({ example: '2026-09-01T00:00:00Z' }) createdAt!: string;
}
