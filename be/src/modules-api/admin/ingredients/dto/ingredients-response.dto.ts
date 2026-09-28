import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CategoryResponseDto {
  @ApiProperty() id!: number;
  @ApiProperty() name!: string;
  @ApiPropertyOptional() iconPath!: string | null;
  @ApiPropertyOptional() parentId!: number | null;
  @ApiPropertyOptional() defaultShelfLifeDays!: number | null;
  @ApiPropertyOptional({ type: () => [CategoryResponseDto] }) children?: CategoryResponseDto[];
}

export class IngredientResponseDto {
  @ApiProperty() id!: number;
  @ApiProperty() name!: string;
  @ApiProperty() defaultUnit!: string;
  @ApiPropertyOptional() caloriesPer100g!: number | null;
  @ApiPropertyOptional() averagePricePerUnit!: number | null;
  @ApiPropertyOptional() imagePath!: string | null;
  @ApiProperty() isCommon!: boolean;
  @ApiProperty() categoryId!: number;
  @ApiProperty() categoryName!: string;
}
