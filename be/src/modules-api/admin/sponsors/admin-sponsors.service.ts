/**
 * AdminSponsorsService — Sponsor & Campaign Management
 */
import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from 'src/modules-system/prisma/prisma.service';
import type {
  CreateSponsorDto,
  UpdateSponsorDto,
  CreateCampaignDto,
  UpdateCampaignDto,
} from './dto/admin-sponsors.dto';

@Injectable()
export class AdminSponsorsService {
  constructor(private readonly prisma: PrismaService) {}

  // ── Sponsors ──────────────────────────────────────────────

  async getSponsors() {
    return this.prisma.sponsor.findMany({
      where: { deletedAt: null },
      orderBy: { createdAt: 'desc' },
      include: { _count: { select: { campaigns: true } } },
    });
  }

  async createSponsor(dto: CreateSponsorDto) {
    return this.prisma.sponsor.create({
      data: {
        name: dto.name,
        websiteUrl: dto.websiteUrl,
        contactEmail: dto.contactEmail,
        status: (dto.status ?? 'active') as any,
      },
    });
  }

  async updateSponsor(id: number, dto: UpdateSponsorDto) {
    const sponsor = await this.prisma.sponsor.findFirst({ where: { id, deletedAt: null } });
    if (!sponsor) throw new NotFoundException('Không tìm thấy sponsor');

    return this.prisma.sponsor.update({
      where: { id },
      data: {
        ...(dto.name && { name: dto.name }),
        ...(dto.websiteUrl !== undefined && { websiteUrl: dto.websiteUrl }),
        ...(dto.contactEmail !== undefined && { contactEmail: dto.contactEmail }),
        ...(dto.status && { status: dto.status as any }),
      },
    });
  }

  // ── Campaigns ─────────────────────────────────────────────

  async getCampaigns(sponsorId: number) {
    const sponsor = await this.prisma.sponsor.findFirst({ where: { id: sponsorId, deletedAt: null } });
    if (!sponsor) throw new NotFoundException('Không tìm thấy sponsor');

    return this.prisma.sponsorCampaign.findMany({
      where: { sponsorId, deletedAt: null },
      orderBy: { createdAt: 'desc' },
      include: { _count: { select: { recipes: true } } },
    });
  }

  async createCampaign(sponsorId: number, dto: CreateCampaignDto) {
    const sponsor = await this.prisma.sponsor.findFirst({ where: { id: sponsorId, deletedAt: null } });
    if (!sponsor) throw new NotFoundException('Không tìm thấy sponsor');

    return this.prisma.sponsorCampaign.create({
      data: {
        sponsorId,
        title: dto.title,
        description: dto.description,
        campaignType: dto.campaignType as any,
        startDate: new Date(dto.startDate),
        endDate: dto.endDate ? new Date(dto.endDate) : null,
        status: (dto.status ?? 'scheduled') as any,
      },
    });
  }

  async updateCampaign(campaignId: string, dto: UpdateCampaignDto) {
    const campaign = await this.prisma.sponsorCampaign.findFirst({
      where: { id: campaignId, deletedAt: null },
    });
    if (!campaign) throw new NotFoundException('Không tìm thấy campaign');

    return this.prisma.sponsorCampaign.update({
      where: { id: campaignId },
      data: {
        ...(dto.title && { title: dto.title }),
        ...(dto.status && { status: dto.status as any }),
        ...(dto.endDate !== undefined && { endDate: dto.endDate ? new Date(dto.endDate) : null }),
      },
    });
  }
}
