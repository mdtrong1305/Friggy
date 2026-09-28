import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from 'src/modules-system/prisma/prisma.service';
import { existsSync, unlinkSync } from 'fs';
import { join } from 'path';
import type {
  CreateIngredientDto,
  UpdateIngredientDto,
  CreateCategoryDto,
  UpdateCategoryDto,
} from './dto/ingredients.dto';
import type {
  IngredientResponseDto,
  CategoryResponseDto,
} from './dto/ingredients-response.dto';

@Injectable()
export class AdminIngredientsService {
  constructor(private readonly prisma: PrismaService) {}

  // ─────────────────────────────────────────────────────────
  // Ingredients
  // ─────────────────────────────────────────────────────────

  async create(dto: CreateIngredientDto): Promise<IngredientResponseDto> {
    const existing = await this.prisma.ingredient.findUnique({
      where: { name: dto.name },
    });
    if (existing) throw new ConflictException('Tên nguyên liệu đã tồn tại');

    const category = await this.prisma.ingredientCategory.findFirst({
      where: { id: dto.categoryId, deletedAt: null },
    });
    if (!category) throw new NotFoundException('Danh mục không tồn tại');

    const ingredient = await this.prisma.ingredient.create({
      data: {
        name: dto.name,
        categoryId: dto.categoryId,
        defaultUnit: dto.defaultUnit,
        caloriesPer100g: dto.caloriesPer100g ?? null,
        averagePricePerUnit: dto.averagePricePerUnit ?? null,
        isCommon: dto.isCommon ?? true,
      },
      include: { category: true },
    });

    return this.mapIngredient(ingredient);
  }

  async update(id: number, dto: UpdateIngredientDto): Promise<IngredientResponseDto> {
    const ingredient = await this.prisma.ingredient.findFirst({
      where: { id, deletedAt: null },
    });
    if (!ingredient) throw new NotFoundException('Không tìm thấy nguyên liệu');

    if (dto.name && dto.name !== ingredient.name) {
      const nameConflict = await this.prisma.ingredient.findUnique({
        where: { name: dto.name },
      });
      if (nameConflict) throw new ConflictException('Tên nguyên liệu đã tồn tại');
    }

    const updated = await this.prisma.ingredient.update({
      where: { id },
      data: {
        ...(dto.name && { name: dto.name }),
        ...(dto.categoryId && { categoryId: dto.categoryId }),
        ...(dto.defaultUnit && { defaultUnit: dto.defaultUnit }),
        ...(dto.caloriesPer100g !== undefined && { caloriesPer100g: dto.caloriesPer100g }),
        ...(dto.averagePricePerUnit !== undefined && { averagePricePerUnit: dto.averagePricePerUnit }),
        ...(dto.isCommon !== undefined && { isCommon: dto.isCommon }),
      },
      include: { category: true },
    });

    return this.mapIngredient(updated);
  }

  async remove(id: number): Promise<void> {
    const ingredient = await this.prisma.ingredient.findFirst({
      where: { id, deletedAt: null },
    });
    if (!ingredient) throw new NotFoundException('Không tìm thấy nguyên liệu');

    await this.prisma.ingredient.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
  }

  async uploadImage(id: number, file: Express.Multer.File): Promise<IngredientResponseDto> {
    const ingredient = await this.prisma.ingredient.findFirst({
      where: { id, deletedAt: null },
      include: { category: true },
    });
    if (!ingredient) throw new NotFoundException('Không tìm thấy nguyên liệu');

    if (ingredient.imagePath) {
      const oldFile = join(process.cwd(), 'public', ingredient.imagePath);
      if (existsSync(oldFile)) unlinkSync(oldFile);
    }

    const imagePath = `/ingredients/${file.filename}`;
    const updated = await this.prisma.ingredient.update({
      where: { id },
      data: { imagePath },
      include: { category: true },
    });

    return this.mapIngredient(updated);
  }

  // ─────────────────────────────────────────────────────────
  // Categories
  // ─────────────────────────────────────────────────────────

  async createCategory(dto: CreateCategoryDto): Promise<CategoryResponseDto> {
    const existing = await this.prisma.ingredientCategory.findUnique({
      where: { name: dto.name },
    });
    if (existing) throw new ConflictException('Tên danh mục đã tồn tại');

    if (dto.parentId) {
      const parent = await this.prisma.ingredientCategory.findFirst({
        where: { id: dto.parentId, deletedAt: null },
      });
      if (!parent) throw new NotFoundException('Danh mục cha không tồn tại');
      if (parent.parentId !== null)
        throw new BadRequestException('Chỉ hỗ trợ 2 cấp danh mục');
    }

    const category = await this.prisma.ingredientCategory.create({
      data: {
        name: dto.name,
        parentId: dto.parentId ?? null,
        defaultShelfLifeDays: dto.defaultShelfLifeDays ?? null,
      },
      include: { children: { where: { deletedAt: null } } },
    });

    return this.mapCategory(category);
  }

