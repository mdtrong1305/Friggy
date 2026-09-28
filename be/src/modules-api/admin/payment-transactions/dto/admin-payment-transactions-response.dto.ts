import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class AdminPaymentTransactionDto {
  @ApiProperty({ example: 'uuid-xxx' }) id!: string;
  @ApiPropertyOptional({ example: 'FRIGGY-1727100000000' }) paymentRef!: string | null;
  @ApiProperty({ example: 'subscribe', description: 'subscribe | renew' }) type!: string;
  @ApiProperty({ example: 'usr_abc123' }) userId!: string;
  @ApiProperty({ example: 'Individual Pro', description: 'Tên gói dịch vụ' }) planName!: string;
  @ApiProperty({ example: 25000 }) amount!: number;
  @ApiProperty({ example: 'pending', description: 'pending | paid | expired | cancelled' }) status!: string;
  @ApiPropertyOptional({ example: 'https://pay.payos.vn/web/abc123' }) checkoutUrl!: string | null;
  @ApiPropertyOptional({ example: '2026-09-24T02:30:00.000Z' }) expiredAt!: string | null;
  @ApiPropertyOptional({ example: '2026-09-24T02:35:00.000Z' }) paidAt!: string | null;
  @ApiProperty({ example: '2026-09-24T02:28:00.000Z' }) createdAt!: string;
}

export class AdminPaymentTransactionListResponseDto {
  @ApiProperty({ type: [AdminPaymentTransactionDto] }) data!: AdminPaymentTransactionDto[];
  @ApiProperty({ example: 100 }) total!: number;
  @ApiProperty({ example: 1 }) page!: number;
  @ApiProperty({ example: 20 }) limit!: number;
}
