import {
  Controller, Get, Post, Patch, Delete,
  Body, Param, ParseIntPipe,
  HttpCode, HttpStatus,
  UploadedFile, UseInterceptors, BadRequestException,
} from '@nestjs/common';
import {
  ApiTags, ApiBearerAuth, ApiOperation,
  ApiParam, ApiResponse, ApiConsumes,
} from '@nestjs/swagger';
import { Roles } from 'src/common/decorators/roles.decorator';
import { FileInterceptor } from '@nestjs/platform-express';
import {
  multerIngredientConfig,
  multerCategoryIconConfig,
} from 'src/common/configs/multer.config';
import { AdminIngredientsService } from './admin-ingredients.service';
import {
  CreateIngredientDto,
  UpdateIngredientDto,
  CreateCategoryDto,
  UpdateCategoryDto,
} from './dto/ingredients.dto';
import {
  IngredientResponseDto,
  CategoryResponseDto,
} from './dto/ingredients-response.dto';

@ApiTags('Admin / Ingredients')
@ApiBearerAuth('access-token')
@Roles('admin')
@Controller('admin/ingredients')
export class AdminIngredientsController {
  constructor(private readonly ingredientsService: AdminIngredientsService) {}

  // ─────────────────────────────────────────────────────────
  // Categories
  // ─────────────────────────────────────────────────────────

  @Post('categories')
  @ApiOperation({ summary: '[Admin] Tạo danh mục nguyên liệu mới' })
  @ApiResponse({ status: 201, type: CategoryResponseDto })
  @ApiResponse({ status: 409, description: 'Tên đã tồn tại' })
  createCategory(@Body() dto: CreateCategoryDto): Promise<CategoryResponseDto> {
    return this.ingredientsService.createCategory(dto);
  }

  @Patch('categories/:id')
  @ApiOperation({ summary: '[Admin] Cập nhật danh mục (tên, defaultShelfLifeDays...)' })
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

  @Post('categories/:id/icon')
  @ApiOperation({ summary: '[Admin] Upload icon danh mục (JPEG/PNG/WEBP, tối đa 2MB)' })
  @ApiConsumes('multipart/form-data')
  @ApiParam({ name: 'id', description: 'Category ID' })
  @ApiResponse({ status: 200, type: CategoryResponseDto })
  @ApiResponse({ status: 404, description: 'Không tìm thấy danh mục' })
  @UseInterceptors(FileInterceptor('file', multerCategoryIconConfig))
  uploadCategoryIcon(
    @Param('id', ParseIntPipe) id: number,
    @UploadedFile() file: Express.Multer.File,
  ): Promise<CategoryResponseDto> {
    if (!file) throw new BadRequestException('Chưa chọn file');
    return this.ingredientsService.uploadCategoryIcon(id, file);
  }

  @Delete('categories/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: '[Admin] Xóa danh mục (soft delete, chặn nếu có nguyên liệu/con)' })
  @ApiParam({ name: 'id', description: 'Category ID' })
  @ApiResponse({ status: 204, description: 'Đã xóa' })
  @ApiResponse({ status: 400, description: 'Có nguyên liệu/con — không thể xóa' })
  removeCategory(@Param('id', ParseIntPipe) id: number): Promise<void> {
    return this.ingredientsService.removeCategory(id);
  }

  // ─────────────────────────────────────────────────────────
  // Ingredients
  // ─────────────────────────────────────────────────────────

  @Post()
  @ApiOperation({ summary: '[Admin] Tạo nguyên liệu mới' })
  @ApiResponse({ status: 201, type: IngredientResponseDto })
  @ApiResponse({ status: 409, description: 'Tên đã tồn tại' })
  create(@Body() dto: CreateIngredientDto): Promise<IngredientResponseDto> {
    return this.ingredientsService.create(dto);
  }

  @Patch(':id')
  @ApiOperation({ summary: '[Admin] Cập nhật nguyên liệu' })
  @ApiParam({ name: 'id', description: 'Ingredient ID' })
  @ApiResponse({ status: 200, type: IngredientResponseDto })
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateIngredientDto,
  ): Promise<IngredientResponseDto> {
    return this.ingredientsService.update(id, dto);
  }

  @Post(':id/image')
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

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: '[Admin] Xóa nguyên liệu (soft delete)' })
  @ApiParam({ name: 'id', description: 'Ingredient ID' })
  @ApiResponse({ status: 204, description: 'Đã xóa' })
  remove(@Param('id', ParseIntPipe) id: number): Promise<void> {
    return this.ingredientsService.remove(id);
  }
}
