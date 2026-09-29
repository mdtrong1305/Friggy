import {
  Controller,
  Get,
  Patch,
  Post,
  Delete,
  Body,
  Param,
  HttpCode,
  HttpStatus,
  UploadedFile,
  UseInterceptors,
  BadRequestException,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiConsumes,
} from '@nestjs/swagger';
import { FileInterceptor } from '@nestjs/platform-express';
import { multerAvatarConfig } from 'src/common/configs/multer.config';
import { unlinkSync, existsSync } from 'fs';
import { join } from 'path';
import { UsersService } from './users.service';
import {
  UpdateProfileDto,
  UpdatePreferencesDto,
  OnboardingDto,
  AddAllergyDto,
} from './dto/users.dto';
import {
  MeResponseDto,
  UserPreferenceResponseDto,
  AllergyResponseDto,
  AiUsageResponseDto,
} from './dto/users-response.dto';
import { NotificationsService } from 'src/modules-api/notifications/notifications.service';
import { UpdateNotificationSettingsDto } from 'src/modules-api/notifications/dto/notifications.dto';
import { NotificationSettingsResponseDto } from 'src/modules-api/notifications/dto/notifications-response.dto';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import type { JwtPayload } from 'src/common/interfaces/jwt-payload.interface';

@ApiTags('Users')
@ApiBearerAuth('access-token')
@Controller('users')
export class UsersController {
  constructor(
    private readonly usersService: UsersService,
    private readonly notificationsService: NotificationsService,
  ) { }

  // ─────────────────────────────────────────────────────────
  // GET /me
  // ─────────────────────────────────────────────────────────

  @Get('me')
  @ApiOperation({ summary: 'Lấy thông tin hồ sơ người dùng hiện tại' })
  @ApiResponse({ status: 200, description: 'Thông tin user', type: MeResponseDto })
  async getMe(@CurrentUser() user: JwtPayload): Promise<MeResponseDto> {
    return this.usersService.getMe(user.sub);
  }

  // ─────────────────────────────────────────────────────────
  // PATCH /me/profile
  // ─────────────────────────────────────────────────────────

  @Patch('me/profile')
  @ApiOperation({ summary: 'Cập nhật tên, giới tính, ngày sinh, bio' })
  @ApiResponse({ status: 200, description: 'Hồ sơ đã cập nhật', type: MeResponseDto })
  async updateProfile(
    @CurrentUser() user: JwtPayload,
    @Body() dto: UpdateProfileDto,
  ): Promise<MeResponseDto> {
    return this.usersService.updateProfile(user.sub, dto);
  }

  // ─────────────────────────────────────────────────────────
  // AVATAR
  // ─────────────────────────────────────────────────────────

  @Post('me/avatar')
  @ApiOperation({ summary: 'Upload ảnh đại diện (JPEG/PNG/WEBP, tối đa 5MB)' })
  @ApiConsumes('multipart/form-data')
  @ApiResponse({ status: 200, description: 'Avatar URL mới', schema: { example: { avatarUrl: '/avatars/uuid.jpg' } } })
  @UseInterceptors(FileInterceptor('file', multerAvatarConfig))
  async uploadAvatar(
    @CurrentUser() user: JwtPayload,
    @UploadedFile() file: Express.Multer.File,
  ): Promise<{ avatarUrl: string }> {
    if (!file) throw new BadRequestException('Chưa chọn file');

    // Xóa avatar cũ nếu có
    const profile = await this.usersService.getProfile(user.sub);
    if (profile?.avatarPath) {
      const oldPath = join(process.cwd(), 'public', profile.avatarPath);
      if (existsSync(oldPath)) unlinkSync(oldPath);
    }

    const avatarUrl = `/avatars/${file.filename}`;
    await this.usersService.updateAvatarUrl(user.sub, avatarUrl);
    return { avatarUrl };
  }

  // ─────────────────────────────────────────────────────────
  // PREFERENCES
  // ─────────────────────────────────────────────────────────

  @Get('me/preferences')
  @ApiOperation({ summary: 'Lấy tùy chọn cá nhân (ngân sách, chế độ ăn, kỹ năng...)' })
  @ApiResponse({ status: 200, type: UserPreferenceResponseDto })
  async getPreferences(@CurrentUser() user: JwtPayload): Promise<UserPreferenceResponseDto | null> {
    return this.usersService.getPreferences(user.sub);
  }

