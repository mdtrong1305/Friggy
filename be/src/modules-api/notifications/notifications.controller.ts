import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Query,
  Body,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { NotificationsService } from './notifications.service';
import { ListNotificationsQueryDto, UpdateNotificationSettingsDto } from './dto/notifications.dto';
import {
  NotificationResponseDto,
  PaginatedNotificationsDto,
  UnreadCountResponseDto,
  MarkAllReadResponseDto,
  NotificationSettingsResponseDto,
} from './dto/notifications-response.dto';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import type { JwtPayload } from 'src/common/interfaces/jwt-payload.interface';
import { RegisterFcmTokenDto, RemoveFcmTokenDto, FcmTokenResponseDto } from './dto/fcm-token.dto';

@ApiTags('Notifications')
@ApiBearerAuth('access-token')
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  // ─────────────────────────────────────────────────────────
  // GET /unread-count (trước /:id)
  // ─────────────────────────────────────────────────────────

  @Get('unread-count')
  @ApiOperation({ summary: 'Số thông báo chưa đọc' })
  @ApiResponse({ status: 200, type: UnreadCountResponseDto })
  getUnreadCount(@CurrentUser() user: JwtPayload): Promise<UnreadCountResponseDto> {
    return this.notificationsService.getUnreadCount(user.sub);
  }

  // ─────────────────────────────────────────────────────────
  // PATCH /read-all (trước /:id)
  // ─────────────────────────────────────────────────────────

  @Patch('read-all')
  @ApiOperation({ summary: 'Đánh dấu tất cả thông báo đã đọc' })
  @ApiResponse({ status: 200, type: MarkAllReadResponseDto })
  markAllRead(@CurrentUser() user: JwtPayload): Promise<MarkAllReadResponseDto> {
    return this.notificationsService.markAllRead(user.sub);
  }

  // ─────────────────────────────────────────────────────────
  // GET / — Danh sách
  // ─────────────────────────────────────────────────────────

  @Get()
  @ApiOperation({ summary: 'Danh sách thông báo (phân trang, lọc isRead)' })
  @ApiResponse({ status: 200, type: PaginatedNotificationsDto })
  findAll(
    @CurrentUser() user: JwtPayload,
    @Query() query: ListNotificationsQueryDto,
  ): Promise<PaginatedNotificationsDto> {
    return this.notificationsService.findAll(user.sub, query);
  }

  // ─────────────────────────────────────────────────────────
  // PATCH /:id/read
  // ─────────────────────────────────────────────────────────

  @Patch(':id/read')
  @ApiOperation({ summary: 'Đánh dấu 1 thông báo đã đọc' })
  @ApiResponse({ status: 200, type: NotificationResponseDto })
  @ApiResponse({ status: 404, description: 'Không tìm thấy thông báo' })
  markOneRead(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
  ): Promise<NotificationResponseDto> {
    return this.notificationsService.markOneRead(user.sub, id);
  }

  // ─────────────────────────────────────────────────────────
  // DELETE /:id
  // ─────────────────────────────────────────────────────────

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Xóa thông báo (soft delete)' })
  @ApiResponse({ status: 204, description: 'Xóa thành công' })
  @ApiResponse({ status: 404, description: 'Không tìm thấy thông báo' })
  remove(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
  ): Promise<void> {
    return this.notificationsService.remove(user.sub, id);
  }

  // ─────────────────────────────────────────────────────────
  // FCM Token
  // ─────────────────────────────────────────────────────────

  @Post('fcm-token')
  @ApiOperation({
    summary: 'Đăng ký FCM token',
    description: 'Gọi sau khi đăng nhập để nhận push notification. Token sẽ được upsert.',
  })
  @ApiResponse({ status: 201, type: FcmTokenResponseDto })
  registerFcmToken(
    @CurrentUser() user: JwtPayload,
    @Body() dto: RegisterFcmTokenDto,
  ): Promise<FcmTokenResponseDto> {
    return this.notificationsService.registerFcmToken(user.sub, dto);
  }

  @Delete('fcm-token')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Xóa FCM token',
    description: 'Gọi khi logout để ngưng nhận push notification trên thiết bị này.',
  })
  @ApiResponse({ status: 200, type: FcmTokenResponseDto })
  removeFcmToken(
    @CurrentUser() user: JwtPayload,
    @Body() dto: RemoveFcmTokenDto,
  ): Promise<FcmTokenResponseDto> {
    return this.notificationsService.removeFcmToken(user.sub, dto.token);
  }
}
