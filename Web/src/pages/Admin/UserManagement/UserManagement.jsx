import React, { useEffect, useState, useCallback } from 'react';
import {
  Search,
  Filter,
  Eye,
  Lock,
  Unlock,
  CheckCircle,
  AlertTriangle,
  Loader2,
  ChevronLeft,
  ChevronRight,
  RefreshCw,
  Clock,
} from 'lucide-react';
import AnimatedCounter from '../../../components/common/AnimatedCounter';
import { UserDetailModal } from './UserDetailModal';
import {
  getAdminUsersApi,
  suspendUserApi,
  activateUserApi,
} from '../../../services/adminService';
import { showToast } from '../../../components/common/Toast';

const resolveAvatarUrl = (rawUrl) => {
  if (!rawUrl) return null;
  let formatted = rawUrl.trim();
  if (formatted.includes('api.friggy.io.vn')) {
    formatted = formatted.replace('api.friggy.io.vn', 'file.friggy.io.vn');
  }
  if (formatted.startsWith('http://') || formatted.startsWith('https://') || formatted.startsWith('data:')) {
    return formatted;
  }
  if (formatted.startsWith('file.friggy.io.vn')) {
    return `https://${formatted}`;
  }
  const apiBase = import.meta.env.VITE_API_BASE_URL || import.meta.env.VITE_API_URL || 'https://api.friggy.io.vn/api/v1';
  let fileBase = 'https://file.friggy.io.vn';
  if (!apiBase.includes('friggy.io.vn')) {
    fileBase = apiBase.replace(/\/api\/v1\/?$/, '').replace(/\/$/, '');
  }
  return `${fileBase}${formatted.startsWith('/') ? '' : '/'}${formatted}`;
};

