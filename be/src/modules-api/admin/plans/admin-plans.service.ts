import { Injectable, NotFoundException, Logger } from '@nestjs/common';
import { PrismaService } from 'src/modules-system/prisma/prisma.service';
import type { CreatePlanDto, UpdatePlanDto } from './dto/admin-plan.dto';

@Injectable()
export class AdminPlansService {
  private readonly logger = new Logger(AdminPlansService.name);

  constructor(private readonly prisma: PrismaService) {}

  // ─── GET /admin/plans ────────────────────────────────────

  async getPlans() {
    return this.prisma.subscriptionPlan.findMany({
      where: { deletedAt: null },
      orderBy: { priceVnd: 'asc' },
    });
  }

  // ─── PATCH /admin/plans/:id ──────────────────────────────

  async updatePlan(id: number, dto: UpdatePlanDto) {
    const plan = await this.prisma.subscriptionPlan.findFirst({
      where: { id, deletedAt: null },
    });
    if (!plan) throw new NotFoundException(`Gói #${id} không tồn tại`);

    const updated = await this.prisma.subscriptionPlan.update({
      where: { id },
      data: {
        ...(dto.priceVnd !== undefined && { priceVnd: dto.priceVnd }),
        ...(dto.aiUsagePerWeek !== undefined && { aiUsagePerWeek: dto.aiUsagePerWeek }),
        ...(dto.displayName !== undefined && { displayName: dto.displayName }),
        ...(dto.features !== undefined && { features: dto.features }),
        ...(dto.isActive !== undefined && { isActive: dto.isActive }),
      },
    });

    this.logger.log(`[AdminPlans] Cập nhật gói #${id} (${plan.name}): ${JSON.stringify(dto)}`);
    return updated;
  }
  // ─── POST /admin/plans ────────────────────────────────────

  async createPlan(dto: CreatePlanDto) {
    const created = await this.prisma.subscriptionPlan.create({
      data: {
        name: dto.name,
        displayName: dto.displayName ?? dto.name,
        priceVnd: dto.priceVnd,
        billingCycle: dto.billingCycle,
        aiUsagePerWeek: dto.aiUsagePerWeek,
        features: dto.features ?? [],
        isActive: dto.isActive ?? true,
      },
    });

    this.logger.log(`[AdminPlans] Tạo gói mới: ${created.name} (#${created.id})`);
    return created;
  }

  // ─── DELETE /admin/plans/:id ───────────────────────────────

  async deletePlan(id: number) {
    const plan = await this.prisma.subscriptionPlan.findFirst({
      where: { id, deletedAt: null },
    });
    if (!plan) throw new NotFoundException(`Gói #${id} không tồn tại`);

    await this.prisma.subscriptionPlan.update({
      where: { id },
      data: { deletedAt: new Date(), isActive: false },
    });

    this.logger.log(`[AdminPlans] Xóa gói #${id} (${plan.name})`);
    return { message: `Đã xóa gói "${plan.displayName ?? plan.name}" (#${id})` };
  }
}
