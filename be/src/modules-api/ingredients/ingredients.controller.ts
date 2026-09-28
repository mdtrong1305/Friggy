import {
  Controller,
  Get,
  Param,
  Query,
  ParseIntPipe,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiParam,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { IngredientsService } from './ingredients.service';
import { ListIngredientsQueryDto } from './dto/ingredients.dto';
import {
  IngredientResponseDto,
  PaginatedIngredientsDto,
  CategoryResponseDto,
  PurchaseLinkResponseDto,
} from './dto/ingredients-response.dto';

@ApiTags('Ingredients')
@ApiBearerAuth('access-token')
@Controller('ingredients')
export class IngredientsController {
  constructor(private readonly ingredientsService: IngredientsService) {}

  // ─────────────────────────────────────────────────────────
  // GET /categories — Cây danh mục
  // ─────────────────────────────────────────────────────────

  @Get('categories')
  @ApiOperation({ summary: 'Lấy cây danh mục nguyên liệu (có children + defaultShelfLifeDays)' })
  @ApiResponse({ status: 200, type: [CategoryResponseDto] })
  getCategories(): Promise<CategoryResponseDto[]> {
    return this.ingredientsService.getCategories();
  }

  // ─────────────────────────────────────────────────────────
  // GET / — Danh sách có pagination
  // ─────────────────────────────────────────────────────────

  @Get()
  @ApiOperation({ summary: 'Danh sách nguyên liệu (pagination + search + categoryId)' })
  @ApiResponse({ status: 200, type: PaginatedIngredientsDto })
  findAll(@Query() query: ListIngredientsQueryDto): Promise<PaginatedIngredientsDto> {
    return this.ingredientsService.findAll(query);
  }

  // ─────────────────────────────────────────────────────────
  // GET /:id/purchase-links — Link mua TMDT (phải trước /:id)
  // ─────────────────────────────────────────────────────────

  @Get(':id/purchase-links')
  @ApiOperation({ summary: 'Link mua nguyên liệu trên TMDT (Shopee, Lazada...)' })
  @ApiParam({ name: 'id', description: 'Ingredient ID' })
  @ApiResponse({ status: 200, type: [PurchaseLinkResponseDto] })
  @ApiResponse({ status: 404, description: 'Không tìm thấy nguyên liệu' })
  getPurchaseLinks(@Param('id', ParseIntPipe) id: number): Promise<PurchaseLinkResponseDto[]> {
    return this.ingredientsService.getPurchaseLinks(id);
  }

  // ─────────────────────────────────────────────────────────
  // GET /:id — Chi tiết
  // ─────────────────────────────────────────────────────────

  @Get(':id')
  @ApiOperation({ summary: 'Chi tiết nguyên liệu' })
  @ApiParam({ name: 'id', description: 'Ingredient ID' })
  @ApiResponse({ status: 200, type: IngredientResponseDto })
  @ApiResponse({ status: 404, description: 'Không tìm thấy' })
  findOne(@Param('id', ParseIntPipe) id: number): Promise<IngredientResponseDto> {
    return this.ingredientsService.findOne(id);
  }
}