export const UserManagement = () => {

  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [actionLoadingId, setActionLoadingId] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('All'); // 'All' | 'active' | 'suspended' | 'pending'
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalUsers, setTotalUsers] = useState(0);

  const [selectedUser, setSelectedUser] = useState(null);

  // Load Users from Backend API
  const fetchUsers = useCallback(async () => {
    setLoading(true);
    try {
      const params = {
        page,
        limit: 15,
      };
      if (searchTerm.trim()) {
        params.q = searchTerm.trim();
      }
      if (statusFilter !== 'All') {
        params.status = statusFilter.toLowerCase();
      }

      const res = await getAdminUsersApi(params);
      const resData = res?.data?.data ? res.data : res;

      const userList = Array.isArray(resData?.data) ? resData.data : Array.isArray(resData) ? resData : [];
      setUsers(userList);
      setTotalUsers(resData?.total ?? userList.length);
      setTotalPages(resData?.totalPages ?? 1);
    } catch (err) {
      console.error('Lỗi khi tải danh sách users:', err);
      showToast.error(err.message || 'Không thể tải danh sách người dùng từ hệ thống');
    } finally {
      setLoading(false);
    }
  }, [page, searchTerm, statusFilter]);

  useEffect(() => {
    const timer = setTimeout(() => {
      fetchUsers();
    }, 300);
    return () => clearTimeout(timer);
  }, [fetchUsers]);

  // Handle Toggle Suspend / Activate User
  const handleToggleStatus = async (user) => {
    const isSuspended = user.status === 'suspended';
    setActionLoadingId(user.id);
    try {
      if (isSuspended) {
        await activateUserApi(user.id);
        showToast.success(`Đã mở khóa tài khoản ${user.name || user.googleEmail}`);
      } else {
        await suspendUserApi(user.id);
        showToast.success(`Đã khóa tài khoản ${user.name || user.googleEmail}`);
      }
      // Refresh list after change
      fetchUsers();
    } catch (err) {
      console.error('Lỗi thay đổi trạng thái user:', err);
      showToast.error(err.message || 'Thao tác thất bại');
    } finally {
      setActionLoadingId(null);
    }
  };

  return (
    <div className="space-y-6 pb-12">
      {/* Top Action & Search Bar */}
      <div className="p-6 rounded-[32px] bg-white border border-slate-100 shadow-md flex flex-col md:flex-row md:items-center justify-between gap-4">
        {/* Search Field */}
        <div className="relative flex-1 max-w-md">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => {
              setSearchTerm(e.target.value);
              setPage(1);
            }}
            placeholder="Tìm theo Tên, Email hoặc SĐT..."
            className="w-full pl-10 pr-4 py-3 bg-slate-50 border border-slate-200 rounded-2xl text-xs font-semibold text-slate-900 focus:outline-none focus:border-emerald-500 focus:bg-white focus:ring-4 focus:ring-emerald-500/10 transition-all"
          />
        </div>

        {/* Filter & Refresh Actions */}
        <div className="flex items-center gap-3 flex-wrap">
          {/* Status Filter Dropdown */}
          <div className="flex items-center gap-1 bg-slate-50 p-1.5 rounded-2xl border border-slate-200">
            <Filter className="w-3.5 h-3.5 text-slate-400 ml-2" />
            <button
              onClick={() => {
                setStatusFilter('All');
                setPage(1);
              }}
              className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                statusFilter === 'All'
                  ? 'bg-white text-emerald-700 shadow-xs'
                  : 'text-slate-500 hover:text-slate-800'
              }`}
            >
              Tất cả
            </button>
            <button
              onClick={() => {
                setStatusFilter('active');
                setPage(1);
              }}
              className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                statusFilter === 'active'
                  ? 'bg-white text-emerald-700 shadow-xs'
                  : 'text-slate-500 hover:text-slate-800'
              }`}
            >
              Hoạt động
            </button>
            <button
              onClick={() => {
                setStatusFilter('suspended');
                setPage(1);
              }}
              className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                statusFilter === 'suspended'
                  ? 'bg-white text-rose-600 shadow-xs'
                  : 'text-slate-500 hover:text-slate-800'
              }`}
            >
              Bị khóa
            </button>
            <button
              onClick={() => {
                setStatusFilter('pending');
                setPage(1);
              }}
              className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                statusFilter === 'pending'
                  ? 'bg-white text-amber-600 shadow-xs'
                  : 'text-slate-500 hover:text-slate-800'
              }`}
            >
              Chờ duyệt
            </button>
          </div>

          <button
            onClick={fetchUsers}
            className="p-3 bg-slate-50 hover:bg-slate-100 text-slate-600 rounded-2xl border border-slate-200 transition-colors cursor-pointer"
            title="Làm mới danh sách"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      {/* Main Users Table */}
      <div className="p-6 rounded-[32px] bg-white border border-slate-100 shadow-md space-y-4">
        <div className="flex items-center justify-between border-b border-slate-100 pb-4">
          <div>
            <h3 className="text-lg font-black text-slate-900 tracking-tight flex items-center gap-1.5">
              <span>Danh Sách Tài Khoản Người Dùng (</span>
              <span className="text-emerald-600"><AnimatedCounter end={totalUsers} duration={1.5} /></span>
              <span>)</span>
            </h3>

            <p className="text-xs text-slate-500 font-medium">
              Quản lý danh sách người dùng hệ thống Friggy từ cơ sở dữ liệu backend
            </p>
          </div>
        </div>

        {loading ? (
          <div className="py-16 text-center text-slate-400 font-semibold text-sm flex flex-col items-center justify-center gap-3">
            <Loader2 className="w-8 h-8 animate-spin text-emerald-600" />
            <p>Đang tải danh sách người dùng từ hệ thống...</p>
          </div>
        ) : users.length === 0 ? (
          <div className="py-12 text-center text-slate-400 font-semibold text-sm">
            Không tìm thấy người dùng nào phù hợp với bộ lọc.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse min-w-[850px]">
              <thead>
                <tr className="border-b border-slate-200/80 bg-slate-50/80 text-[11px] font-black text-slate-500 uppercase tracking-wider">
                  <th className="py-3.5 px-4 rounded-l-2xl">Thành Viên</th>
                  <th className="py-3.5 px-4">Thông Tin Liên Hệ</th>
                  <th className="py-3.5 px-4">Gói Dịch Vụ</th>
                  <th className="py-3.5 px-4">Trạng Thái</th>
                  <th className="py-3.5 px-4">Ngày Tham Gia</th>
                  <th className="py-3.5 px-4 rounded-r-2xl text-right">Thao Tác</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 text-xs">
                {users.map((u, idx) => {
                  const avatarUrl =
                    resolveAvatarUrl(u.profile?.avatarUrl) ||
                    `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(
                      u.name || u.googleEmail || 'User'
                    )}`;

                  const packageName =
                    u.subscription?.plan?.displayName ||
                    u.subscription?.plan?.name ||
                    'Miễn Phí (FREE)';

                  const isSuspended = u.status === 'suspended';
                  const isPending = u.status === 'pending';
                  const isActionLoading = actionLoadingId === u.id;

                  const createdDateStr = u.createdAt
                    ? new Date(u.createdAt).toLocaleDateString('vi-VN')
                    : 'N/A';

                  return (
                    <tr
                      key={u.id}
                      className="hover:bg-slate-50/80 transition-colors font-semibold text-slate-800 group animate__animated animate__fadeIn"
                    >
                      {/* Member Name & Avatar */}
                      <td className="py-4 px-4">
                        <div className="flex items-center gap-3">
                          <img
                            src={avatarUrl}
                            alt={u.name || 'User'}
                            className="w-10 h-10 rounded-2xl object-cover border border-slate-200 bg-slate-100 shadow-2xs"
                          />
                          <div>
                            <p className="font-black text-slate-900 group-hover:text-emerald-700 transition-colors">
                              {u.name || u.googleEmail?.split('@')[0] || 'Người dùng'}
                            </p>
                            <p className="text-[11px] text-slate-400 font-medium">
                              Provider: {u.authProvider || 'google'}
                            </p>
                          </div>
                        </div>
                      </td>

                      {/* Contact Info */}
                      <td className="py-4 px-4">
                        <div>
                          <p className="font-bold text-slate-800">{u.googleEmail || 'N/A'}</p>
                          <p className="text-[11px] text-slate-500">{u.phone || 'Chưa cập nhật SĐT'}</p>
                        </div>
                      </td>

                      {/* Package Badge */}
                      <td className="py-4 px-4">
                        <span
                          className={`px-3 py-1 rounded-xl text-[11px] font-extrabold border ${
                            packageName.includes('VIP')
                              ? 'bg-teal-50 text-teal-700 border-teal-200'
                              : packageName.includes('PRO')
                              ? 'bg-indigo-50 text-indigo-700 border-indigo-200'
                              : 'bg-slate-100 text-slate-700 border-slate-200'
                          }`}
                        >
                          {packageName}
                        </span>
                      </td>

                      {/* Status Badge */}
                      <td className="py-4 px-4">
                        {isSuspended ? (
                          <span className="px-2.5 py-1 rounded-full bg-rose-50 text-rose-700 text-[11px] font-extrabold border border-rose-200 inline-flex items-center gap-1">
                            <AlertTriangle className="w-3.5 h-3.5 text-rose-500" />
                            Bị khóa
                          </span>
                        ) : isPending ? (
                          <span className="px-2.5 py-1 rounded-full bg-amber-50 text-amber-700 text-[11px] font-extrabold border border-amber-200 inline-flex items-center gap-1">
                            <Clock className="w-3.5 h-3.5 text-amber-500" />
                            Chờ duyệt
                          </span>
                        ) : (
                          <span className="px-2.5 py-1 rounded-full bg-emerald-50 text-emerald-700 text-[11px] font-extrabold border border-emerald-200 inline-flex items-center gap-1">
                            <CheckCircle className="w-3.5 h-3.5 text-emerald-500" />
                            Hoạt động
                          </span>
                        )}
                      </td>

                      {/* Join Date */}
                      <td className="py-4 px-4 text-slate-500 font-medium">{createdDateStr}</td>

                      {/* Actions */}
                      <td className="py-4 px-4 text-right">
                        <div className="flex items-center justify-end gap-1.5">
                          {/* View Detail */}
                          <button
                            onClick={() => setSelectedUser(u)}
                            className="p-2 rounded-xl text-slate-500 hover:text-emerald-700 hover:bg-emerald-50 transition-colors cursor-pointer"
                            title="Xem Chi Tiết"
                          >
                            <Eye className="w-4 h-4" />
                          </button>

                          {/* Toggle Lock / Unlock */}
                          <button
                            disabled={isActionLoading}
                            onClick={() => handleToggleStatus(u)}
                            className={`p-2 rounded-xl transition-colors cursor-pointer disabled:opacity-50 ${
                              isSuspended
                                ? 'text-rose-600 hover:text-emerald-700 hover:bg-emerald-50'
                                : 'text-slate-400 hover:text-rose-600 hover:bg-rose-50'
                            }`}
                            title={isSuspended ? 'Mở Khóa Tài Khoản' : 'Khóa Tài Khoản'}
                          >
                            {isActionLoading ? (
                              <Loader2 className="w-4 h-4 animate-spin text-emerald-600" />
                            ) : isSuspended ? (
                              <Unlock className="w-4 h-4" />
                            ) : (
                              <Lock className="w-4 h-4" />
                            )}
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}

        {/* Pagination Controls */}
        {totalPages > 1 && (
          <div className="flex items-center justify-between pt-4 border-t border-slate-100">
            <p className="text-xs text-slate-500 font-medium">
              Trang {page} / {totalPages} (Tổng số {totalUsers} người dùng)
            </p>
            <div className="flex items-center gap-2">
              <button
                disabled={page <= 1 || loading}
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                className="p-2 rounded-xl border border-slate-200 text-slate-600 hover:bg-slate-50 disabled:opacity-40 disabled:hover:bg-transparent transition-colors cursor-pointer"
              >
                <ChevronLeft className="w-4 h-4" />
              </button>
              <button
                disabled={page >= totalPages || loading}
                onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                className="p-2 rounded-xl border border-slate-200 text-slate-600 hover:bg-slate-50 disabled:opacity-40 disabled:hover:bg-transparent transition-colors cursor-pointer"
              >
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Detail Modal */}
      {selectedUser && (
        <UserDetailModal
          user={selectedUser}
          onClose={() => setSelectedUser(null)}
        />
      )}
    </div>
  );
};

export default UserManagement;
