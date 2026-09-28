/**
 * AdminStatsService — Dashboard Stats
 */
import { Injectable } from '@nestjs/common';
import { PrismaService } from 'src/modules-system/prisma/prisma.service';

@Injectable()
export class AdminStatsService {
  constructor(private readonly prisma: PrismaService) {}

  // ─────────────────────────────────────────────────────────
  // GET /admin/stats/overview
  // ─────────────────────────────────────────────────────────
  async getOverview() {
    const now = new Date();
    const thirtyDaysAgo = new Date(now);
    thirtyDaysAgo.setDate(now.getDate() - 30);
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

    const [
      totalUsers,
      activeUsers,
      suspendedUsers,
      newUsersThisMonth,
      activeSubscriptions,
      revenueThisMonth,
      totalRevenue,
    ] = await Promise.all([
      this.prisma.user.count({ where: { deletedAt: null } }),
      this.prisma.user.count({ where: { deletedAt: null, status: 'active' } }),
      this.prisma.user.count({ where: { deletedAt: null, status: 'suspended' } }),
      this.prisma.user.count({ where: { deletedAt: null, createdAt: { gte: monthStart } } }),
      this.prisma.userSubscription.count({
        where: {
          status: 'active',
          OR: [{ endDate: null }, { endDate: { gte: now } }],
        },
      }),
      // Doanh thu tháng này = tổng tiền giao dịch paid trong tháng
      this.prisma.paymentTransaction.aggregate({
        where: { status: 'paid', createdAt: { gte: monthStart } },
        _sum: { amount: true },
      }),
      // Tổng doanh thu toàn thời gian
      this.prisma.paymentTransaction.aggregate({
        where: { status: 'paid' },
        _sum: { amount: true },
      }),
    ]);

    const revenueVnd = revenueThisMonth._sum.amount ?? 0;
    const totalRevenueVnd = totalRevenue._sum.amount ?? 0;

    return {
      totalUsers,
      activeUsers,
      suspendedUsers,
      newUsersThisMonth,
      activeSubscriptions,
      revenueThisMonthVnd: revenueVnd,
      totalRevenueVnd,
    };
  }

  // ─────────────────────────────────────────────────────────
  // GET /admin/stats/ai-usage?days=7
  // ─────────────────────────────────────────────────────────
  async getAiUsage(days: number = 7) {
    const since = new Date();
    since.setDate(since.getDate() - days);

    const logs = await this.prisma.aiUsageLog.groupBy({
      by: ['featureType'],
      where: { usedAt: { gte: since } },
      _count: { id: true },
      orderBy: { _count: { id: 'desc' } },
    });

    const totalCalls = logs.reduce((sum, l) => sum + l._count.id, 0);

    return {
      period: `${days} ngày gần nhất`,
      totalCalls,
      breakdown: logs.map((l) => ({
        featureType: l.featureType,
        count: l._count.id,
      })),
    };
  }

  // ─────────────────────────────────────────────────────────
  // GET /admin/stats/subscriptions
  // ─────────────────────────────────────────────────────────
  async getSubscriptionBreakdown() {
    const breakdown = await this.prisma.userSubscription.groupBy({
      by: ['planId'],
      where: { status: 'active' },
      _count: { id: true },
    });

    const plans = await this.prisma.subscriptionPlan.findMany({
      select: { id: true, name: true, displayName: true },
    });

    const planMap = new Map(plans.map((p) => [p.id, p]));

    return breakdown.map((b) => ({
      plan: planMap.get(b.planId) ?? { id: b.planId, name: 'Unknown' },
      activeSubscribers: b._count.id,
    }));
  }
}
