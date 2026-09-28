import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  ParseIntPipe,
  HttpCode,
  HttpStatus,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiParam,
  ApiResponse,
  ApiBearerAuth,
  ApiConsumes,
} from '@nestjs/swagger';
import { FileInterceptor } from '@nestjs/platform-express';
import { multerIngredientConfig } from 'src/common/configs/multer.config';
import { IngredientsService } from './ingredients.service';
import {
  ListIngredientsQueryDto,
  CreateIngredientDto,
  UpdateIngredientDto,
  CreateCategoryDto,
  UpdateCategoryDto,
} from './dto/ingredients.dto';
import {
  IngredientResponseDto,
  PaginatedIngredientsDto,
  CategoryResponseDto,
  PurchaseLinkResponseDto,
} from './dto/ingredients-response.dto';
import { RolesGuard } from 'src/common/guards/roles.guard';
import { Roles } from 'src/common/decorators/roles.decorator';

@ApiTags('Ingredients')
@ApiBearerAuth('access-token')
@Controller('ingredients')
export class IngredientsController {
  constructor(private readonly ingredientsService: IngredientsService) {}

  // ─────────────────────────────────────────────────────────
  // GET /categories — Cây danh mục (JWT only)
  // ─────────────────────────────────────────────────────────

  @Get('categories')
  @ApiOperation({ summary: 'Lấy cây danh mục nguyên liệu (có children + defaultShelfLifeDays)' })
  @ApiResponse({ status: 200, type: [CategoryResponseDto] })
  getCategories(): Promise<CategoryResponseDto[]> {
    return this.ingredientsService.getCategories();
  }

  // ─────────────────────────────────────────────────────────
  // POST /categories — Tạo danh mục (Admin only)
  // ─────────────────────────────────────────────────────────

  @Post('categories')
  @UseGuards(RolesGuard)
  @Roles('admin')
  @ApiOperation({ summary: '[Admin] Tạo danh mục nguyên liệu mới' })
  @ApiResponse({ status: 201, type: CategoryResponseDto })
  @ApiResponse({ status: 409, description: 'Tên đã tồn tại' })
  createCategory(@Body() dto: CreateCategoryDto): Promise<CategoryResponseDto> {
    return this.ingredientsService.createCategory(dto);
  }

  // ─────────────────────────────────────────────────────────
  // PATCH /categories/:id — Cập nhật danh mục (Admin only)
  // ─────────────────────────────────────────────────────────

  @Patch('categories/:id')
  @UseGuards(RolesGuard)
  @Roles('admin')
  @ApiOperation({ summary: '[Admin] Cập nhật danh mục (tên, icon, defaultShelfLifeDays...)' })
  @ApiParam({ name: 'id', description: 'Category ID' })
  @ApiResponse({ status: 200, type: CategoryResponseDto })
  @ApiResponse({ status: 404, description: 'Không tìm thấy' })
  @ApiResponse({ status: 409, description: 'Tên đã tồn tại' })
  updateCategory(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateCategoryDto,
  ): Promise<CategoryResponseDto> {
    return this.ingredientsService.updateCategory(id, dto);
  }

  // ─────────────────────────────────────────────────────────
  // DELETE /categories/:id — Soft delete (Admin only)
  // ─────────────────────────────────────────────────────────

