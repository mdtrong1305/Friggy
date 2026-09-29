import {
  Injectable,
  BadRequestException,
  UnauthorizedException,
  ForbiddenException,
  ConflictException,
  InternalServerErrorException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from 'src/modules-system/prisma/prisma.service';
import { TokensService } from 'src/modules-system/tokens/tokens.service';
import { generateOtp, hashOtp, verifyOtp } from 'src/common/utils/otp.util';
import { OAuth2Client } from 'google-auth-library';
import { v4 as uuid } from 'uuid';
import * as bcrypt from 'bcryptjs';
import {
  EmailRegisterDto,
  EmailLoginDto,
  VerifyEmailOtpDto,
  ForgotPasswordDto,
  ResetPasswordDto,
  ChangePasswordDto,
  GoogleAuthDto,
  RefreshTokenDto,
  LogoutDto,
} from './dto/auth.dto';
import {
  AuthResponseDto,
  OtpSentResponseDto,
  MessageResponseDto,
  RefreshResponseDto,
} from './dto/auth-response.dto';
import { ClientProxy } from '@nestjs/microservices';
import { Inject } from '@nestjs/common';

const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID ?? '';
const OTP_TTL_SECONDS = 300; // 5 phút
const OTP_MAX_ATTEMPTS = 5;
const OTP_RATE_LIMIT_MAX = 3;
const OTP_RATE_LIMIT_WINDOW_MINUTES = 10;
const BCRYPT_ROUNDS = 10;

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  private readonly googleClient = new OAuth2Client(GOOGLE_CLIENT_ID);

  constructor(
    private readonly prisma: PrismaService,
    private readonly tokensService: TokensService,
    @Inject('EMAIL_SERVICE') private readonly emailClient: ClientProxy,
  ) { }

  // ─────────────────────────────────────────────────────────
  // EMAIL REGISTER
  // ─────────────────────────────────────────────────────────

  async emailRegister(dto: EmailRegisterDto): Promise<OtpSentResponseDto> {
    const email = dto.email.toLowerCase().trim();

    // 1. Kiểm tra email đã tồn tại — cả email/password lẫn Google account
    const existing = await this.prisma.user.findFirst({
      where: {
        OR: [
          { email },
          { googleEmail: email }, // user đã đăng ký qua Google với email này
        ],
      },
    });
    if (existing) {
      if (existing.authProvider === 'google' && !existing.passwordHash) {
        throw new ConflictException(
          'Email này đã được liên kết với tài khoản Google. Vui lòng đăng nhập bằng Google.',
        );
      }
      throw new ConflictException('Email này đã được đăng ký');
    }

    // 2. Rate limit OTP
    await this.checkOtpRateLimit(email);

    // 3. Sinh OTP + lưu DB
    const otp = generateOtp();
    const otpHash = await hashOtp(otp);
    const expiresAt = new Date(Date.now() + OTP_TTL_SECONDS * 1000);

    await this.prisma.emailOtp.create({
      data: { id: uuid(), email, otpHash, purpose: 'register', expiresAt },
    });

    // 4. Gửi email qua email-service (RabbitMQ)
    this.emailClient.emit('email.send', {
      type: 'otp',
      to: email,
      data: { otp, purpose: 'register' },
    });

    this.logger.log(`📧 OTP register gửi tới ${email}`);
    return {
      message: `Mã OTP đã được gửi tới ${email}`,
      expiresIn: OTP_TTL_SECONDS,
    };
  }

  // ─────────────────────────────────────────────────────────
  // VERIFY EMAIL OTP → Kích hoạt tài khoản + JWT
  // ─────────────────────────────────────────────────────────

  async verifyEmailOtp(
    dto: VerifyEmailOtpDto,
    passwordHash: string,
    name: string | undefined,
    deviceInfo?: string,
    ipAddress?: string,
  ): Promise<AuthResponseDto> {
    const email = dto.email.toLowerCase().trim();

    // 1. Kiểm tra OTP
    const otpRecord = await this.findValidOtp(email, 'register');
    await this.validateOtpAttempt(otpRecord, dto.otpCode);

    // 2. Lấy role
    const userRole = await this.prisma.role.findFirst({
      where: { name: 'user' },
    });
    if (!userRole)
      throw new InternalServerErrorException('Cấu hình role không tồn tại');

    // 3. Tạo user
    const user = await this.prisma.user.create({
      data: {
        id: uuid(),
        email,
        passwordHash,
        name: name ?? null,
        authProvider: 'email',
        status: 'active',
        roleId: userRole.id,
        isOnboardingCompleted: false,
        lastLoginAt: new Date(),
      },
      include: { role: true },
    });

    // 4. Tạo UserProfile
    if (name) {
      await this.prisma.userProfile.create({
        data: { id: uuid(), userId: user.id, displayName: name },
      });
    }

    // 5. Gán gói Free
    await this.assignFreePlan(user.id);

    // 6. Gửi email chào mừng
    this.emailClient.emit('email.send', {
      type: 'welcome',
      to: email,
      data: { name: name ?? 'bạn' },
    });

    // 7. Sinh tokens
    const tokens = await this.tokensService.generateTokenPair(
      user.id,
      user.role.name,
      deviceInfo,
      ipAddress,
    );

    return {
      ...tokens,
      isNewUser: true,
      user: {
        id: user.id,
        name: user.name ?? null,
        email: user.email ?? null,
        googleEmail: user.googleEmail ?? null,
        status: user.status,
        role: user.role.name,
        isOnboardingCompleted: user.isOnboardingCompleted,
      },
    };
  }

  // ─────────────────────────────────────────────────────────
  // EMAIL LOGIN
  // ─────────────────────────────────────────────────────────

  async emailLogin(
    dto: EmailLoginDto,
    deviceInfo?: string,
    ipAddress?: string,
  ): Promise<AuthResponseDto> {
    const email = dto.email.toLowerCase().trim();

    const user = await this.prisma.user.findUnique({
      where: { email },
      include: { role: true },
    });

    if (!user || !user.passwordHash) {
      throw new UnauthorizedException('Email hoặc mật khẩu không chính xác');
    }

    if (user.status === 'suspended') {
      throw new ForbiddenException('Tài khoản của bạn đã bị khoá');
    }

    const passwordValid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!passwordValid) {
      throw new UnauthorizedException('Email hoặc mật khẩu không chính xác');
    }

    await this.prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });

    const tokens = await this.tokensService.generateTokenPair(
      user.id,
      user.role.name,
      deviceInfo,
      ipAddress,
    );

    return {
      ...tokens,
      isNewUser: false,
      user: {
        id: user.id,
        name: user.name ?? null,
        email: user.email ?? null,
        googleEmail: user.googleEmail ?? null,
        status: user.status,
        role: user.role.name,
        isOnboardingCompleted: user.isOnboardingCompleted,
      },
    };
  }

  // ─────────────────────────────────────────────────────────
  // FORGOT PASSWORD — Gửi OTP
  // ─────────────────────────────────────────────────────────

  async forgotPassword(dto: ForgotPasswordDto): Promise<OtpSentResponseDto> {
    const email = dto.email.toLowerCase().trim();

    // Không tiết lộ email có tồn tại không (security best practice)
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user || user.authProvider !== 'email') {
      return {
        message: `Nếu email tồn tại, OTP đã được gửi tới ${email}`,
        expiresIn: OTP_TTL_SECONDS,
      };
    }

    await this.checkOtpRateLimit(email);

    const otp = generateOtp();
    const otpHash = await hashOtp(otp);
    await this.prisma.emailOtp.create({
      data: {
        id: uuid(),
        email,
        otpHash,
        purpose: 'reset_password',
        expiresAt: new Date(Date.now() + OTP_TTL_SECONDS * 1000),
      },
    });

    this.emailClient.emit('email.send', {
      type: 'otp',
      to: email,
      data: { otp, purpose: 'reset_password' },
    });

    return {
      message: `Nếu email tồn tại, OTP đã được gửi tới ${email}`,
      expiresIn: OTP_TTL_SECONDS,
    };
  }

  // ─────────────────────────────────────────────────────────
  // RESET PASSWORD — Xác nhận OTP + đặt mật khẩu mới
  // ─────────────────────────────────────────────────────────

  async resetPassword(dto: ResetPasswordDto): Promise<MessageResponseDto> {
    const email = dto.email.toLowerCase().trim();

    const otpRecord = await this.findValidOtp(email, 'reset_password');
    await this.validateOtpAttempt(otpRecord, dto.otpCode);

    const passwordHash = await bcrypt.hash(dto.newPassword, BCRYPT_ROUNDS);
    await this.prisma.user.update({
      where: { email },
      data: { passwordHash },
    });

    this.logger.log(`🔐 Đổi mật khẩu thành công cho ${email}`);
    return { message: 'Mật khẩu đã được đặt lại thành công' };
  }

  // ─────────────────────────────────────────────────────────
  // CHANGE PASSWORD — Đổi mật khẩu khi đã đăng nhập
  // ─────────────────────────────────────────────────────────

  async changePassword(
    userId: string,
    dto: ChangePasswordDto,
  ): Promise<MessageResponseDto> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user || !user.passwordHash) {
      throw new BadRequestException('Tài khoản không dùng email + mật khẩu');
    }

    const valid = await bcrypt.compare(dto.currentPassword, user.passwordHash);
    if (!valid) {
      throw new BadRequestException('Mật khẩu hiện tại không đúng');
    }

    const newHash = await bcrypt.hash(dto.newPassword, BCRYPT_ROUNDS);
    await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash: newHash },
    });

    // Gửi email xác nhận
    if (user.email) {
      this.emailClient.emit('email.send', {
        type: 'password_changed',
        to: user.email,
        data: { name: user.name ?? 'bạn' },
      });
    }

    return { message: 'Mật khẩu đã được thay đổi thành công' };
  }

  // ─────────────────────────────────────────────────────────
  // GOOGLE AUTH (giữ nguyên logic, chỉ đổi field phone→email)
  // ─────────────────────────────────────────────────────────

  async googleAuth(
    dto: GoogleAuthDto,
    deviceInfo?: string,
    ipAddress?: string,
  ): Promise<AuthResponseDto> {
    let googlePayload: { sub: string; email?: string; name?: string };
    try {
      const ticket = await this.googleClient.verifyIdToken({
        idToken: dto.idToken,
        audience: GOOGLE_CLIENT_ID || undefined,
      });
      const p = ticket.getPayload();
      if (!p?.sub) throw new Error('No sub in Google payload');
      googlePayload = { sub: p.sub, email: p.email, name: p.name };
    } catch (err) {
      this.logger.warn(`Google verify failed: ${err}`);
      throw new UnauthorizedException('Google ID Token không hợp lệ');
    }

    const userRole = await this.prisma.role.findFirst({
      where: { name: 'user' },
    });
    if (!userRole)
      throw new InternalServerErrorException('Cấu hình role không tồn tại');

    let isNewUser = false;

    // 1. Tìm theo googleId trước (đã login Google trước đó)
    let user = await this.prisma.user.findUnique({
      where: { googleId: googlePayload.sub },
      include: { role: true },
    });

    if (!user && googlePayload.email) {
      // 2. Tìm theo email — có thể là tài khoản email/password đã tồn tại
      const existingByEmail = await this.prisma.user.findUnique({
        where: { email: googlePayload.email.toLowerCase() },
        include: { role: true },
      });

      if (existingByEmail) {
        // Merge: liên kết googleId vào tài khoản email/password đã có
        if (existingByEmail.status === 'suspended') {
          throw new ForbiddenException('Tài khoản của bạn đã bị khoá');
        }
        const updateData: any = {
          googleId: googlePayload.sub,
          googleEmail: googlePayload.email,
          lastLoginAt: new Date(),
        };
        if (!existingByEmail.name && googlePayload.name)
          updateData.name = googlePayload.name;

        user = await this.prisma.user.update({
          where: { id: existingByEmail.id },
          data: updateData,
          include: { role: true },
        });
        this.logger.log(
          `🔗 Merge Google → email account: ${googlePayload.email}`,
        );
      }
    }

    if (!user) {
      // 3. Tạo tài khoản mới hoàn toàn
      isNewUser = true;
      user = await this.prisma.user.create({
        data: {
          id: uuid(),
          googleId: googlePayload.sub,
          googleEmail: googlePayload.email ?? null,
          email: googlePayload.email ? googlePayload.email.toLowerCase() : null,
          name: googlePayload.name ?? null,
          authProvider: 'google',
          status: 'active',
          roleId: userRole.id,
          isOnboardingCompleted: false,
          lastLoginAt: new Date(),
        },
        include: { role: true },
      });

      if (googlePayload.name) {
        await this.prisma.userProfile.create({
          data: {
            id: uuid(),
            userId: user.id,
            displayName: googlePayload.name,
          },
        });
      }
      await this.assignFreePlan(user.id);

      // Gửi welcome email cho user mới qua Google
      if (googlePayload.email) {
        this.emailClient.emit('email.send', {
          type: 'welcome',
          to: googlePayload.email,
          data: { name: googlePayload.name ?? 'bạn' },
        });
      }
    } else {
      if (user.status === 'suspended')
        throw new ForbiddenException('Tài khoản của bạn đã bị khoá');
      const updateData: any = { lastLoginAt: new Date() };
      if (!user.name && googlePayload.name)
        updateData.name = googlePayload.name;
      // Cập nhật googleId nếu chưa có (trường hợp merge)
      if (!user.googleId) updateData.googleId = googlePayload.sub;
      if (!user.googleEmail && googlePayload.email)
        updateData.googleEmail = googlePayload.email;
      user = await this.prisma.user.update({
        where: { id: user.id },
        data: updateData,
        include: { role: true },
      });
    }

    const tokens = await this.tokensService.generateTokenPair(
      user.id,
      user.role.name,
      deviceInfo,
      ipAddress,
    );

    return {
      ...tokens,
      isNewUser,
      user: {
        id: user.id,
        name: user.name ?? null,
        email: user.email ?? null,
        googleEmail: user.googleEmail ?? null,
        status: user.status,
        role: user.role.name,
        isOnboardingCompleted: user.isOnboardingCompleted,
      },
    };
  }

  // ─────────────────────────────────────────────────────────
  // REFRESH TOKEN
  // ─────────────────────────────────────────────────────────

  async refresh(dto: RefreshTokenDto): Promise<RefreshResponseDto> {
    const payload = await this.tokensService.verifyRefreshToken(
      dto.refreshToken,
    );
    if (!payload)
      throw new UnauthorizedException(
        'Refresh token không hợp lệ hoặc đã hết hạn',
      );
    const accessToken = await this.tokensService.refreshAccessToken(payload);
    return { accessToken };
  }

  // ─────────────────────────────────────────────────────────
  // LOGOUT
  // ─────────────────────────────────────────────────────────

  async logout(dto: LogoutDto, userId: string): Promise<void> {
    await this.tokensService.revokeRefreshToken(dto.refreshToken, userId);
  }

  // ─────────────────────────────────────────────────────────
  // PRIVATE HELPERS
  // ─────────────────────────────────────────────────────────

  private async checkOtpRateLimit(email: string): Promise<void> {
    const windowStart = new Date(
      Date.now() - OTP_RATE_LIMIT_WINDOW_MINUTES * 60_000,
    );
    const count = await this.prisma.emailOtp.count({
      where: { email, createdAt: { gt: windowStart } },
    });
    if (count >= OTP_RATE_LIMIT_MAX) {
      throw new BadRequestException(
        `Bạn đã gửi quá ${OTP_RATE_LIMIT_MAX} lần OTP. Vui lòng thử lại sau ${OTP_RATE_LIMIT_WINDOW_MINUTES} phút.`,
      );
    }
  }

  private async findValidOtp(email: string, purpose: string): Promise<any> {
    const record = await this.prisma.emailOtp.findFirst({
      where: { email, purpose: purpose as any, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: 'desc' },
    });
    if (!record)
      throw new BadRequestException('OTP không tồn tại hoặc đã hết hạn');
    return record;
  }

  private async validateOtpAttempt(
    otpRecord: any,
    inputOtp: string,
  ): Promise<void> {
    if (otpRecord.attempts >= OTP_MAX_ATTEMPTS) {
      await this.prisma.emailOtp.delete({ where: { id: otpRecord.id } });
      throw new BadRequestException(
        'OTP đã vượt quá số lần thử. Vui lòng yêu cầu OTP mới.',
      );
    }

    const isValid = await verifyOtp(inputOtp, otpRecord.otpHash);
    if (!isValid) {
      await this.prisma.emailOtp.update({
        where: { id: otpRecord.id },
        data: { attempts: otpRecord.attempts + 1 },
      });
      throw new BadRequestException('OTP không chính xác');
    }

    // Xóa OTP sau khi xác minh thành công
    await this.prisma.emailOtp.delete({ where: { id: otpRecord.id } });
  }

  private async assignFreePlan(userId: string): Promise<void> {
    const freePlan = await this.prisma.subscriptionPlan.findFirst({
      where: { name: 'free', isActive: true },
    });
    if (!freePlan) {
      this.logger.warn(`⚠️ Không tìm thấy gói 'free' trong DB`);
      return;
    }
    const existing = await this.prisma.userSubscription.findUnique({
      where: { userId },
    });
    if (existing) return;

    await this.prisma.userSubscription.create({
      data: {
        id: uuid(),
        userId,
        planId: freePlan.id,
        startDate: new Date(),
        endDate: null,
        status: 'active',
        autoRenew: false, // Free plan không gia hạn tự động
      },
    });
    this.logger.log(`✅ Đã khởi tạo gói Free cho user ${userId}`);
  }
}
