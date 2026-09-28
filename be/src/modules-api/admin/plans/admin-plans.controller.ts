import { Controller, Get, Post, Patch, Delete, Param, Body, ParseIntPipe, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiParam } from '@nestjs/swagger';
import { AdminPlansService } from './admin-plans.service';
import { CreatePlanDto, UpdatePlanDto } from './dto/admin-plan.dto';
import { SubscriptionPlanDto } from './dto/admin-plan-response.dto';
import { Roles } from 'src/common/decorators/roles.decorator';

@ApiTags('Admin / Plans')
@ApiBearerAuth('access-token')
@Roles('admin')
@Controller('admin/plans')
export class AdminPlansController {
  constructor(private readonly adminPlansService: AdminPlansService) {}

  @Get()
  @ApiOperation({ summary: '[Admin] Danh sách tất cả gói dịch vụ' })
  @ApiResponse({ status: 200, type: [SubscriptionPlanDto] })
  getPlans() {
    return this.adminPlansService.getPlans();
  }

  @Post()
  @ApiOperation({ summary: '[Admin] Tạo gói dịch vụ mới' })
  @ApiResponse({ status: 201, type: SubscriptionPlanDto })
  @ApiResponse({ status: 400, description: 'Tên gói đã tồn tại' })
  createPlan(@Body() dto: CreatePlanDto) {
    return this.adminPlansService.createPlan(dto);
  }

  @Patch(':id')
  @ApiOperation({ summary: '[Admin] Cập nhật giá, rate limit, tên, tính năng gói' })
  @ApiParam({ name: 'id', description: 'Plan ID' })
  @ApiResponse({ status: 200, type: SubscriptionPlanDto })
  @ApiResponse({ status: 404, description: 'Gói không tồn tại' })
  updatePlan(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdatePlanDto,
  ) {
    return this.adminPlansService.updatePlan(id, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: '[Admin] Xóa gói dịch vụ (soft delete)' })
  @ApiParam({ name: 'id', description: 'Plan ID' })
  @ApiResponse({ status: 200, description: 'Đã xóa gói' })
  @ApiResponse({ status: 404, description: 'Gói không tồn tại' })
  deletePlan(@Param('id', ParseIntPipe) id: number) {
    return this.adminPlansService.deletePlan(id);
  }
}