  async updateCategory(id: number, dto: UpdateCategoryDto): Promise<CategoryResponseDto> {
    const category = await this.prisma.ingredientCategory.findFirst({
      where: { id, deletedAt: null },
    });
    if (!category) throw new NotFoundException('Không tìm thấy danh mục');

    if (dto.name && dto.name !== category.name) {
      const nameConflict = await this.prisma.ingredientCategory.findUnique({
        where: { name: dto.name },
      });
      if (nameConflict) throw new ConflictException('Tên danh mục đã tồn tại');
    }

    if (dto.parentId !== undefined && dto.parentId !== null) {
      if (dto.parentId === id)
        throw new BadRequestException('Danh mục không thể là cha của chính nó');
      const parent = await this.prisma.ingredientCategory.findFirst({
        where: { id: dto.parentId, deletedAt: null },
      });
      if (!parent) throw new NotFoundException('Danh mục cha không tồn tại');
      if (parent.parentId !== null)
        throw new BadRequestException('Chỉ hỗ trợ 2 cấp danh mục');
    }

    const updated = await this.prisma.ingredientCategory.update({
      where: { id },
      data: {
        ...(dto.name && { name: dto.name }),
        ...(dto.parentId !== undefined && { parentId: dto.parentId }),
        ...(dto.defaultShelfLifeDays !== undefined && {
          defaultShelfLifeDays: dto.defaultShelfLifeDays,
        }),
      },
      include: { children: { where: { deletedAt: null } } },
    });

    return this.mapCategory(updated);
  }

  async removeCategory(id: number): Promise<void> {
    const category = await this.prisma.ingredientCategory.findFirst({
      where: { id, deletedAt: null },
    });
    if (!category) throw new NotFoundException('Không tìm thấy danh mục');

    const ingredientCount = await this.prisma.ingredient.count({
      where: { categoryId: id, deletedAt: null },
    });
    if (ingredientCount > 0)
      throw new BadRequestException(
        `Không thể xóa: có ${ingredientCount} nguyên liệu thuộc danh mục này`,
      );

    const childCount = await this.prisma.ingredientCategory.count({
      where: { parentId: id, deletedAt: null },
    });
    if (childCount > 0)
      throw new BadRequestException(`Không thể xóa: có ${childCount} danh mục con`);

    await this.prisma.ingredientCategory.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
  }

  async uploadCategoryIcon(id: number, file: Express.Multer.File): Promise<CategoryResponseDto> {
    const category = await this.prisma.ingredientCategory.findFirst({
      where: { id, deletedAt: null },
      include: { children: { where: { deletedAt: null } } },
    });
    if (!category) throw new NotFoundException('Không tìm thấy danh mục');

    if (category.iconPath) {
      const oldFile = join(process.cwd(), 'public', category.iconPath);
      if (existsSync(oldFile)) unlinkSync(oldFile);
    }

    const iconPath = `/categories/${file.filename}`;
    const updated = await this.prisma.ingredientCategory.update({
      where: { id },
      data: { iconPath },
      include: { children: { where: { deletedAt: null } } },
    });

    return this.mapCategory(updated);
  }

  // ─────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────

  private mapIngredient(i: any): IngredientResponseDto {
    return {
      id: i.id,
      name: i.name,
      defaultUnit: i.defaultUnit,
      caloriesPer100g: i.caloriesPer100g ?? null,
      averagePricePerUnit: i.averagePricePerUnit ?? null,
      imagePath: i.imagePath ?? null,
      isCommon: i.isCommon,
      categoryId: i.categoryId,
      categoryName: i.category?.name ?? '',
    };
  }

  private mapCategory(c: any): CategoryResponseDto {
    return {
      id: c.id,
      name: c.name,
      iconPath: c.iconPath ?? null,
      parentId: c.parentId ?? null,
      defaultShelfLifeDays: c.defaultShelfLifeDays ?? null,
      children: (c.children ?? []).map((child: any) => ({
        id: child.id,
        name: child.name,
        iconPath: child.iconPath ?? null,
        parentId: child.parentId ?? null,
        defaultShelfLifeDays: child.defaultShelfLifeDays ?? null,
      })),
    };
  }
}
