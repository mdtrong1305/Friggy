/**
 * AdminUsersService — User Management
 */
import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from 'src/modules-system/prisma/prisma.service';
import type { ListUsersQueryDto } from './dto/admin-users.dto';

@Injectable()
export class AdminUsersService {
  constructor(private readonly prisma: PrismaService) {}

  // ─────────────────────────────────────────────────────────
  // GET /admin/users — Danh sách users
  // ─────────────────────────────────────────────────────────
  async getUsers(query: ListUsersQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;

    const where: any = { deletedAt: null };
    if (query.status) where.status = query.status;
    if (query.q) {
      where.OR = [
        { name: { contains: query.q } },
        { email: { contains: query.q } },
        { googleEmail: { contains: query.q } },
      ];
    }

    const [users, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          name: true,
          email: true,
          googleEmail: true,
          authProvider: true,
          status: true,
          createdAt: true,
          lastLoginAt: true,
          subscription: {
            select: {
              status: true,
              plan: { select: { name: true, displayName: true } },
              endDate: true,
            },
          },
        },
      }),
      this.prisma.user.count({ where }),
    ]);

    return {
      data: users,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  // ─────────────────────────────────────────────────────────
  // GET /admin/users/:id — Chi tiết user
  // ─────────────────────────────────────────────────────────
  async getUserDetail(id: string) {
    const user = await this.prisma.user.findFirst({
      where: { id, deletedAt: null },
      select: {
        id: true,
        name: true,
        email: true,
        googleEmail: true,
        authProvider: true,
        status: true,
        createdAt: true,
        lastLoginAt: true,
        isOnboardingCompleted: true,
        profile: true,
        preferences: {
          select: {
            dietaryStyle: true,
            skillLevel: true,
            householdSize: true,
            weeklyBudget: true,
          },
        },
        subscription: {
          select: {
            status: true,
            startDate: true,
            endDate: true,
            plan: { select: { name: true, displayName: true, priceVnd: true, aiUsagePerWeek: true } },
          },
        },
      },
    });

    if (!user) throw new NotFoundException('Không tìm thấy user');

    // Lấy AI usage 7 ngày
    const weekAgo = new Date();
    weekAgo.setDate(weekAgo.getDate() - 7);
    const aiUsageCount = await this.prisma.aiUsageLog.count({
      where: { userId: id, usedAt: { gte: weekAgo } },
    });

    return { ...user, aiUsageThisWeek: aiUsageCount };
  }

  // ─────────────────────────────────────────────────────────
  // PATCH /admin/users/:id/suspend
  // ─────────────────────────────────────────────────────────
  async suspendUser(id: string) {
    const user = await this.prisma.user.findFirst({ where: { id, deletedAt: null } });
    if (!user) throw new NotFoundException('Không tìm thấy user');

    await this.prisma.user.update({
      where: { id },
      data: { status: 'suspended' },
    });

    return { message: `Đã khóa tài khoản user ${id}` };
  }

  // ─────────────────────────────────────────────────────────
  // PATCH /admin/users/:id/activate
  // ─────────────────────────────────────────────────────────
  async activateUser(id: string) {
    const user = await this.prisma.user.findFirst({ where: { id, deletedAt: null } });
    if (!user) throw new NotFoundException('Không tìm thấy user');

    await this.prisma.user.update({
      where: { id },
      data: { status: 'active' },
    });

    return { message: `Đã mở khóa tài khoản user ${id}` };
  }
}
