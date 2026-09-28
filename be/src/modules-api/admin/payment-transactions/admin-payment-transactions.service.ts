/**
 * AdminPaymentTransactionsService
 *
 * Xử lý business logic admin: lấy toàn bộ giao dịch với filter userId, status, phân trang.
 */
import { Injectable } from '@nestjs/common';
import { PrismaService } from 'src/modules-system/prisma/prisma.service';
import type { ListTransactionsQueryDto } from './dto/admin-payment-transactions-query.dto';
import type { AdminPaymentTransactionListResponseDto } from './dto/admin-payment-transactions-response.dto';

@Injectable()
export class AdminPaymentTransactionsService {
  constructor(private readonly prisma: PrismaService) {}

  // ─────────────────────────────────────────────────────────
  // GET /admin/payment-transactions — Tất cả giao dịch (admin view)
  // ─────────────────────────────────────────────────────────

  async getAllTransactions(
    query: ListTransactionsQueryDto,
  ): Promise<AdminPaymentTransactionListResponseDto> {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;

    const where: Record<string, unknown> = {};
    if (query.userId) where.userId = query.userId;
    if (query.status) where.status = query.status;

    const [data, total] = await Promise.all([
      this.prisma.paymentTransaction.findMany({
        where,
        include: { plan: true },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.paymentTransaction.count({ where }),
    ]);

    return {
      data: data.map((tx) => ({
        id: tx.id,
        paymentRef: tx.paymentRef,
        type: tx.type,
        userId: tx.userId,
        planName: tx.plan.displayName,
        amount: tx.amount,
        status: tx.status,
        checkoutUrl: tx.checkoutUrl,
        expiredAt: tx.expiredAt?.toISOString() ?? null,
        paidAt: tx.paidAt?.toISOString() ?? null,
        createdAt: tx.createdAt.toISOString(),
      })),
      total,
      page,
      limit,
    };
  }
}
