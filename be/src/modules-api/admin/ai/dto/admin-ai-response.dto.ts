import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

// ─── AI Provider ─────────────────────────────────────────────────────────────

export class AiProviderResponseDto {
  @ApiProperty({ example: 1, description: 'ID provider trong DB' }) id!: number;
  @ApiProperty({ example: 'gemini', description: 'Tên provider: gemini | openai | anthropic' }) provider!: string;
  @ApiProperty({ example: 'gemini-2.0-flash', description: 'Tên model cụ thể' }) modelName!: string;
  @ApiProperty({ example: true, description: 'Provider đang được kích hoạt' }) isActive!: boolean;
  @ApiProperty({ example: 0.7, description: 'Độ sáng tạo (0.0 - 2.0)' }) temperature!: number;
  @ApiProperty({ example: 8192, description: 'Giới hạn token output tối đa' }) maxTokens!: number;
  @ApiPropertyOptional({ example: 'baseURL=https://openrouter.ai/api/v1', description: 'Ghi chú sử dụng (chứa baseURL nếu dùng proxy)' }) usageNote!: string | null;
  @ApiPropertyOptional({ example: '2026-09-14T00:00:00Z', description: 'Thời điểm được kích hoạt' }) activatedAt!: string | null;
  @ApiProperty({ example: '2026-09-14T00:00:00Z' }) createdAt!: string;
}

// ─── AI System Prompt ─────────────────────────────────────────────────────────

export class AiPromptResponseDto {
  @ApiProperty({ example: 1 }) id!: number;
  @ApiProperty({ example: 'supervisor', description: 'Loại agent: supervisor | chef_agent | data_agent | evaluator' }) agentType!: string;
  @ApiProperty({ example: '1.0.0', description: 'Phiên bản prompt' }) version!: string;
  @ApiProperty({ example: true, description: 'Đang được kích hoạt' }) isActive!: boolean;
  @ApiPropertyOptional({ example: '2026-09-14T00:00:00Z' }) activatedAt!: string | null;
  @ApiProperty({ example: '2026-09-14T00:00:00Z' }) createdAt!: string;
}

/** Chi tiết prompt — kèm nội dung đầy đủ (dùng cho endpoint GET /prompts/:id) */
export class AiPromptDetailResponseDto extends AiPromptResponseDto {
  @ApiProperty({ description: 'Nội dung system prompt đầy đủ' }) promptContent!: string;
}

// ─── Kết quả thao tác kích hoạt ──────────────────────────────────────────────

export class ActivateResponseDto {
  @ApiProperty({ example: true }) success!: boolean;
  @ApiProperty({ example: 'Đã kích hoạt provider: gemini / gemini-2.0-flash' }) message!: string;
}
