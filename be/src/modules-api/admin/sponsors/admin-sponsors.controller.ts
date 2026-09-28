import {
  Controller, Get, Post, Patch, Param, Body, ParseIntPipe,
} from '@nestjs/common';
import {
  ApiTags, ApiBearerAuth, ApiOperation, ApiParam, ApiResponse,
} from '@nestjs/swagger';
import { Roles } from 'src/common/decorators/roles.decorator';
import { AdminSponsorsService } from './admin-sponsors.service';
import {
  CreateSponsorDto, UpdateSponsorDto,
  CreateCampaignDto, UpdateCampaignDto,
} from './dto/admin-sponsors.dto';
import { SponsorDto, CampaignDto } from './dto/admin-sponsors-response.dto';

@ApiTags('Admin / Sponsors')
@ApiBearerAuth('access-token')
@Roles('admin')
@Controller('admin/sponsors')
export class AdminSponsorsController {
  constructor(private readonly service: AdminSponsorsService) {}

  // ── Sponsors ──────────────────────────────────────────────

  @Get()
  @ApiOperation({ summary: '[Admin] Danh sách sponsors' })
  @ApiResponse({ status: 200, type: [SponsorDto] })
  getSponsors() {
    return this.service.getSponsors();
  }

  @Post()
  @ApiOperation({ summary: '[Admin] Tạo sponsor mới' })
  @ApiResponse({ status: 201, type: SponsorDto })
  createSponsor(@Body() dto: CreateSponsorDto) {
    return this.service.createSponsor(dto);
  }

  @Patch(':id')
  @ApiOperation({ summary: '[Admin] Cập nhật thông tin sponsor' })
  @ApiParam({ name: 'id', description: 'Sponsor ID' })
  @ApiResponse({ status: 200, type: SponsorDto })
  @ApiResponse({ status: 404, description: 'Sponsor không tồn tại' })
  updateSponsor(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateSponsorDto,
  ) {
    return this.service.updateSponsor(id, dto);
  }

  // ── Campaigns ─────────────────────────────────────────────

  @Get(':id/campaigns')
  @ApiOperation({ summary: '[Admin] Campaigns của 1 sponsor' })
  @ApiParam({ name: 'id', description: 'Sponsor ID' })
  @ApiResponse({ status: 200, type: [CampaignDto] })
  getCampaigns(@Param('id', ParseIntPipe) id: number) {
    return this.service.getCampaigns(id);
  }

  @Post(':id/campaigns')
  @ApiOperation({ summary: '[Admin] Tạo campaign cho sponsor' })
  @ApiParam({ name: 'id', description: 'Sponsor ID' })
  @ApiResponse({ status: 201, type: CampaignDto })
  createCampaign(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: CreateCampaignDto,
  ) {
    return this.service.createCampaign(id, dto);
  }

  @Patch('campaigns/:campaignId')
  @ApiOperation({ summary: '[Admin] Cập nhật campaign (status, endDate)' })
  @ApiParam({ name: 'campaignId', description: 'Campaign ID (UUID)' })
  @ApiResponse({ status: 200, type: CampaignDto })
  @ApiResponse({ status: 404, description: 'Campaign không tồn tại' })
  updateCampaign(
    @Param('campaignId') campaignId: string,
    @Body() dto: UpdateCampaignDto,
  ) {
    return this.service.updateCampaign(campaignId, dto);
  }
}
