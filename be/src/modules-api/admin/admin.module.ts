import { Module } from '@nestjs/common';
import { PrismaModule } from 'src/modules-system/prisma/prisma.module';

// ── AI ────────────────────────────────────────────────────
import { AdminAiController } from './ai/admin-ai.controller';
import { AdminAiService } from './ai/admin-ai.service';

// ── Cron ─────────────────────────────────────────────────
import { AdminCronController } from './cron/admin-cron.controller';
import { AdminCronService } from './cron/admin-cron.service';
import { NotificationsModule } from 'src/modules-api/notifications/notifications.module';

// ── Users ─────────────────────────────────────────────────
import { AdminUsersController } from './users/admin-users.controller';
import { AdminUsersService } from './users/admin-users.service';

// ── Stats ─────────────────────────────────────────────────
import { AdminStatsController } from './stats/admin-stats.controller';
import { AdminStatsService } from './stats/admin-stats.service';

// ── Sponsors ──────────────────────────────────────────────
import { AdminSponsorsController } from './sponsors/admin-sponsors.controller';
import { AdminSponsorsService } from './sponsors/admin-sponsors.service';

// ── Plans ─────────────────────────────────────────────────
import { AdminPlansController } from './plans/admin-plans.controller';
import { AdminPlansService } from './plans/admin-plans.service';

// ── Payment Transactions ──────────────────────────────────
import { AdminPaymentTransactionsController } from './payment-transactions/admin-payment-transactions.controller';
import { AdminPaymentTransactionsService } from './payment-transactions/admin-payment-transactions.service';

// ── Ingredients ───────────────────────────────────────────
import { AdminIngredientsController } from './ingredients/admin-ingredients.controller';
import { AdminIngredientsService } from './ingredients/admin-ingredients.service';

// ── Recipes ───────────────────────────────────────────────
import { AdminRecipesController } from './recipes/admin-recipes.controller';
import { AdminRecipesService } from './recipes/admin-recipes.service';

@Module({
  imports: [
    PrismaModule,
    NotificationsModule,
  ],
  controllers: [
    AdminAiController,
    AdminCronController,
    AdminUsersController,
    AdminStatsController,
    AdminSponsorsController,
    AdminPlansController,
    AdminPaymentTransactionsController,
    AdminIngredientsController,
    AdminRecipesController,
  ],
  providers: [
    AdminAiService,
    AdminCronService,
    AdminUsersService,
    AdminStatsService,
    AdminSponsorsService,
    AdminPlansService,
    AdminPaymentTransactionsService,
    AdminIngredientsService,
    AdminRecipesService,
  ],
})
export class AdminModule {}
