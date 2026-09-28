import { Controller, Get, Query } from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { Roles } from 'src/common/decorators/roles.decorator';
import { AdminPaymentTransactionsService } from './admin-payment-transactions.service';
import { ListTransactionsQueryDto } from './dto/admin-payment-transactions-query.dto';
import { AdminPaymentTransactionListResponseDto } from './dto/admin-payment-transactions-response.dto';

@ApiTags('Admin / Payment Transactions')
@ApiBearerAuth('access-token')
@Roles('admin')
@Controller('admin/payment-transactions')
export class AdminPaymentTransactionsController {
  constructor(private readonly service: AdminPaymentTransactionsService) {}

  // ─────────────────────────────────────────────────────────
  // GET /admin/payment-transactions — Tất cả giao dịch
  // ─────────────────────────────────────────────────────────

  @Get()
  @ApiOperation({
    summary: '[Admin] Toàn bộ lịch sử giao dịch thanh toán',
    description:
      'Lấy tất cả giao dịch với hỗ trợ filter theo `userId` và `status`.\n\n' +
      '**Filter status:** `pending` | `paid` | `expired` | `cancelled`',
  })
  @ApiResponse({ status: 200, type: AdminPaymentTransactionListResponseDto })
  getAllTransactions(
    @Query() query: ListTransactionsQueryDto,
  ) {
    return this.service.getAllTransactions(query);
  }
}
