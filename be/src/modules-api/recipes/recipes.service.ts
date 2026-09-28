import {
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from 'src/modules-system/prisma/prisma.service';
import type { ListRecipesQueryDto } from './dto/recipes.dto';
import type {
  RecipeSummaryDto,
  RecipeDetailDto,
  PaginatedRecipesDto,
} from './dto/recipes-response.dto';

@Injectable()
export class RecipesService {
  constructor(private readonly prisma: PrismaService) {}

  // ─────────────────────────────────────────────────────────
  // GET / — Danh sách công thức (pagination + filter)
  // ─────────────────────────────────────────────────────────

  async findAll(query: ListRecipesQueryDto): Promise<PaginatedRecipesDto> {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;

    const where: any = { deletedAt: null, status: 'published' };

    if (query.search) {
      where.OR = [
        { title: { contains: query.search } },
        { description: { contains: query.search } },
      ];
    }
    if (query.mealType) where.mealType = query.mealType;
    if (query.difficulty) where.difficultyLevel = query.difficulty;
    if (query.maxCookTime) where.cookTimeMinutes = { lte: query.maxCookTime };
    if (query.tagIds) {
      const ids = query.tagIds.split(',').map(Number).filter(Boolean);
      if (ids.length) where.tags = { some: { tagId: { in: ids } } };
    }

    const [items, total] = await Promise.all([
      this.prisma.recipe.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: { tags: { include: { tag: true } } },
      }),
      this.prisma.recipe.count({ where }),
    ]);

    return {
      data: items.map((r) => this.mapSummary(r)),
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  // ─────────────────────────────────────────────────────────
  // GET /suggestions — Gợi ý từ tủ lạnh + matchScore
  // ─────────────────────────────────────────────────────────

  async getSuggestions(userId: string): Promise<RecipeSummaryDto[]> {
    // Lấy ingredient IDs trong tủ lạnh (chưa hết hạn, chưa xóa)
    const fridgeItems = await this.prisma.fridgeItem.findMany({
      where: {
        userId,
        deletedAt: null,
        OR: [{ expiresAt: null }, { expiresAt: { gte: new Date() } }],
      },
      select: { ingredientId: true },
    });
    const fridgeIngredientIds = new Set(fridgeItems.map((f) => f.ingredientId));

    // Lấy ingredient IDs user bị dị ứng
    const allergies = await this.prisma.userAllergy.findMany({
      where: { userId, deletedAt: null },
      select: { ingredientId: true },
    });
    const allergyIds = new Set(allergies.map((a) => a.ingredientId));

    // Lấy recipes không chứa nguyên liệu dị ứng
    const recipes = await this.prisma.recipe.findMany({
      where: {
        deletedAt: null,
        status: 'published',
        // Loại recipe có ingredient dị ứng
        NOT: allergyIds.size > 0
          ? { ingredients: { some: { ingredientId: { in: Array.from(allergyIds) }, deletedAt: null } } }
          : undefined,
      },
      include: {
        ingredients: { where: { deletedAt: null } },
        tags: { include: { tag: true } },
      },
    });

    // Tính matchScore và sắp xếp
    const scored = recipes.map((r) => {
      const total = r.ingredients.length;
      if (total === 0) return { recipe: r, score: 0 };
      const matched = r.ingredients.filter((i) =>
        fridgeIngredientIds.has(i.ingredientId),
      ).length;
      return { recipe: r, score: Math.round((matched / total) * 100) };
    });

    scored.sort((a, b) => b.score - a.score);

    return scored.slice(0, 20).map(({ recipe, score }) => ({
      ...this.mapSummary(recipe),
      matchScore: score,
    }));
  }

  // ─────────────────────────────────────────────────────────
  // GET /bookmarked — Công thức đã bookmark
  // ─────────────────────────────────────────────────────────

  async getBookmarked(userId: string): Promise<RecipeSummaryDto[]> {
    const saved = await this.prisma.userSavedRecipe.findMany({
      where: { userId, deletedAt: null },
      include: {
        recipe: {
          include: { tags: { include: { tag: true } } },
        },
      },
      orderBy: { savedAt: 'desc' },
    });

    return saved
      .filter((s) => !s.recipe.deletedAt)
      .map((s) => this.mapSummary(s.recipe));
  }

  // ─────────────────────────────────────────────────────────
  // GET /:id — Chi tiết công thức
  // ─────────────────────────────────────────────────────────

  async findOne(id: string, userId: string): Promise<RecipeDetailDto> {
    const recipe = await this.prisma.recipe.findFirst({
      where: { id, deletedAt: null },
      include: {
        ingredients: {
          where: { deletedAt: null },
          include: { ingredient: true },
          orderBy: { id: 'asc' },
        },
        steps: {
          where: { deletedAt: null },
          orderBy: { stepNumber: 'asc' },
        },
        tags: { include: { tag: true } },
      },
    });
    if (!recipe) throw new NotFoundException('Không tìm thấy công thức');

    // Lấy fridge items để tính inFridge
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

  // ─────────────────────────────────────────────────────────
  // POST /:id/bookmark — Lưu bookmark
  // ─────────────────────────────────────────────────────────

  async addBookmark(userId: string, recipeId: string): Promise<void> {
    const recipe = await this.prisma.recipe.findFirst({
      where: { id: recipeId, deletedAt: null },
    });
    if (!recipe) throw new NotFoundException('Không tìm thấy công thức');

    // Upsert — restore nếu đã bị soft delete
    const existing = await this.prisma.userSavedRecipe.findUnique({
      where: { userId_recipeId: { userId, recipeId } },
    });

    if (existing) {
      if (!existing.deletedAt) return; // Đã bookmark rồi
      await this.prisma.userSavedRecipe.update({
        where: { userId_recipeId: { userId, recipeId } },
        data: { deletedAt: null },
      });
    } else {
      await this.prisma.userSavedRecipe.create({
        data: { userId, recipeId },
      });
    }
  }

  // ─────────────────────────────────────────────────────────
  // DELETE /:id/bookmark — Bỏ bookmark
  // ─────────────────────────────────────────────────────────

  async removeBookmark(userId: string, recipeId: string): Promise<void> {
    const saved = await this.prisma.userSavedRecipe.findFirst({
      where: { userId, recipeId, deletedAt: null },
    });
    if (!saved) throw new NotFoundException('Chưa bookmark công thức này');

    await this.prisma.userSavedRecipe.update({
      where: { userId_recipeId: { userId, recipeId } },
      data: { deletedAt: new Date() },
    });
  }

  // ─────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────

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
