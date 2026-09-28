import { BadRequestException } from '@nestjs/common';
import { MulterOptions } from '@nestjs/platform-express/multer/interfaces/multer-options.interface';
import { diskStorage } from 'multer';
import { extname, join } from 'path';
import { mkdirSync } from 'fs';
import { v4 as uuid } from 'uuid';

// Các MIME type được phép upload ảnh
const ALLOWED_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

/**
 * Tạo fileFilter chỉ chấp nhận ảnh hợp lệ
 */
const imageFileFilter: MulterOptions['fileFilter'] = (_, file, callback) => {
  if (!ALLOWED_IMAGE_TYPES.includes(file.mimetype)) {
    return callback(
      new BadRequestException(
        `Định dạng file không hợp lệ. Chỉ chấp nhận: JPG, PNG, WEBP`,
      ),
      false,
    );
  }
  callback(null, true);
};

/**
 * Tạo diskStorage với thư mục đích và tên file uuid
 * @param destFn Hàm nhận request trả về đường dẫn thư mục đích (cho phép dynamic theo userId…)
 */
const createStorage = (
  destFn: (req: Express.Request) => string,
): MulterOptions['storage'] =>
  diskStorage({
    destination: (req, _file, callback) => {
      const dest = join(process.cwd(), 'public', destFn(req));
      // Tạo thư mục tự động nếu chưa tồn tại
      mkdirSync(dest, { recursive: true });
      callback(null, dest);
    },
    filename: (_req, file, callback) => {
      const ext = extname(file.originalname).toLowerCase() || '.jpg';
      callback(null, `${uuid()}${ext}`);
    },
  });

// ── Avatar người dùng ───────────────────────────────────────────────────────
export const multerAvatarConfig: MulterOptions = {
  storage: createStorage(() => 'avatars'),
  fileFilter: imageFileFilter,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5 MB
};

// ── Ảnh scan tủ lạnh (lưu theo userId để dễ quản lý) ───────────────────────
export const multerScanConfig: MulterOptions = {
  storage: createStorage((req) => {
    const userId = (req as any)?.user?.sub ?? 'unknown';
    return `scans/${userId}`;
  }),
  fileFilter: imageFileFilter,
  limits: { fileSize: 20 * 1024 * 1024 }, // 20 MB
};

// ── Ảnh thumbnail công thức ─────────────────────────────────────────────────
export const multerRecipeConfig: MulterOptions = {
  storage: createStorage(() => 'recipes'),
  fileFilter: imageFileFilter,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
};

// ── Logo / ảnh nhà tài trợ ──────────────────────────────────────────────────
export const multerSponsorConfig: MulterOptions = {
  storage: createStorage(() => 'sponsors'),
  fileFilter: imageFileFilter,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5 MB
};

// ── Ảnh nguyên liệu ─────────────────────────────────────────────────────────
export const multerIngredientConfig: MulterOptions = {
  storage: createStorage(() => 'ingredients'),
  fileFilter: imageFileFilter,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5 MB
};
