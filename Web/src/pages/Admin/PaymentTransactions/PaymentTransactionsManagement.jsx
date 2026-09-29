import React, { useState, useEffect } from 'react';
import {
  CreditCard,
  Search,
  Filter,
  CheckCircle2,
  Clock,
  XCircle,
  AlertCircle,
  Eye,
  ChevronLeft,
  ChevronRight,
  Loader2,
  RefreshCw,
  TrendingUp,
  DollarSign,
  User,
  Calendar,
} from 'lucide-react';
import { getAdminPaymentTransactionsApi, getAdminUserDetailApi } from '../../../services/adminService';
import { showToast } from '../../../components/common/Toast';

export const PaymentTransactionsManagement = () => {
  const [transactions, setTransactions] = useState([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [limit, setLimit] = useState(10);
  const [totalPages, setTotalPages] = useState(1);
  const [loading, setLoading] = useState(true);

  // Filters
  const [statusFilter, setStatusFilter] = useState('');
  const [userIdSearch, setUserIdSearch] = useState('');

  // Selected Transaction for Detail Modal
  const [selectedTx, setSelectedTx] = useState(null);
  const [openDetailModal, setOpenDetailModal] = useState(false);

  const fetchTransactions = async () => {
    setLoading(true);
    try {
      const params = {
        page,
        limit,
        status: statusFilter || undefined,
        userId: userIdSearch.trim() || undefined,
      };

      const res = await getAdminPaymentTransactionsApi(params);
      const resData = res?.data || res;

      if (resData) {
        const txList = resData.data || [];
        setTotal(resData.total || 0);
        setTotalPages(resData.totalPages || 1);

        // Fetch user info for each transaction's userId in parallel
        const uniqueUserIds = [...new Set(txList.map((t) => t.userId).filter(Boolean))];
        const userMap = {};

        await Promise.all(
          uniqueUserIds.map(async (uid) => {
            try {
              const uRes = await getAdminUserDetailApi(uid);
              const uData = uRes?.data || uRes;
              if (uData) {
                const name =
                  uData.name ||
                  uData.profile?.displayName ||
                  uData.profile?.name ||
                  (uData.googleEmail ? uData.googleEmail.split('@')[0] : null) ||
                  (uData.email ? uData.email.split('@')[0] : null) ||
                  'N/A';
                const email = uData.email || uData.googleEmail || 'N/A';
                userMap[uid] = { name, email };
              }
            } catch (e) {
              console.log(`Could not fetch detail for user ${uid}`, e);
            }
          })
        );

        const enrichedList = txList.map((tx) => ({
          ...tx,
          user: tx.user || userMap[tx.userId] || null,
        }));

        setTransactions(enrichedList);
      }
    } catch (err) {
      console.error('Lỗi khi tải lịch sử giao dịch:', err);
      showToast.error('Không thể tải lịch sử giao dịch thanh toán');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchTransactions();
  }, [page, limit, statusFilter]);

  const handleSearchSubmit = (e) => {
    e.preventDefault();
    setPage(1);
    fetchTransactions();
  };

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(amount || 0);
  };

  const formatDate = (dateStr) => {
    if (!dateStr) return '--';
    try {
      return new Date(dateStr).toLocaleString('vi-VN', {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
      });
    } catch {
      return dateStr;
    }
  };

  const renderStatusBadge = (status) => {
    switch (status) {
      case 'paid':
        return (
          <span className="px-3 py-1 rounded-full bg-emerald-50 text-emerald-700 text-xs font-bold border border-emerald-200 inline-flex items-center gap-1.5 shadow-2xs">
            <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" />
            Đã thanh toán
          </span>
        );
      case 'pending':
        return (
          <span className="px-3 py-1 rounded-full bg-amber-50 text-amber-700 text-xs font-bold border border-amber-200 inline-flex items-center gap-1.5 shadow-2xs">
            <Clock className="w-3.5 h-3.5 text-amber-600 animate-pulse" />
            Chờ thanh toán
          </span>
        );
      case 'expired':
        return (
          <span className="px-3 py-1 rounded-full bg-slate-100 text-slate-600 text-xs font-bold border border-slate-200 inline-flex items-center gap-1.5">
            <AlertCircle className="w-3.5 h-3.5 text-slate-500" />
            Hết hạn
          </span>
        );
      case 'cancelled':
        return (
          <span className="px-3 py-1 rounded-full bg-rose-50 text-rose-700 text-xs font-bold border border-rose-200 inline-flex items-center gap-1.5 shadow-2xs">
            <XCircle className="w-3.5 h-3.5 text-rose-600" />
            Đã hủy
          </span>
        );
      default:
        return (
          <span className="px-3 py-1 rounded-full bg-slate-100 text-slate-600 text-xs font-semibold">
            {status || 'Không rõ'}
          </span>
        );
    }
  };

  return (
    <div className="space-y-8 pb-12 animate__animated animate__fadeIn animate__faster">
      {/* Top Banner Header */}
      <div className="p-6 sm:p-8 rounded-[32px] bg-white border border-emerald-100 shadow-xs flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h3 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight flex items-center gap-2">
            <span>Quản Lý Lịch Sử Giao Dịch Thanh Toán</span>
            <CreditCard className="w-6 h-6 text-emerald-600" />
          </h3>
          <p className="text-xs sm:text-sm text-slate-500 font-medium mt-1">
            Theo dõi toàn bộ lịch sử thanh toán gói dịch vụ Premium từ cổng PayOS.
          </p>
        </div>

        <button
          onClick={fetchTransactions}
          className="px-5 py-2.5 rounded-2xl bg-emerald-50 hover:bg-emerald-100 text-emerald-700 font-extrabold text-xs sm:text-sm border border-emerald-200 transition-all cursor-pointer flex items-center gap-2 self-start md:self-auto"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          <span>Làm Mới</span>
        </button>
      </div>

      {/* Control & Search Bar */}
      <div className="p-6 rounded-[32px] bg-white border border-slate-100 shadow-md space-y-4">
        <form onSubmit={handleSearchSubmit} className="grid grid-cols-1 sm:grid-cols-12 gap-3">
          {/* User ID Search */}
          <div className="sm:col-span-8 relative">
            <Search className="w-4 h-4 text-slate-400 absolute left-4 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={userIdSearch}
              onChange={(e) => setUserIdSearch(e.target.value)}
              placeholder="Tìm theo Mã Người Dùng (User ID)..."
              className="w-full pl-10 pr-4 py-2.5 rounded-2xl bg-slate-50 border border-slate-200 text-xs sm:text-sm font-semibold outline-hidden focus:border-emerald-500 focus:bg-white transition-all"
            />
          </div>

          {/* Status Filter */}
          <div className="sm:col-span-4 relative">
            <select
              value={statusFilter}
              onChange={(e) => {
                setStatusFilter(e.target.value);
                setPage(1);
              }}
              className="w-full px-4 py-2.5 rounded-2xl bg-slate-50 border border-slate-200 text-xs sm:text-sm font-semibold text-slate-700 outline-hidden focus:border-emerald-500 transition-all cursor-pointer"
            >
              <option value="">Tất cả trạng thái</option>
              <option value="paid">Đã thanh toán (paid)</option>
              <option value="pending">Đang chờ (pending)</option>
              <option value="expired">Đã hết hạn (expired)</option>
              <option value="cancelled">Đã hủy (cancelled)</option>
            </select>
          </div>
        </form>

        <div className="flex items-center justify-between text-xs font-semibold text-slate-500 pt-2 border-t border-slate-100">
          <span>Tổng số giao dịch: <strong className="text-emerald-700 font-extrabold">{total}</strong></span>
          <span>Trang {page} / {totalPages}</span>
        </div>
      </div>

      {/* Main Transactions Table */}
      <div className="animate__animated animate__fadeInUp p-6 rounded-[32px] bg-white border border-slate-100 shadow-md space-y-4">
        {loading ? (
          <div className="py-20 text-center space-y-3">
            <Loader2 className="w-8 h-8 text-emerald-600 animate-spin mx-auto" />
            <p className="text-xs font-bold text-slate-500">Đang tải lịch sử giao dịch...</p>
          </div>
        ) : transactions.length === 0 ? (
          <div className="py-16 text-center text-slate-400 font-medium text-sm space-y-2">
            <CreditCard className="w-10 h-10 text-slate-300 mx-auto" />
            <p>Không có lịch sử giao dịch nào phù hợp với điều kiện tìm kiếm.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse min-w-[950px]">
              <thead>
                <tr className="border-b border-emerald-100 bg-emerald-50/60 text-[11px] font-black text-emerald-950 uppercase tracking-wider">
                  <th className="py-3.5 px-4 rounded-l-2xl">Mã Đơn (Order Code)</th>
                  <th className="py-3.5 px-4">Người Dùng</th>
                  <th className="py-3.5 px-4">Số Tiền</th>
                  <th className="py-3.5 px-4">Kênh Thanh Toán</th>
                  <th className="py-3.5 px-4">Trạng Thái</th>
                  <th className="py-3.5 px-4">Thời Gian Tạo</th>
                  <th className="py-3.5 px-4 rounded-r-2xl text-right">Chi Tiết</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 text-xs">
                {transactions.map((tx) => (
                  <tr key={tx.id || tx.orderCode} className="hover:bg-slate-50/80 transition-colors font-semibold text-slate-800">
                    <td className="py-4 px-4 font-mono font-black text-emerald-700">
                      #{tx.orderCode || tx.id?.substring(0, 8)}
                    </td>
                    <td className="py-4 px-4 font-bold text-slate-800">
                      <div className="flex flex-col">
                        <span className="font-extrabold text-slate-900">{tx.user?.name || tx.user?.displayName || 'N/A'}</span>
                        <span className="text-[11px] text-slate-400 font-normal">{tx.user?.email || tx.userId}</span>
                      </div>
                    </td>
                    <td className="py-4 px-4 font-black text-emerald-700 text-sm">
                      {formatCurrency(tx.amount)}
                    </td>
                    <td className="py-4 px-4 font-bold text-slate-600">
                      <span className="px-2.5 py-1 rounded-xl bg-slate-100 text-slate-700 border border-slate-200">
                        {tx.paymentChannel || 'PayOS'}
                      </span>
                    </td>
                    <td className="py-4 px-4">
                      {renderStatusBadge(tx.status)}
                    </td>
                    <td className="py-4 px-4 font-medium text-slate-500">
                      {formatDate(tx.createdAt)}
                    </td>
                    <td className="py-4 px-4 text-right">
                      <button
                        onClick={() => {
                          setSelectedTx(tx);
                          setOpenDetailModal(true);
                        }}
                        className="p-2 rounded-xl bg-emerald-50 hover:bg-emerald-100 text-emerald-700 transition-colors cursor-pointer"
                        title="Xem chi tiết giao dịch"
                      >
                        <Eye className="w-4 h-4" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Pagination Bar */}
        {totalPages > 1 && (
          <div className="flex flex-col sm:flex-row items-center justify-between gap-4 pt-4 border-t border-slate-100">
            <span className="text-xs font-semibold text-slate-500">
              Hiển thị {transactions.length} / {total} giao dịch
            </span>

            <div className="flex items-center gap-2">
              <button
                disabled={page <= 1}
                onClick={() => setPage((prev) => Math.max(prev - 1, 1))}
                className="p-2 rounded-xl border border-slate-200 hover:bg-slate-50 text-slate-600 disabled:opacity-40 transition-all cursor-pointer"
              >
                <ChevronLeft className="w-4 h-4" />
              </button>
              <span className="text-xs font-bold text-slate-700 px-2">
                Trang {page} / {totalPages}
              </span>
              <button
                disabled={page >= totalPages}
                onClick={() => setPage((prev) => Math.min(prev + 1, totalPages))}
                className="p-2 rounded-xl border border-slate-200 hover:bg-slate-50 text-slate-600 disabled:opacity-40 transition-all cursor-pointer"
              >
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Transaction Detail Modal */}
      {openDetailModal && selectedTx && (
        <div className="fixed inset-0 bg-emerald-950/40 backdrop-blur-xs z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-[32px] max-w-lg w-full p-6 sm:p-8 space-y-6 shadow-2xl border border-emerald-100 animate__animated animate__zoomIn animate__faster">
            <div className="flex items-center justify-between border-b border-slate-100 pb-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-2xl bg-emerald-100 text-emerald-700 flex items-center justify-center">
                  <CreditCard className="w-5 h-5" />
                </div>
                <div>
                  <h4 className="text-lg font-black text-slate-900">Chi Tiết Giao Dịch</h4>
                  <p className="text-xs text-slate-500 font-semibold">Mã đơn #{selectedTx.orderCode}</p>
                </div>
              </div>
              <button
                onClick={() => setOpenDetailModal(false)}
                className="p-2 rounded-xl text-slate-400 hover:bg-slate-100 transition-colors"
              >
                ✕
              </button>
            </div>

            <div className="space-y-4 text-xs font-semibold text-slate-700">
              <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200 space-y-2">
                <div className="flex justify-between">
                  <span className="text-slate-500">Trạng thái:</span>
                  <div>{renderStatusBadge(selectedTx.status)}</div>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-500">Số tiền:</span>
                  <span className="font-black text-emerald-700 text-sm">{formatCurrency(selectedTx.amount)}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-500">Mã đơn hàng PayOS:</span>
                  <span className="font-mono font-bold text-slate-900">{selectedTx.orderCode}</span>
                </div>
              </div>

              <div className="space-y-2">
                <p className="text-[11px] font-bold uppercase text-slate-400">Thông tin người mua</p>
                <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200 space-y-1.5">
                  <p><strong className="text-slate-900">Họ tên:</strong> {selectedTx.user?.name || selectedTx.user?.displayName || 'N/A'}</p>
                  <p><strong className="text-slate-900">Email:</strong> {selectedTx.user?.email || 'N/A'}</p>
                  <p><strong className="text-slate-900">User ID:</strong> <span className="font-mono text-[11px]">{selectedTx.userId}</span></p>
                </div>
              </div>

              <div className="space-y-2">
                <p className="text-[11px] font-bold uppercase text-slate-400">Thời gian & Tham chiếu</p>
                <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200 space-y-1.5">
                  <p><strong className="text-slate-900">Thời gian khởi tạo:</strong> {formatDate(selectedTx.createdAt)}</p>
                  <p><strong className="text-slate-900">Cập nhật lần cuối:</strong> {formatDate(selectedTx.updatedAt)}</p>
                  {selectedTx.paymentLinkId && (
                    <p><strong className="text-slate-900">Payment Link ID:</strong> <span className="font-mono text-[11px]">{selectedTx.paymentLinkId}</span></p>
                  )}
                </div>
              </div>
            </div>

            <button
              onClick={() => setOpenDetailModal(false)}
              className="w-full py-3 rounded-2xl bg-slate-900 text-white font-extrabold text-sm hover:bg-slate-800 transition-all cursor-pointer"
            >
              Đóng
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

export default PaymentTransactionsManagement;
