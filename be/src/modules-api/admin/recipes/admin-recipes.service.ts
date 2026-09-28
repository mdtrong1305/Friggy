import {
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from 'src/modules-system/prisma/prisma.service';
import { v4 as uuid } from 'uuid';
import type {
  CreateRecipeDto,
  UpdateRecipeDto,
} from './dto/recipes.dto';
import type {
  RecipeSummaryDto,
  RecipeDetailDto,
} from './dto/recipes-response.dto';

@Injectable()
export class AdminRecipesService {
  constructor(private readonly prisma: PrismaService) {}

  // ─────────────────────────────────────────────────────────
  // POST / — Tạo công thức
  // ─────────────────────────────────────────────────────────

  async create(dto: CreateRecipeDto, authorId: string): Promise<RecipeDetailDto> {
    const existing = await this.prisma.recipe.findFirst({
      where: { title: dto.title, deletedAt: null },
    });
    if (existing) throw new ConflictException('Tên công thức đã tồn tại');

    const id = uuid();

    await this.prisma.recipe.create({
      data: {
        id,
        title: dto.title,
        description: dto.description ?? null,
        mealType: dto.mealType as any,
        cookTimeMinutes: dto.cookTimeMinutes,
        servings: dto.servings,
        difficultyLevel: dto.difficultyLevel as any,
        estimatedCost: dto.estimatedCost ?? null,
        authorId,
        status: 'published',
        ingredients: dto.ingredients?.length
          ? {
              create: dto.ingredients.map((i) => ({
                ingredientId: i.ingredientId,
                quantity: i.quantity,
                unit: i.unit,
                isOptional: i.isOptional ?? false,
                note: i.note ?? null,
              })),
            }
          : undefined,
        steps: dto.steps?.length
          ? {
              create: dto.steps.map((s) => ({
                stepNumber: s.stepNumber,
                instruction: s.instruction,
                durationMinutes: s.durationMinutes ?? null,
              })),
            }
          : undefined,
        tags: dto.tagIds?.length
          ? { create: dto.tagIds.map((tagId) => ({ tagId })) }
          : undefined,
      },
    });

    return this.findDetail(id, authorId);
  }

  // ─────────────────────────────────────────────────────────
  // PATCH /:id — Cập nhật
  // ─────────────────────────────────────────────────────────

  async update(id: string, dto: UpdateRecipeDto, userId: string): Promise<RecipeDetailDto> {
    const recipe = await this.prisma.recipe.findFirst({
      where: { id, deletedAt: null },
    });
    if (!recipe) throw new NotFoundException('Không tìm thấy công thức');

    await this.prisma.recipe.update({
      where: { id },
      data: {
        ...(dto.title && { title: dto.title }),
        ...(dto.description !== undefined && { description: dto.description }),
        ...(dto.mealType && { mealType: dto.mealType as any }),
        ...(dto.cookTimeMinutes && { cookTimeMinutes: dto.cookTimeMinutes }),
        ...(dto.servings && { servings: dto.servings }),
        ...(dto.difficultyLevel && { difficultyLevel: dto.difficultyLevel as any }),
        ...(dto.estimatedCost !== undefined && { estimatedCost: dto.estimatedCost }),
      },
    });

    return this.findDetail(id, userId);
  }

  // ─────────────────────────────────────────────────────────
  // DELETE /:id — Soft delete
  // ─────────────────────────────────────────────────────────

  async remove(id: string): Promise<void> {
    const recipe = await this.prisma.recipe.findFirst({
      where: { id, deletedAt: null },
    });
    if (!recipe) throw new NotFoundException('Không tìm thấy công thức');

    await this.prisma.recipe.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
  }

  // ─────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────

  private async findDetail(id: string, userId: string): Promise<RecipeDetailDto> {
    const recipe = await this.prisma.recipe.findFirst({
      where: { id, deletedAt: null },
      include: {
        ingredients: {
          include: { ingredient: true },
          orderBy: { ingredientId: 'asc' },
        },
        steps: {
          orderBy: { stepNumber: 'asc' },
        },
        tags: { include: { tag: true } },
      },
    });
    if (!recipe) throw new NotFoundException('Không tìm thấy công thức');

    const fridgeItems = await this.prisma.fridgeItem.findMany({
      where: { userId, deletedAt: null },
      select: { ingredientId: true },
    });
    const fridgeIds = new Set(fridgeItems.map((f) => f.ingredientId));

    return {
      ...this.mapSummary(recipe),
      description: recipe.description ?? null,
      ingredients: recipe.ingredients.map((ri) => ({
        ingredientId: ri.ingredientId,
        ingredientName: ri.ingredient.name,
        quantity: ri.quantity,
        unit: ri.unit,
        isOptional: ri.isOptional,
        note: ri.note ?? null,
        inFridge: fridgeIds.has(ri.ingredientId),
      })),
      steps: recipe.steps.map((s) => ({
        stepNumber: s.stepNumber,
        instruction: s.instruction,
        imagePath: s.imagePath ?? null,
        durationMinutes: s.durationMinutes ?? null,
      })),
    };
  }

  private mapSummary(r: any): RecipeSummaryDto {
    return {
      id: r.id,
      title: r.title,
      thumbnailPath: r.thumbnailPath ?? null,
      mealType: r.mealType,
      cookTimeMinutes: r.cookTimeMinutes,
      servings: r.servings,
      difficultyLevel: r.difficultyLevel,
      estimatedCost: r.estimatedCost ?? null,
      isAiGenerated: r.isAiGenerated,
      tags: (r.tags ?? []).map((rt: any) => ({
        id: rt.tag.id,
        name: rt.tag.name,
        type: rt.tag.type,
      })),
    };
  }
}
