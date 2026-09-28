import {
  IsString,
  IsOptional,
  IsInt,
  Min,
  Max,
  MaxLength,
  IsEnum,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiPropertyOptional } from '@nestjs/swagger';

export enum MealTypeEnum {
  breakfast = 'breakfast',
  lunch = 'lunch',
  dinner = 'dinner',
  snack = 'snack',
  dessert = 'dessert',
  drink = 'drink',
}

export enum DifficultyEnum {
  easy = 'easy',
  medium = 'medium',
  hard = 'hard',
}

// ─── List Query ───────────────────────────────────────────────────────────────

export class ListRecipesQueryDto {
  @ApiPropertyOptional({ example: 1 })
  @IsOptional() @IsInt() @Min(1) @Type(() => Number)
  page?: number = 1;

  @ApiPropertyOptional({ example: 20 })
  @IsOptional() @IsInt() @Min(1) @Max(100) @Type(() => Number)
  limit?: number = 20;

  @ApiPropertyOptional({ example: 'bún bò' })
  @IsOptional() @IsString() @MaxLength(100)
  search?: string;

  @ApiPropertyOptional({ enum: MealTypeEnum })
  @IsOptional() @IsEnum(MealTypeEnum)
  mealType?: MealTypeEnum;

  @ApiPropertyOptional({ enum: DifficultyEnum })
  @IsOptional() @IsEnum(DifficultyEnum)
  difficulty?: DifficultyEnum;

  @ApiPropertyOptional({ example: '1,2,3', description: 'Tag IDs phân cách bằng dấu phẩy' })
  @IsOptional() @IsString()
  tagIds?: string;

  @ApiPropertyOptional({ example: 30, description: 'Thời gian nấu tối đa (phút)' })
  @IsOptional() @IsInt() @Min(1) @Type(() => Number)
  maxCookTime?: number;
}
