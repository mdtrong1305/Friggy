import {
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from 'src/modules-system/prisma/prisma.service';
import type { ListIngredientsQueryDto } from './dto/ingredients.dto';
import type {
  IngredientResponseDto,
  PaginatedIngredientsDto,
  CategoryResponseDto,
  PurchaseLinkResponseDto,
} from './dto/ingredients-response.dto';

@Injectable()
export class IngredientsService {
  constructor(private readonly prisma: PrismaService) {}

  // ─────────────────────────────────────────────────────────
  // GET / — Danh sách nguyên liệu (pagination + search + filter)
  // ─────────────────────────────────────────────────────────

  async findAll(query: ListIngredientsQueryDto): Promise<PaginatedIngredientsDto> {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;

    const where: any = { deletedAt: null };

    if (query.search) {
      where.name = { contains: query.search };
    }
    if (query.categoryId) {
      where.categoryId = query.categoryId;
    }
    if (query.isCommon !== undefined) {
      where.isCommon = query.isCommon;
    }

    const [items, total] = await Promise.all([
      this.prisma.ingredient.findMany({
        where,
        skip,
        take: limit,
        orderBy: [{ isCommon: 'desc' }, { name: 'asc' }],
        include: { category: true },
      }),
      this.prisma.ingredient.count({ where }),
    ]);

    return {
      data: items.map(this.mapIngredient),
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  // ─────────────────────────────────────────────────────────
  // GET /categories — Cây danh mục
  // ─────────────────────────────────────────────────────────

  async getCategories(): Promise<CategoryResponseDto[]> {
    const categories = await this.prisma.ingredientCategory.findMany({
      where: { deletedAt: null },
      orderBy: { name: 'asc' },
      include: {
        children: {
          where: { deletedAt: null },
          orderBy: { name: 'asc' },
        },
      },
    });

    return categories
      .filter((c) => c.parentId === null)
      .map(this.mapCategory);
  }

  // ─────────────────────────────────────────────────────────
  // GET /:id — Chi tiết nguyên liệu
  // ─────────────────────────────────────────────────────────

  async findOne(id: number): Promise<IngredientResponseDto> {
    const ingredient = await this.prisma.ingredient.findFirst({
      where: { id, deletedAt: null },
      include: { category: true },
    });
    if (!ingredient) throw new NotFoundException('Không tìm thấy nguyên liệu');
    return this.mapIngredient(ingredient);
  }

  // ─────────────────────────────────────────────────────────
  // GET /:id/purchase-links — Link mua TMDT
  // ─────────────────────────────────────────────────────────

  async getPurchaseLinks(id: number): Promise<PurchaseLinkResponseDto[]> {
    const ingredient = await this.prisma.ingredient.findFirst({
      where: { id, deletedAt: null },
    });
    if (!ingredient) throw new NotFoundException('Không tìm thấy nguyên liệu');

    const links = await this.prisma.ingredientPurchaseLink.findMany({
      where: { ingredientId: id, isActive: true, deletedAt: null },
      orderBy: [{ priority: 'desc' }, { priceVnd: 'asc' }],
    });

    return links.map((l) => ({
      id: l.id,
      platform: l.platform,
      productName: l.productName,
      purchaseUrl: l.purchaseUrl,
      priceVnd: l.priceVnd ?? null,
      unitDescription: l.unitDescription ?? null,
      thumbnailPath: l.thumbnailPath ?? null,
      priority: l.priority,
    }));
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
