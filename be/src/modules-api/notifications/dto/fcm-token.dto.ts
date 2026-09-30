import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsNotEmpty, IsIn, IsOptional, MaxLength } from 'class-validator';

export class RegisterFcmTokenDto {
  @ApiProperty({ example: 'fcm_token_string_here', description: 'FCM Device Token từ Firebase SDK' })
  @IsString()
  @IsNotEmpty()
  token!: string;

  @ApiProperty({ example: 'android', enum: ['android', 'ios', 'web'] })
  @IsIn(['android', 'ios', 'web'])
  platform!: string;

  @ApiPropertyOptional({ example: 'Samsung Galaxy S24', description: 'Tên thiết bị (optional)' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  deviceName?: string;
}

export class RemoveFcmTokenDto {
  @ApiProperty({ example: 'fcm_token_string_here', description: 'FCM Token cần xóa (khi logout)' })
  @IsString()
  @IsNotEmpty()
  token!: string;
}

export class FcmTokenResponseDto {
  @ApiProperty({ example: 'Đã đăng ký thiết bị thành công' })
  message!: string;
}
