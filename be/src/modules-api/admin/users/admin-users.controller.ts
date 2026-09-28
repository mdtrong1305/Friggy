import { Controller, Get, Patch, Param, Query } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiParam, ApiResponse } from '@nestjs/swagger';
import { Roles } from 'src/common/decorators/roles.decorator';
import { AdminUsersService } from './admin-users.service';
import { ListUsersQueryDto } from './dto/admin-users.dto';
import { PaginatedUsersDto, UserDetailDto, UserActionResponseDto } from './dto/admin-users-response.dto';

@ApiTags('Admin / Users')
@ApiBearerAuth('access-token')
@Roles('admin')
@Controller('admin/users')
export class AdminUsersController {
  constructor(private readonly service: AdminUsersService) {}

  @Get()
  @ApiOperation({ summary: '[Admin] Danh sách users (filter, phân trang)' })
  @ApiResponse({ status: 200, type: PaginatedUsersDto })
  getUsers(@Query() query: ListUsersQueryDto) {
    return this.service.getUsers(query);
  }

  @Get(':id')
  @ApiOperation({ summary: '[Admin] Chi tiết user kèm profile, subscription, AI usage' })
  @ApiParam({ name: 'id', description: 'User ID' })
  @ApiResponse({ status: 200, type: UserDetailDto })
  @ApiResponse({ status: 404, description: 'Không tìm thấy user' })
  getUserDetail(@Param('id') id: string) {
    return this.service.getUserDetail(id);
  }

  @Patch(':id/suspend')
  @ApiOperation({ summary: '[Admin] Khóa tài khoản user' })
  @ApiParam({ name: 'id', description: 'User ID' })
  @ApiResponse({ status: 200, type: UserActionResponseDto })
  suspendUser(@Param('id') id: string) {
    return this.service.suspendUser(id);
  }

  @Patch(':id/activate')
  @ApiOperation({ summary: '[Admin] Mở khóa tài khoản user' })
  @ApiParam({ name: 'id', description: 'User ID' })
  @ApiResponse({ status: 200, type: UserActionResponseDto })
  activateUser(@Param('id') id: string) {
    return this.service.activateUser(id);
  }
}
