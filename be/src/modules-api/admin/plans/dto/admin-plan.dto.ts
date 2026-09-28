import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsNumber, IsString, IsBoolean, Min, IsArray, IsNotEmpty, IsEnum } from 'class-validator';

export class CreatePlanDto {
  @ApiProperty({ example: 'individual_pro', description: 'Tên định danh nội bộ (unique)' })
  @IsString() @IsNotEmpty()
  name!: string;

  @ApiPropertyOptional({ example: 'Individual Pro' })
  @IsOptional() @IsString()
  displayName?: string;

  @ApiProperty({ example: 29000, description: 'Giá gói (VND)' })
  @IsNumber() @Min(0)
  priceVnd!: number;

  @ApiProperty({ example: 'monthly', enum: ['monthly', 'yearly'] })
  @IsEnum(['monthly', 'yearly'])
  billingCycle!: string;

  @ApiProperty({ example: 5, description: 'Số lượt AI/tuần (-1 = không giới hạn)' })
  @IsNumber() @Min(-1)
  aiUsagePerWeek!: number;

  @ApiPropertyOptional({ type: [String], example: ['Tính năng A', 'Tính năng B'] })
  @IsOptional() @IsArray() @IsString({ each: true })
  features?: string[];

  @ApiPropertyOptional({ example: true, default: true })
  @IsOptional() @IsBoolean()
  isActive?: boolean = true;
}


export class UpdatePlanDto {
  @ApiPropertyOptional({ example: 29000, description: 'Giá gói (VND)' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  priceVnd?: number;

  @ApiPropertyOptional({ example: 5, description: 'Số lượt AI/tuần (-1 = không giới hạn)' })
  @IsOptional()
  @IsNumber()
  @Min(-1)
  aiUsagePerWeek?: number;

  @ApiPropertyOptional({ example: 'Individual Pro' })
  @IsOptional()
  @IsString()
  displayName?: string;

  @ApiPropertyOptional({ type: [String], example: ['Tính năng A', 'Tính năng B'] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  features?: string[];

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