  @Delete('categories/:id')
  @UseGuards(RolesGuard)
  @Roles('admin')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: '[Admin] Xóa danh mục (soft delete, chặn nếu có nguyên liệu/con)' })
  @ApiParam({ name: 'id', description: 'Category ID' })
  @ApiResponse({ status: 204, description: 'Đã xóa' })
  @ApiResponse({ status: 400, description: 'Có nguyên liệu/con — không thể xóa' })
  removeCategory(@Param('id', ParseIntPipe) id: number): Promise<void> {
    return this.ingredientsService.removeCategory(id);
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
  // GET /:id — Chi tiết
  // ─────────────────────────────────────────────────────────

  @Get(':id')
  @ApiOperation({ summary: 'Chi tiết nguyên liệu' })
  @ApiResponse({ status: 200, type: IngredientResponseDto })
  @ApiResponse({ status: 404, description: 'Không tìm thấy' })
  findOne(@Param('id', ParseIntPipe) id: number): Promise<IngredientResponseDto> {
    return this.ingredientsService.findOne(id);
  }

  // ─────────────────────────────────────────────────────────
  // GET /:id/purchase-links — Link mua TMDT
  // ─────────────────────────────────────────────────────────

  @Get(':id/purchase-links')
  @ApiOperation({ summary: 'Link mua nguyên liệu trên TMDT (Shopee, Lazada...)' })
  @ApiResponse({ status: 200, type: [PurchaseLinkResponseDto] })
  @ApiResponse({ status: 404, description: 'Không tìm thấy nguyên liệu' })
  getPurchaseLinks(@Param('id', ParseIntPipe) id: number): Promise<PurchaseLinkResponseDto[]> {
    return this.ingredientsService.getPurchaseLinks(id);
  }

  // ─────────────────────────────────────────────────────────
  // POST / — Tạo nguyên liệu (Admin only)
  // ─────────────────────────────────────────────────────────

  @Post()
  @UseGuards(RolesGuard)
  @Roles('admin')
  @ApiOperation({ summary: '[Admin] Tạo nguyên liệu mới' })
  @ApiResponse({ status: 201, type: IngredientResponseDto })
  @ApiResponse({ status: 409, description: 'Tên đã tồn tại' })
  create(@Body() dto: CreateIngredientDto): Promise<IngredientResponseDto> {
    return this.ingredientsService.create(dto);
  }

  // ─────────────────────────────────────────────────────────
  // PATCH /:id — Cập nhật (Admin only)
  // ─────────────────────────────────────────────────────────

  @Patch(':id')
  @UseGuards(RolesGuard)
  @Roles('admin')
  @ApiOperation({ summary: '[Admin] Cập nhật nguyên liệu' })
  @ApiResponse({ status: 200, type: IngredientResponseDto })
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateIngredientDto,
  ): Promise<IngredientResponseDto> {
    return this.ingredientsService.update(id, dto);
  }

  // ─────────────────────────────────────────────────────────
  // POST /:id/image — Upload ảnh nguyên liệu (Admin only)
  // ─────────────────────────────────────────────────────────

  @Post(':id/image')
  @UseGuards(RolesGuard)
  @Roles('admin')
  @ApiOperation({ summary: '[Admin] Upload ảnh nguyên liệu (JPEG/PNG/WEBP, tối đa 5MB)' })
  @ApiConsumes('multipart/form-data')
  @ApiParam({ name: 'id', description: 'Ingredient ID' })
  @ApiResponse({ status: 200, type: IngredientResponseDto })
  @ApiResponse({ status: 404, description: 'Không tìm thấy nguyên liệu' })
  @UseInterceptors(FileInterceptor('file', multerIngredientConfig))
  uploadImage(
    @Param('id', ParseIntPipe) id: number,
    @UploadedFile() file: Express.Multer.File,
  ): Promise<IngredientResponseDto> {
    if (!file) throw new BadRequestException('Chưa chọn file');
    return this.ingredientsService.uploadImage(id, file);
  }

  // ─────────────────────────────────────────────────────────
  // DELETE /:id — Soft delete (Admin only)
  // ─────────────────────────────────────────────────────────

  @Delete(':id')
  @UseGuards(RolesGuard)
  @Roles('admin')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: '[Admin] Xóa nguyên liệu (soft delete)' })
  @ApiResponse({ status: 204, description: 'Đã xóa' })
  remove(@Param('id', ParseIntPipe) id: number): Promise<void> {
    return this.ingredientsService.remove(id);
  }
}
