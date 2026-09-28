/**
 * AdminAiService — Dịch vụ quản lý cấu hình AI cho admin
 *
 * Cho phép admin:
 * - Thêm/xóa AI provider (tự động mã hóa API key bằng AES-256)
 * - Kích hoạt provider (chỉ 1 provider active tại 1 thời điểm)
 * - Quản lý system prompt theo từng loại agent
 *
 * Khi admin thay đổi provider active → gọi AiProviderService.invalidateCache()
 * để client mới được tạo lại với cấu hình mới.
 */
import {
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from 'src/modules-system/prisma/prisma.service';
import { encrypt } from 'src/common/utils/encrypt.util';
import type {
  CreateAiProviderDto,
  CreateAiPromptDto,
} from './dto/admin-ai.dto';
import type {
  AiProviderResponseDto,
  AiPromptResponseDto,
  AiPromptDetailResponseDto,
  ActivateResponseDto,
} from './dto/admin-ai-response.dto';

@Injectable()
export class AdminAiService {
  constructor(private readonly prisma: PrismaService) {}

  // ─────────────────────────────────────────────────────────
  // Quản lý AI Provider
  // ─────────────────────────────────────────────────────────

  /** Lấy danh sách tất cả provider (kể cả đã xóa mềm, để admin xem lịch sử) */
  async getProviders(): Promise<AiProviderResponseDto[]> {
    const providers = await this.prisma.aiProviderConfig.findMany({
      where: { deletedAt: null },
      orderBy: [{ isActive: 'desc' }, { createdAt: 'desc' }],
    });

    return providers.map((p): AiProviderResponseDto => ({
      id: p.id,
      provider: p.provider,
      modelName: p.modelName,
      isActive: p.isActive,
      temperature: p.temperature,
      maxTokens: p.maxTokens,
      usageNote: p.usageNote,
      activatedAt: p.activatedAt?.toISOString() ?? null,
      createdAt: p.createdAt.toISOString(),
      // Không trả về encryptedApiKey — bảo mật
    }));
  }

  /**
   * Thêm AI provider mới.
   * API key thô sẽ được mã hóa AES-256 trước khi lưu vào DB.
   * Không tự động active — admin phải gọi endpoint activate riêng.
   */
  async createProvider(
    dto: CreateAiProviderDto,
    activatedByUserId: string,
  ): Promise<AiProviderResponseDto> {
    // Kiểm tra trùng lặp provider + model
    const existing = await this.prisma.aiProviderConfig.findFirst({
      where: {
        provider: dto.provider as any,
        modelName: dto.modelName,
        deletedAt: null,
      },
    });
    if (existing) {
      throw new ConflictException(
        `Provider ${dto.provider} với model ${dto.modelName} đã tồn tại`,
      );
    }

    // Mã hóa API key trước khi lưu (AI Service sẽ decrypt khi đọc)
    const encryptedApiKey = encrypt(dto.apiKey);

    const provider = await this.prisma.aiProviderConfig.create({
      data: {
        provider: dto.provider as any,
        modelName: dto.modelName,
        encryptedApiKey,
        isActive: false, // Mặc định không active — admin phải kích hoạt thủ công
        temperature: dto.temperature ?? 0.7,
        maxTokens: dto.maxTokens ?? 8192,
        usageNote: dto.usageNote ?? null,
        activatedBy: activatedByUserId,
      },
    });

    return {
      id: provider.id,
      provider: provider.provider,
      modelName: provider.modelName,
      isActive: provider.isActive,
      temperature: provider.temperature,
      maxTokens: provider.maxTokens,
      usageNote: provider.usageNote,
      activatedAt: provider.activatedAt?.toISOString() ?? null,
      createdAt: provider.createdAt.toISOString(),
    } satisfies AiProviderResponseDto;
  }

  /**
   * Kích hoạt 1 provider và tự động tắt tất cả provider khác.
   * Hệ thống chỉ dùng 1 provider active tại 1 thời điểm.
   * Sau khi activate → xóa cache để client mới được tạo.
   */
  async activateProvider(
    id: number,
    activatedByUserId: string,
  ): Promise<ActivateResponseDto> {
    const provider = await this.prisma.aiProviderConfig.findFirst({
      where: { id, deletedAt: null },
    });
    if (!provider) throw new NotFoundException('Không tìm thấy AI provider');

    // Transaction: tắt tất cả → bật provider được chọn
    await this.prisma.$transaction([
      // Bước 1: Tắt tất cả provider đang active
      this.prisma.aiProviderConfig.updateMany({
        where: { isActive: true },
        data: { isActive: false },
      }),
      // Bước 2: Kích hoạt provider được chọn
      this.prisma.aiProviderConfig.update({
        where: { id },
        data: {
          isActive: true,
          activatedAt: new Date(),
          activatedBy: activatedByUserId,
        },
      }),
    ]);

    // Lưu ý: AI Service sẽ tự reload cấu hình từ DB trong lần gọi tiếp theo
    // (không cần invalidate cache ở BE nữa vì AI logic đã tách sang ai-service)

    return {
      success: true,
      message: `Đã kích hoạch provider: ${provider.provider} / ${provider.modelName}`,
    } satisfies ActivateResponseDto;
  }

  /** Xóa mềm provider (không thể xóa provider đang active) */
  async deleteProvider(id: number): Promise<void> {
    const provider = await this.prisma.aiProviderConfig.findFirst({
      where: { id, deletedAt: null },
    });
    if (!provider) throw new NotFoundException('Không tìm thấy AI provider');

    if (provider.isActive) {
      throw new ConflictException(
        'Không thể xóa provider đang active. Vui lòng kích hoạt provider khác trước.',
      );
    }

    await this.prisma.aiProviderConfig.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
  }

  // ─────────────────────────────────────────────────────────
  // Quản lý System Prompt
  // ─────────────────────────────────────────────────────────

  /** Lấy danh sách tất cả system prompt (không kèm nội dung để tránh response quá lớn) */
  async getPrompts(): Promise<AiPromptResponseDto[]> {
    const prompts = await this.prisma.aiSystemPrompt.findMany({
      where: { deletedAt: null },
      orderBy: [{ agentType: 'asc' }, { createdAt: 'desc' }],
    });

    return prompts.map((p): AiPromptResponseDto => ({
      id: p.id,
      agentType: p.agentType,
      version: p.version,
      isActive: p.isActive,
      activatedAt: p.activatedAt?.toISOString() ?? null,
      createdAt: p.createdAt.toISOString(),
      // promptContent không được trả về trong danh sách
    }));
  }

  /** Lấy chi tiết 1 prompt (kèm nội dung đầy đủ) */
  async getPromptDetail(id: number): Promise<AiPromptDetailResponseDto> {
    const prompt = await this.prisma.aiSystemPrompt.findFirst({
      where: { id, deletedAt: null },
    });
    if (!prompt) throw new NotFoundException('Không tìm thấy system prompt');

    return {
      id: prompt.id,
      agentType: prompt.agentType,
      version: prompt.version,
      promptContent: prompt.promptContent,
      isActive: prompt.isActive,
      activatedAt: prompt.activatedAt?.toISOString() ?? null,
      createdAt: prompt.createdAt.toISOString(),
    } satisfies AiPromptDetailResponseDto;
  }

  /** Thêm system prompt mới (không tự động active) */
  async createPrompt(
    dto: CreateAiPromptDto,
    createdByUserId: string,
  ): Promise<AiPromptResponseDto> {
    // Kiểm tra trùng agentType + version
    const existing = await this.prisma.aiSystemPrompt.findFirst({
      where: {
        agentType: dto.agentType as any,
        version: dto.version,
        deletedAt: null,
      },
    });
    if (existing) {
      throw new ConflictException(
        `Prompt agentType=${dto.agentType} version=${dto.version} đã tồn tại`,
      );
    }

    const prompt = await this.prisma.aiSystemPrompt.create({
      data: {
        agentType: dto.agentType as any,
        version: dto.version,
        promptContent: dto.promptContent,
        isActive: false,
        activatedBy: createdByUserId,
      },
    });

    return {
      id: prompt.id,
      agentType: prompt.agentType,
      version: prompt.version,
      isActive: prompt.isActive,
      activatedAt: null,
      createdAt: prompt.createdAt.toISOString(),
    } satisfies AiPromptResponseDto;
  }

  /**
   * Kích hoạt 1 prompt cho agentType cụ thể.
   * Chỉ tắt prompt cùng agentType — các agentType khác không bị ảnh hưởng.
   */
  async activatePrompt(
    id: number,
    activatedByUserId: string,
  ): Promise<ActivateResponseDto> {
    const prompt = await this.prisma.aiSystemPrompt.findFirst({
      where: { id, deletedAt: null },
    });
    if (!prompt) throw new NotFoundException('Không tìm thấy system prompt');

    await this.prisma.$transaction([
      // Tắt tất cả prompt cùng agentType
      this.prisma.aiSystemPrompt.updateMany({
        where: { agentType: prompt.agentType, isActive: true },
        data: { isActive: false },
      }),
      // Kích hoạt prompt được chọn
      this.prisma.aiSystemPrompt.update({
        where: { id },
        data: {
          isActive: true,
          activatedAt: new Date(),
          activatedBy: activatedByUserId,
        },
      }),
    ]);

    return {
      success: true,
      message: `Đã kích hoạt prompt: agentType=${prompt.agentType} v${prompt.version}`,
    } satisfies ActivateResponseDto;
  }

  /**
   * Chỉnh sửa nội dung prompt (không cần tạo version mới cho sửa nhỏ).
   * Không cho phép sửa prompt đang isActive.
   */
  async updatePrompt(
    id: number,
    dto: Partial<Pick<import('./dto/admin-ai.dto').CreateAiPromptDto, 'version' | 'promptContent'>>,
  ): Promise<AiPromptDetailResponseDto> {
    const prompt = await this.prisma.aiSystemPrompt.findFirst({
      where: { id, deletedAt: null },
    });
    if (!prompt) throw new NotFoundException('Không tìm thấy system prompt');

    if (prompt.isActive) {
      throw new ConflictException(
        'Không thể sửa prompt đang active. Hãy tạo version mới và activate.',
      );
    }

    const updated = await this.prisma.aiSystemPrompt.update({
      where: { id },
      data: {
        ...(dto.version && { version: dto.version }),
        ...(dto.promptContent && { promptContent: dto.promptContent }),
      },
    });

    return {
      id: updated.id,
      agentType: updated.agentType,
      version: updated.version,
      promptContent: updated.promptContent,
      isActive: updated.isActive,
      activatedAt: updated.activatedAt?.toISOString() ?? null,
      createdAt: updated.createdAt.toISOString(),
    } satisfies AiPromptDetailResponseDto;
  }

  /**
   * Xóa mềm prompt (không xóa prompt đang isActive).
   */
  async deletePrompt(id: number): Promise<void> {
    const prompt = await this.prisma.aiSystemPrompt.findFirst({
      where: { id, deletedAt: null },
    });
    if (!prompt) throw new NotFoundException('Không tìm thấy system prompt');

    if (prompt.isActive) {
      throw new ConflictException(
        'Không thể xóa prompt đang active. Hãy activate prompt khác trước.',
      );
    }

    await this.prisma.aiSystemPrompt.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
  }
}
