import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class RecipeIngredientDto {
  @ApiProperty() ingredientId!: number;
  @ApiProperty() ingredientName!: string;
  @ApiProperty() quantity!: number;
  @ApiProperty() unit!: string;
  @ApiProperty() isOptional!: boolean;
  @ApiPropertyOptional() note!: string | null;
  @ApiProperty({ description: 'true nếu nguyên liệu này có trong tủ lạnh của user' })
  inFridge!: boolean;
}

export class RecipeStepDto {
  @ApiProperty() stepNumber!: number;
  @ApiProperty() instruction!: string;
  @ApiPropertyOptional() imagePath!: string | null;
  @ApiPropertyOptional() durationMinutes!: number | null;
}

export class RecipeTagDto {
  @ApiProperty() id!: number;
  @ApiProperty() name!: string;
  @ApiProperty() type!: string;
}

export class RecipeSummaryDto {
  @ApiProperty() id!: string;
  @ApiProperty() title!: string;
  @ApiPropertyOptional() thumbnailPath!: string | null;
  @ApiProperty() mealType!: string;
  @ApiProperty() cookTimeMinutes!: number;
  @ApiProperty() servings!: number;
  @ApiProperty() difficultyLevel!: string;
  @ApiPropertyOptional() estimatedCost!: number | null;
  @ApiProperty() isAiGenerated!: boolean;
  @ApiPropertyOptional({ description: 'Tỷ lệ nguyên liệu trong tủ khớp với recipe (0–100)' })
  matchScore?: number;
  @ApiProperty({ type: [RecipeTagDto] }) tags!: RecipeTagDto[];
}

export class RecipeDetailDto extends RecipeSummaryDto {
  @ApiPropertyOptional() description!: string | null;
  @ApiProperty({ type: [RecipeIngredientDto] }) ingredients!: RecipeIngredientDto[];
  @ApiProperty({ type: [RecipeStepDto] }) steps!: RecipeStepDto[];
}