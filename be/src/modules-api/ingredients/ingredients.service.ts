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
  ListIngredientsQueryDto,
  CreateIngredientDto,
  UpdateIngredientDto,
  CreateCategoryDto,
  UpdateCategoryDto,
} from './dto/ingredients.dto';
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

    // Chỉ trả về root categories (parentId == null), children đã được include
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
  // POST / — Tạo nguyên liệu (Admin)
  // ─────────────────────────────────────────────────────────

  async create(dto: CreateIngredientDto): Promise<IngredientResponseDto> {
    // Kiểm tra tên trùng
    const existing = await this.prisma.ingredient.findUnique({
      where: { name: dto.name },
    });
    if (existing) throw new ConflictException('Tên nguyên liệu đã tồn tại');

    // Kiểm tra category hợp lệ
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

  // ─────────────────────────────────────────────────────────
  // PATCH /:id — Cập nhật (Admin)
  // ─────────────────────────────────────────────────────────

  async update(id: number, dto: UpdateIngredientDto): Promise<IngredientResponseDto> {
    const ingredient = await this.prisma.ingredient.findFirst({
      where: { id, deletedAt: null },
    });
    if (!ingredient) throw new NotFoundException('Không tìm thấy nguyên liệu');

    // Kiểm tra tên trùng nếu đổi tên
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

  // ─────────────────────────────────────────────────────────
  // DELETE /:id — Soft delete (Admin)
  // ─────────────────────────────────────────────────────────

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

  // ─────────────────────────────────────────────────────────
  // POST /:id/image — Upload ảnh nguyên liệu (Admin)
  // ─────────────────────────────────────────────────────────

  async uploadImage(id: number, file: Express.Multer.File): Promise<IngredientResponseDto> {
    const ingredient = await this.prisma.ingredient.findFirst({
      where: { id, deletedAt: null },
      include: { category: true },
    });
    if (!ingredient) throw new NotFoundException('Không tìm thấy nguyên liệu');

    // Xóa ảnh cũ trên disk nếu có
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
  // Category CRUD (Admin)
  // ─────────────────────────────────────────────────────────

  async createCategory(dto: CreateCategoryDto): Promise<CategoryResponseDto> {
    // Kiểm tra tên trùng
    const existing = await this.prisma.ingredientCategory.findUnique({
      where: { name: dto.name },
    });
    if (existing) throw new ConflictException('Tên danh mục đã tồn tại');

    // Kiểm tra parentId hợp lệ (nếu có)
    if (dto.parentId) {
      const parent = await this.prisma.ingredientCategory.findFirst({
        where: { id: dto.parentId, deletedAt: null },
      });
      if (!parent) throw new NotFoundException('Danh mục cha không tồn tại');
      // Chỉ cho phép 2 cấp (parent phải là root)
      if (parent.parentId !== null)
        throw new BadRequestException('Chỉ hỗ trợ 2 cấp danh mục');
    }

    const category = await this.prisma.ingredientCategory.create({
      data: {
        name: dto.name,
        iconPath: dto.iconPath ?? null,
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

    // Kiểm tra tên trùng nếu đổi tên
    if (dto.name && dto.name !== category.name) {
      const nameConflict = await this.prisma.ingredientCategory.findUnique({
        where: { name: dto.name },
      });
      if (nameConflict) throw new ConflictException('Tên danh mục đã tồn tại');
    }

    // Kiểm tra parentId hợp lệ (nếu đổi)
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
        ...(dto.iconPath !== undefined && { iconPath: dto.iconPath }),
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

    // Kiểm tra có nguyên liệu thuộc danh mục này không
    const ingredientCount = await this.prisma.ingredient.count({
      where: { categoryId: id, deletedAt: null },
    });
    if (ingredientCount > 0)
      throw new BadRequestException(
        `Không thể xóa: có ${ingredientCount} nguyên liệu thuộc danh mục này`,
      );

    // Kiểm tra có danh mục con không
    const childCount = await this.prisma.ingredientCategory.count({
      where: { parentId: id, deletedAt: null },
    });
    if (childCount > 0)
      throw new BadRequestException(
        `Không thể xóa: có ${childCount} danh mục con`,
      );

    await this.prisma.ingredientCategory.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
  }

  // ─────────────────────────────────────────────────────────
  // HELPERS
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
