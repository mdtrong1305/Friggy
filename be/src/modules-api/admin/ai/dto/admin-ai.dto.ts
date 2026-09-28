import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsNotEmpty, IsNumber, IsOptional, IsInt, Min, Max } from 'class-validator';
import { Type } from 'class-transformer';

// ─── Input DTOs ───────────────────────────────────────────────────────────────

export class CreateAiProviderDto {
  @ApiProperty({
    example: 'gemini',
    description: 'Tên provider: gemini | openai | anthropic',
  })
  @IsString() @IsNotEmpty()
  provider!: string;

  @ApiProperty({
    example: 'gemini-2.0-flash',
    description: 'Tên model cụ thể của provider',
  })
  @IsString() @IsNotEmpty()
  modelName!: string;

  @ApiProperty({
    example: 'sk-or-v1-abc123...',
    description: 'API key thô (chưa mã hóa) — hệ thống tự mã hóa AES-256 trước khi lưu',
  })
  @IsString() @IsNotEmpty()
  apiKey!: string;

  @ApiPropertyOptional({
    example: 'baseURL=https://openrouter.ai/api/v1',
    description: 'Ghi chú sử dụng. Để chỉ định base URL tùy chỉnh, dùng format: "baseURL=https://..."',
  })
  @IsOptional() @IsString()
  usageNote?: string;

  @ApiPropertyOptional({ example: 0.7, description: 'Độ sáng tạo (0.0 - 2.0)' })
  @IsOptional() @IsNumber() @Min(0) @Max(2) @Type(() => Number)
  temperature?: number;

  @ApiPropertyOptional({ example: 8192, description: 'Giới hạn số token output tối đa' })
  @IsOptional() @IsInt() @Min(1) @Type(() => Number)
  maxTokens?: number;
}

export class CreateAiPromptDto {
  @ApiProperty({
    example: 'supervisor',
    description:
      'Loại agent: supervisor | public_chat | chef_agent | data_agent | evaluator | nutrition_agent | accountant_agent',
  })
  @IsString() @IsNotEmpty()
  agentType!: string;

  @ApiProperty({ example: 'v1.1', description: 'Phiên bản prompt (dùng để tracking thay đổi)' })
  @IsString() @IsNotEmpty()
  version!: string;

  @ApiProperty({
    example: 'Bạn là trợ lý AI của Friggy...',
    description: 'Nội dung system prompt đầy đủ',
  })
  @IsString() @IsNotEmpty()
  promptContent!: string;
}

export class UpdateAiPromptDto {
  @ApiPropertyOptional({ example: 'v1.1', description: 'Phiên bản mới' })
  @IsOptional() @IsString() @IsNotEmpty()
  version?: string;

  @ApiPropertyOptional({
    example: 'Bạn là trợ lý AI của Friggy...',
    description: 'Nội dung prompt mới (chỉ cho prompt chưa active)',
  })
  @IsOptional() @IsString() @IsNotEmpty()
  promptContent?: string;
}
