import {
  Controller, Post, Patch, Delete,
  Body, Param,
  HttpCode, HttpStatus,
} from '@nestjs/common';
import {
  ApiTags, ApiBearerAuth, ApiOperation,
  ApiParam, ApiResponse,
} from '@nestjs/swagger';
import { Roles } from 'src/common/decorators/roles.decorator';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import type { JwtPayload } from 'src/common/interfaces/jwt-payload.interface';
import { AdminRecipesService } from './admin-recipes.service';
import {
  CreateRecipeDto,
  UpdateRecipeDto,
} from './dto/recipes.dto';
import { RecipeDetailDto } from './dto/recipes-response.dto';

@ApiTags('Admin / Recipes')
@ApiBearerAuth('access-token')
@Roles('admin')
@Controller('admin/recipes')
export class AdminRecipesController {
  constructor(private readonly recipesService: AdminRecipesService) {}

  // ─────────────────────────────────────────────────────────
  // POST / — Tạo công thức
  // ─────────────────────────────────────────────────────────

  @Post()
  @ApiOperation({ summary: '[Admin] Tạo công thức mới (kèm ingredients + steps + tags)' })
  @ApiResponse({ status: 201, type: RecipeDetailDto })
  create(
    @Body() dto: CreateRecipeDto,
    @CurrentUser() user: JwtPayload,
  ): Promise<RecipeDetailDto> {
    return this.recipesService.create(dto, user.sub);
  }

  // ─────────────────────────────────────────────────────────
  // PATCH /:id — Cập nhật
  // ─────────────────────────────────────────────────────────

  @Patch(':id')
  @ApiOperation({ summary: '[Admin] Cập nhật thông tin công thức' })
  @ApiParam({ name: 'id', description: 'Recipe ID (UUID)' })
  @ApiResponse({ status: 200, type: RecipeDetailDto })
  @ApiResponse({ status: 404, description: 'Không tìm thấy' })
  update(
    @Param('id') id: string,
    @Body() dto: UpdateRecipeDto,
    @CurrentUser() user: JwtPayload,
  ): Promise<RecipeDetailDto> {
    return this.recipesService.update(id, dto, user.sub);
  }

  // ─────────────────────────────────────────────────────────
  // DELETE /:id — Soft delete
  // ─────────────────────────────────────────────────────────

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: '[Admin] Xóa công thức (soft delete)' })
  @ApiParam({ name: 'id', description: 'Recipe ID (UUID)' })
  @ApiResponse({ status: 204, description: 'Đã xóa' })
  remove(@Param('id') id: string): Promise<void> {
    return this.recipesService.remove(id);
  }
}
