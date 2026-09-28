import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  ParseIntPipe,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import {
  ApiTags,
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiParam,
} from '@nestjs/swagger';
import { AdminAiService } from './admin-ai.service';
import { CreateAiProviderDto, CreateAiPromptDto, UpdateAiPromptDto } from './dto/admin-ai.dto';
import {
  AiProviderResponseDto,
  AiPromptResponseDto,
  AiPromptDetailResponseDto,
  ActivateResponseDto,
} from './dto/admin-ai-response.dto';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import type { JwtPayload } from 'src/common/interfaces/jwt-payload.interface';

@ApiTags('Admin / AI')
@ApiBearerAuth('access-token')
@Controller('admin/ai')
export class AdminAiController {
  constructor(private readonly adminAiService: AdminAiService) {}

  // ══════════════════════════════════════════════════════════
  // AI Provider Management
  // ══════════════════════════════════════════════════════════

  @Get('providers')
  @ApiOperation({ summary: '[Admin] Danh sách tất cả AI provider đã cấu hình' })
  @ApiResponse({ status: 200, type: [AiProviderResponseDto] })
  getProviders(): Promise<AiProviderResponseDto[]> {
    return this.adminAiService.getProviders();
  }

  @Post('providers')
  @ApiOperation({
    summary: '[Admin] Thêm AI provider mới',
    description:
      'Nhập API key thô — hệ thống tự mã hóa AES-256 trước khi lưu DB. ' +
      'Để dùng base URL tùy chỉnh, ghi vào usageNote: "baseURL=https://..."',
  })
  @ApiResponse({ status: 201, type: AiProviderResponseDto })
  @ApiResponse({ status: 409, description: 'Provider + model đã tồn tại' })
  createProvider(
    @Body() dto: CreateAiProviderDto,
    @CurrentUser() user: JwtPayload,
  ): Promise<AiProviderResponseDto> {
    return this.adminAiService.createProvider(dto, user.sub);
  }

  @Patch('providers/:id/activate')
  @ApiOperation({
    summary: '[Admin] Kích hoạt AI provider',
    description:
      'Tự động tắt tất cả provider khác và kích hoạt provider được chọn. ' +
      'Xóa cache in-memory để client mới được tạo lại ngay.',
  })
  @ApiParam({ name: 'id', description: 'ID của provider cần kích hoạt' })
  @ApiResponse({ status: 200, type: ActivateResponseDto })
  @ApiResponse({ status: 404, description: 'Không tìm thấy provider' })
  activateProvider(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() user: JwtPayload,
  ): Promise<ActivateResponseDto> {
    return this.adminAiService.activateProvider(id, user.sub);
  }

  @Delete('providers/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: '[Admin] Xóa AI provider (soft delete, không xóa provider đang active)' })
  @ApiParam({ name: 'id', description: 'ID của provider cần xóa' })
  @ApiResponse({ status: 204, description: 'Xóa thành công' })
  @ApiResponse({ status: 409, description: 'Không thể xóa provider đang active' })
  deleteProvider(@Param('id', ParseIntPipe) id: number): Promise<void> {
    return this.adminAiService.deleteProvider(id);
  }

  // ══════════════════════════════════════════════════════════
  // AI System Prompt Management
  // ══════════════════════════════════════════════════════════

  @Get('prompts')
  @ApiOperation({ summary: '[Admin] Danh sách system prompt (không kèm nội dung)' })
  @ApiResponse({ status: 200, type: [AiPromptResponseDto] })
  getPrompts(): Promise<AiPromptResponseDto[]> {
    return this.adminAiService.getPrompts();
  }

  @Get('prompts/:id')
  @ApiOperation({ summary: '[Admin] Chi tiết system prompt (kèm nội dung đầy đủ)' })
  @ApiParam({ name: 'id', description: 'ID của prompt' })
  @ApiResponse({ status: 200, type: AiPromptDetailResponseDto })
  @ApiResponse({ status: 404, description: 'Không tìm thấy prompt' })
  getPromptDetail(
    @Param('id', ParseIntPipe) id: number,
  ): Promise<AiPromptDetailResponseDto> {
    return this.adminAiService.getPromptDetail(id);
  }

  @Post('prompts')
  @ApiOperation({
    summary: '[Admin] Thêm system prompt mới',
    description: 'Tạo prompt với trạng thái không active. Gọi endpoint activate sau để dùng.',
  })
  @ApiResponse({ status: 201, type: AiPromptResponseDto })
  @ApiResponse({ status: 409, description: 'agentType + version đã tồn tại' })
  createPrompt(
    @Body() dto: CreateAiPromptDto,
    @CurrentUser() user: JwtPayload,
  ): Promise<AiPromptResponseDto> {
    return this.adminAiService.createPrompt(dto, user.sub);
  }

  @Patch('prompts/:id/activate')
  @ApiOperation({
    summary: '[Admin] Kích hoạt system prompt cho agentType',
    description: 'Tắt các prompt cùng agentType và kích hoạt prompt được chọn.',
  })
  @ApiParam({ name: 'id', description: 'ID của prompt cần kích hoạt' })
  @ApiResponse({ status: 200, type: ActivateResponseDto })
  @ApiResponse({ status: 404, description: 'Không tìm thấy prompt' })
  activatePrompt(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() user: JwtPayload,
  ): Promise<ActivateResponseDto> {
    return this.adminAiService.activatePrompt(id, user.sub);
  }

  @Patch('prompts/:id')
  @ApiOperation({
    summary: '[Admin] Sửa nội dung prompt (chỉ được sửa prompt chưa active)',
    description: 'Dùng cho sửa nhỏ (typo, cập nhật câu từ). Không cho phép sửa prompt đang active.',
  })
  @ApiParam({ name: 'id', description: 'ID của prompt cần sửa' })
  @ApiResponse({ status: 200, type: AiPromptDetailResponseDto })
  @ApiResponse({ status: 404, description: 'Không tìm thấy' })
  @ApiResponse({ status: 409, description: 'Prompt đang active — không thể sửa' })
  updatePrompt(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateAiPromptDto,
  ): Promise<AiPromptDetailResponseDto> {
    return this.adminAiService.updatePrompt(id, dto);
  }

  @Delete('prompts/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: '[Admin] Xóa system prompt (soft delete, không xóa prompt đang active)' })
  @ApiParam({ name: 'id', description: 'ID của prompt cần xóa' })
  @ApiResponse({ status: 204, description: 'Đã xóa' })
  @ApiResponse({ status: 409, description: 'Prompt đang active — không thể xóa' })
  deletePrompt(@Param('id', ParseIntPipe) id: number): Promise<void> {
    return this.adminAiService.deletePrompt(id);
  }
}
