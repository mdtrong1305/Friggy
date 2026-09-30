import 'dotenv/config';

export const PORT = process.env.PORT;
export const NODE_ENV = process.env.NODE_ENV ?? 'development';
export const DATABASE_URL = process.env.DATABASE_URL;
export const SWAGGER_PATH = process.env.SWAGGER_PATH ?? 'api/docs';
export const APP_URL =
  process.env.APP_URL ?? `http://localhost:${PORT ?? 6969}`;

// Google OAuth
export const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID ?? '';

// JWT
export const JWT_ACCESS_SECRET =
  process.env.JWT_ACCESS_SECRET ?? 'fallback_access_secret';
export const JWT_REFRESH_SECRET =
  process.env.JWT_REFRESH_SECRET ?? 'fallback_refresh_secret';
export const JWT_ACCESS_EXPIRES_IN = process.env.JWT_ACCESS_EXPIRES_IN ?? '15m';
export const JWT_REFRESH_EXPIRES_IN =
  process.env.JWT_REFRESH_EXPIRES_IN ?? '7d';

// AES-256 Encryption
export const ENCRYPTION_SECRET = process.env.ENCRYPTION_SECRET ?? '';

// Redis — Cache + BullMQ Queue
export const REDIS_URL = process.env.DATABASE_REDIS ?? 'redis://localhost:6380';

// RabbitMQ — Message broker cho giao tiếp với AI Service
export const RABBIT_MQ_URL =
  process.env.RABBIT_MQ_URL ?? 'amqp://user:12345@localhost:5673';

// RabbitMQ Exchange & Routing Keys (phải khớp với ai-service/src/common/constants/app.constant.ts)
export const FRIGGY_AI_EXCHANGE = 'friggy.ai';
export const MEAL_PLAN_ROUTING_KEY = 'meal.plan.generate';
export const AI_CHAT_ROUTING_KEY = 'ai.chat.message';
export const FRIDGE_SCAN_ROUTING_KEY = 'fridge.scan';
export const AI_SLOT_REGENERATE_ROUTING_KEY = 'ai.slot.regenerate';
export const AI_EXPIRING_MEAL_ROUTING_KEY = 'ai.expiring.meal.plan';
export const PUBLIC_CHAT_ROUTING_KEY = 'public.chat.message'; // Phải khớp ai-service

// Gemini — Public SEO Chatbot (gọi trực tiếp, không qua ai-service)
export const GEMINI_API_KEY = process.env.GEMINI_API_KEY ?? '';

// Firebase — FCM Push Notifications
export const FIREBASE_SERVICE_ACCOUNT_JSON =
  process.env.FIREBASE_SERVICE_ACCOUNT_JSON ?? '';

console.log(
  '\n',
  { PORT, NODE_ENV, DATABASE_URL, REDIS_URL, RABBIT_MQ_URL },
  '\n',
);
