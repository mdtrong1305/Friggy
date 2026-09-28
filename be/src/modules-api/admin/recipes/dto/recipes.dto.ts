import {
  IsString,
  IsOptional,
  IsInt,
  IsBoolean,
  Min,
  Max,
  MaxLength,
  IsPositive,
  IsEnum,
  IsArray,
} from 'class-validator';
import { Type } from 'class-transformer';

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

// ─── Create Recipe (Admin) ────────────────────────────────────────────────────

export class RecipeIngredientInputDto {
  @IsInt() @IsPositive() @Type(() => Number)
  ingredientId!: number;

  @Type(() => Number)
  quantity!: number;

  @IsString() @MaxLength(30)
  unit!: string;

  @IsOptional() @IsBoolean()
  isOptional?: boolean;

  @IsOptional() @IsString() @MaxLength(255)
  note?: string;
}

export class RecipeStepInputDto {
  @IsInt() @Min(1) @Type(() => Number)
  stepNumber!: number;

  @IsString()
  instruction!: string;

  @IsOptional() @IsInt() @Min(1) @Type(() => Number)
  durationMinutes?: number;
}

export class CreateRecipeDto {
  @IsString() @MaxLength(255)
  title!: string;

  @IsOptional() @IsString()
  description?: string;

  @IsEnum(MealTypeEnum)
  mealType!: MealTypeEnum;

  @IsInt() @Min(1) @Max(600)
  @Type(() => Number)
  cookTimeMinutes!: number;

  @IsInt() @Min(1) @Max(50)
  @Type(() => Number)
  servings!: number;

  @IsEnum(DifficultyEnum)
  difficultyLevel!: DifficultyEnum;

  @IsOptional() @IsInt() @Min(0) @Type(() => Number)
  estimatedCost?: number;

  @IsOptional() @IsArray()
  @Type(() => RecipeIngredientInputDto)
  ingredients?: RecipeIngredientInputDto[];

  @IsOptional() @IsArray()
  @Type(() => RecipeStepInputDto)
  steps?: RecipeStepInputDto[];

  @IsOptional() @IsArray() @IsInt({ each: true })
  @Type(() => Number)
  tagIds?: number[];
}

export class UpdateRecipeDto {
  @IsOptional() @IsString() @MaxLength(255)
  title?: string;

  @IsOptional() @IsString()
  description?: string;

  @IsOptional() @IsEnum(MealTypeEnum)
  mealType?: MealTypeEnum;

  @IsOptional() @IsInt() @Min(1) @Max(600) @Type(() => Number)
  cookTimeMinutes?: number;

  @IsOptional() @IsInt() @Min(1) @Max(50) @Type(() => Number)
  servings?: number;

  @IsOptional() @IsEnum(DifficultyEnum)
  difficultyLevel?: DifficultyEnum;

  @IsOptional() @IsInt() @Min(0) @Type(() => Number)
  estimatedCost?: number;
}