  @Patch('me/preferences')
  @ApiOperation({ summary: 'Cập nhật tùy chọn cá nhân' })
  @ApiResponse({ status: 200, type: UserPreferenceResponseDto })
  async updatePreferences(
    @CurrentUser() user: JwtPayload,
    @Body() dto: UpdatePreferencesDto,
  ): Promise<UserPreferenceResponseDto> {
    return this.usersService.updatePreferences(user.sub, dto);
  }

  // ─────────────────────────────────────────────────────────
  // ONBOARDING
  // ─────────────────────────────────────────────────────────

  @Post('me/onboarding')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Hoàn thành survey onboarding 4 bước → isOnboardingCompleted = true' })
  @ApiResponse({ status: 200, description: 'Onboarding hoàn tất', type: MeResponseDto })
  async completeOnboarding(
    @CurrentUser() user: JwtPayload,
    @Body() dto: OnboardingDto,
  ): Promise<MeResponseDto> {
    return this.usersService.completeOnboarding(user.sub, dto);
  }

  // ─────────────────────────────────────────────────────────
  // ALLERGIES
  // ─────────────────────────────────────────────────────────

  @Get('me/allergies')
  @ApiOperation({ summary: 'Danh sách dị ứng nguyên liệu' })
  @ApiResponse({ status: 200, type: [AllergyResponseDto] })
  async getAllergies(@CurrentUser() user: JwtPayload): Promise<AllergyResponseDto[]> {
    return this.usersService.getAllergies(user.sub);
  }

  @Post('me/allergies')
  @ApiOperation({ summary: 'Thêm dị ứng nguyên liệu' })
  @ApiResponse({ status: 201, type: AllergyResponseDto })
  @ApiResponse({ status: 400, description: 'Nguyên liệu đã có trong DS dị ứng' })
  async addAllergy(
    @CurrentUser() user: JwtPayload,
    @Body() dto: AddAllergyDto,
  ): Promise<AllergyResponseDto> {
    return this.usersService.addAllergy(user.sub, dto);
  }

  @Delete('me/allergies/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Xóa dị ứng nguyên liệu (soft delete)' })
  @ApiResponse({ status: 204, description: 'Đã xóa' })
  @ApiResponse({ status: 404, description: 'Không tìm thấy' })
  async removeAllergy(
    @CurrentUser() user: JwtPayload,
    @Param('id') allergyId: string,
  ): Promise<void> {
    return this.usersService.removeAllergy(user.sub, allergyId);
  }

  // ─────────────────────────────────────────────────────────
  // AI USAGE
  // ─────────────────────────────────────────────────────────

  @Get('me/ai-usage')
  @ApiOperation({ summary: 'Số lượt AI đã dùng trong tuần hiện tại' })
  @ApiResponse({ status: 200, type: AiUsageResponseDto })
  async getAiUsage(@CurrentUser() user: JwtPayload): Promise<AiUsageResponseDto> {
    return this.usersService.getAiUsage(user.sub);
  }

  // ─────────────────────────────────────────────────────────
  // NOTIFICATION SETTINGS
  // ─────────────────────────────────────────────────────────

  @Get('me/notification-settings')
  @ApiOperation({ summary: 'Lấy cài đặt thông báo' })
  @ApiResponse({ status: 200, type: NotificationSettingsResponseDto })
  getNotificationSettings(@CurrentUser() user: JwtPayload): Promise<NotificationSettingsResponseDto> {
    return this.notificationsService.getNotificationSettings(user.sub);
  }

  @Patch('me/notification-settings')
  @ApiOperation({ summary: 'Cập nhật cài đặt thông báo (push, expiry alert, shopping reminder)' })
  @ApiResponse({ status: 200, type: NotificationSettingsResponseDto })
  updateNotificationSettings(
    @CurrentUser() user: JwtPayload,
    @Body() dto: UpdateNotificationSettingsDto,
  ): Promise<NotificationSettingsResponseDto> {
    return this.notificationsService.updateNotificationSettings(user.sub, dto);
  }
}
