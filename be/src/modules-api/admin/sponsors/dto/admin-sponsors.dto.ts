import { ApiPropertyOptional, ApiProperty } from '@nestjs/swagger';
import { IsOptional, IsString, IsEnum } from 'class-validator';

export class CreateSponsorDto {
  @ApiProperty({ description: 'Tên sponsor', example: 'Shopee Food' })
  @IsString()
  name!: string;

  @ApiPropertyOptional({ description: 'URL website', example: 'https://shopee.vn' })
  @IsOptional()
  @IsString()
  websiteUrl?: string;

  @ApiPropertyOptional({ description: 'Email liên hệ' })
  @IsOptional()
  @IsString()
  contactEmail?: string;

  @ApiPropertyOptional({ enum: ['active', 'paused', 'terminated'], example: 'active' })
  @IsOptional()
  @IsEnum(['active', 'paused', 'terminated'])
  status?: string = 'active';
}

export class UpdateSponsorDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  name?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  websiteUrl?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  contactEmail?: string;

  @ApiPropertyOptional({ enum: ['active', 'paused', 'terminated'] })
  @IsOptional()
  @IsEnum(['active', 'paused', 'terminated'])
  status?: string;
}

export class CreateCampaignDto {
  @ApiProperty({ description: 'Tiêu đề chiến dịch', example: 'Flash Sale Tết 2026' })
  @IsString()
  title!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  description?: string;

  @ApiProperty({ enum: ['banner', 'recipe_highlight', 'ingredient_promo'] })
  @IsEnum(['banner', 'recipe_highlight', 'ingredient_promo'])
  campaignType!: string;

  @ApiProperty({ example: '2026-01-01' })
  @IsString()
  startDate!: string;

  @ApiPropertyOptional({ example: '2026-01-31' })
  @IsOptional()
  @IsString()
  endDate?: string;

  @ApiPropertyOptional({ enum: ['scheduled', 'active', 'ended'], example: 'scheduled' })
  @IsOptional()
  @IsEnum(['scheduled', 'active', 'ended'])
  status?: string = 'scheduled';
}

export class UpdateCampaignDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  title?: string;

  @ApiPropertyOptional({ enum: ['scheduled', 'active', 'ended'] })
  @IsOptional()
  @IsEnum(['scheduled', 'active', 'ended'])
  status?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  endDate?: string;
}
