import React, { useState, useEffect } from 'react';
import {
  BookOpen,
  Search,
  Plus,
  Filter,
  Eye,
  Edit2,
  Trash2,
  ChevronLeft,
  ChevronRight,
  Sparkles,
  Loader2,
  Clock,
  Users,
  ChefHat,
  DollarSign,
  UtensilsCrossed,
} from 'lucide-react';
import { getRecipesApi, deleteRecipeApi } from '../../../services/recipeService';
import { RecipeDetailModal } from './RecipeDetailModal';
import { AddEditRecipeModal } from './AddEditRecipeModal';
import { showToast } from '../../../components/common/Toast';

export const RecipeManagement = () => {
  const [recipes, setRecipes] = useState([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [limit, setLimit] = useState(10);
  const [totalPages, setTotalPages] = useState(1);
  const [loading, setLoading] = useState(true);

  // Filters
  const [search, setSearch] = useState('');
  const [mealTypeFilter, setMealTypeFilter] = useState('');
  const [difficultyFilter, setDifficultyFilter] = useState('');

  // Modals
  const [openDetailModal, setOpenDetailModal] = useState(false);
  const [selectedRecipeId, setSelectedRecipeId] = useState(null);
  const [openAddEditModal, setOpenAddEditModal] = useState(false);
  const [editingRecipe, setEditingRecipe] = useState(null);

  // Delete Confirm Modal State
  const [recipeToDelete, setRecipeToDelete] = useState(null);
  const [deleting, setDeleting] = useState(false);

  const fetchRecipes = async () => {
    setLoading(true);
    try {
      const params = {
        page,
        limit,
        search: search.trim() || undefined,
        mealType: mealTypeFilter || undefined,
        difficulty: difficultyFilter || undefined,
      };

      const res = await getRecipesApi(params);
      const resData = res?.data || res;

      if (resData) {
        setRecipes(resData.data || []);
        setTotal(resData.total || 0);
        setTotalPages(resData.totalPages || 1);
      }
    } catch (err) {
      console.error('Lỗi khi tải danh sách công thức:', err);
      showToast.error('Không thể tải danh sách công thức nấu ăn');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchRecipes();
  }, [page, limit, mealTypeFilter, difficultyFilter]);

  const handleSearchSubmit = (e) => {
    e.preventDefault();
    setPage(1);
    fetchRecipes();
  };

  const handleDelete = (recipe) => {
    setRecipeToDelete(recipe);
  };

  const confirmDeleteRecipe = async () => {
    if (!recipeToDelete) return;
    setDeleting(true);
    try {
      await deleteRecipeApi(recipeToDelete.id);
      showToast.success('Xóa công thức nấu ăn thành công!');
      setRecipeToDelete(null);
      fetchRecipes();
    } catch (err) {
      console.error('Lỗi xóa công thức:', err);
      const errMsg = err.response?.data?.message || err.message || '';
      if (errMsg.includes('Cannot DELETE') || errMsg.includes('404')) {
        showToast.error('Máy chủ chưa kích hoạt hoặc không tìm thấy route xóa công thức (DELETE /recipes)');
      } else {
        showToast.error(errMsg || 'Xóa công thức thất bại');
      }
    } finally {
      setDeleting(false);
    }
  };

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(amount || 0);
  };

  const translateMealType = (type) => {
    const map = {
      breakfast: 'Bữa Sáng',
      lunch: 'Bữa Trưa',
      dinner: 'Bữa Tối',
      snack: 'Ăn Vặt',
      dessert: 'Tráng Miệng',
      drink: 'Thức Uống',
    };
    return map[type] || type;
  };

  const translateDifficulty = (diff) => {
    const map = {
      easy: 'Dễ',
      medium: 'Trung Bình',
      hard: 'Phức Tạp',
    };
    return map[diff] || diff;
  };

  return (
    <div className="space-y-8 pb-12 animate__animated animate__fadeIn animate__faster">
      {/* Action Header Banner */}
      <div className="p-6 sm:p-8 rounded-[32px] bg-white border border-emerald-100 shadow-xs flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h3 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight flex items-center gap-2">
            <span>Quản Lý Công Thức Nấu Ăn</span>
            <UtensilsCrossed className="w-6 h-6 text-emerald-600" />
          </h3>
          <p className="text-xs sm:text-sm text-slate-500 font-medium mt-1">
            Quản lý công thức món ăn master, khẩu phần, nguyên liệu & các bước thực hiện.
          </p>
        </div>

        <button
          onClick={() => {
            setEditingRecipe(null);
            setOpenAddEditModal(true);
          }}
          className="px-6 py-3 rounded-2xl bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-700 hover:to-teal-700 text-white font-extrabold text-xs sm:text-sm shadow-md shadow-emerald-600/20 hover:scale-105 transition-all duration-200 cursor-pointer flex items-center gap-2 self-start md:self-auto"
        >
          <Plus className="w-4 h-4 stroke-[3]" />
          <span>Thêm Công Thức Mới</span>
        </button>
      </div>

      {/* Control & Search Bar */}
      <div className="p-6 rounded-[32px] bg-white border border-slate-100 shadow-md space-y-4">
        <form onSubmit={handleSearchSubmit} className="grid grid-cols-1 sm:grid-cols-12 gap-3">
          {/* Search Input */}
          <div className="sm:col-span-6 relative">
            <Search className="w-4 h-4 text-slate-400 absolute left-4 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Tìm kiếm công thức món ăn..."
              className="w-full pl-10 pr-4 py-2.5 rounded-2xl bg-slate-50 border border-slate-200 text-xs sm:text-sm font-semibold outline-hidden focus:border-emerald-500 focus:bg-white transition-all"
            />
          </div>

          {/* Meal Type Filter */}
          <div className="sm:col-span-3 relative">
            <select
              value={mealTypeFilter}
              onChange={(e) => {
                setMealTypeFilter(e.target.value);
                setPage(1);
              }}
              className="w-full px-4 py-2.5 rounded-2xl bg-slate-50 border border-slate-200 text-xs sm:text-sm font-semibold text-slate-700 outline-hidden focus:border-emerald-500 transition-all cursor-pointer"
            >
              <option value="">Tất cả bữa ăn</option>
              <option value="breakfast">Bữa Sáng</option>
              <option value="lunch">Bữa Trưa</option>
              <option value="dinner">Bữa Tối</option>
              <option value="snack">Ăn Vặt</option>
              <option value="dessert">Tráng Miệng</option>
              <option value="drink">Thức Uống</option>
            </select>
          </div>

          {/* Difficulty Filter */}
          <div className="sm:col-span-3 relative">
            <select
              value={difficultyFilter}
              onChange={(e) => {
                setDifficultyFilter(e.target.value);
                setPage(1);
              }}
              className="w-full px-4 py-2.5 rounded-2xl bg-slate-50 border border-slate-200 text-xs sm:text-sm font-semibold text-slate-700 outline-hidden focus:border-emerald-500 transition-all cursor-pointer"
            >
              <option value="">Tất cả độ khó</option>
              <option value="easy">Dễ (easy)</option>
              <option value="medium">Trung bình (medium)</option>
              <option value="hard">Phức tạp (hard)</option>
            </select>
          </div>
        </form>

        <div className="flex items-center justify-between text-xs font-semibold text-slate-500 pt-2 border-t border-slate-100">
          <span>Tổng số công thức: <strong className="text-emerald-700 font-extrabold">{total}</strong></span>
          <span>Trang {page} / {totalPages}</span>
        </div>
      </div>

      {/* Recipes Table */}
      <div className="animate__animated animate__fadeInUp p-6 rounded-[32px] bg-white border border-slate-100 shadow-md space-y-4">
        {loading ? (
          <div className="py-20 text-center space-y-3">
            <Loader2 className="w-8 h-8 text-emerald-600 animate-spin mx-auto" />
            <p className="text-xs font-bold text-slate-500">Đang tải danh sách công thức...</p>
          </div>
        ) : recipes.length === 0 ? (
          <div className="py-16 text-center text-slate-400 font-medium text-sm space-y-2">
            <ChefHat className="w-10 h-10 text-slate-300 mx-auto" />
            <p>Chưa có công thức món ăn nào phù hợp với bộ lọc.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse min-w-[950px]">
              <thead>
                <tr className="border-b border-emerald-100 bg-emerald-50/60 text-[11px] font-black text-emerald-950 uppercase tracking-wider">
                  <th className="py-3.5 px-4 rounded-l-2xl">Mã ID</th>
                  <th className="py-3.5 px-4">Tên Món Ăn</th>
                  <th className="py-3.5 px-4">Bữa Ăn</th>
                  <th className="py-3.5 px-4">Thời Gian Nấu</th>
                  <th className="py-3.5 px-4">Khẩu Phần</th>
                  <th className="py-3.5 px-4">Độ Khó</th>
                  <th className="py-3.5 px-4">Chi Phí Ước Tính</th>
                  <th className="py-3.5 px-4 rounded-r-2xl text-right">Thao Tác</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 text-xs">
                {recipes.map((item) => (
                  <tr key={item.id} className="hover:bg-slate-50/80 transition-colors font-semibold text-slate-800">
                    <td className="py-4 px-4 font-mono font-bold text-emerald-700">#{item.id?.substring(0, 8)}</td>
                    <td className="py-4 px-4 font-black text-slate-900 text-sm">
                      <div className="flex flex-col">
                        <span>{item.title}</span>
                        {item.description && (
                          <span className="text-[11px] text-slate-400 font-normal line-clamp-1">{item.description}</span>
                        )}
                      </div>
                    </td>
                    <td className="py-4 px-4 font-bold text-slate-700">
                      <span className="px-2.5 py-1 rounded-xl bg-emerald-50 text-emerald-700 border border-emerald-200">
                        {translateMealType(item.mealType)}
                      </span>
                    </td>
                    <td className="py-4 px-4 font-bold text-slate-700">
                      <span className="flex items-center gap-1">
                        <Clock className="w-3.5 h-3.5 text-emerald-600" />
                        {item.cookTimeMinutes} phút
                      </span>
                    </td>
                    <td className="py-4 px-4 font-bold text-slate-700">
                      <span className="flex items-center gap-1">
                        <Users className="w-3.5 h-3.5 text-blue-600" />
                        {item.servings} phần
                      </span>
                    </td>
                    <td className="py-4 px-4 font-bold text-slate-700">
                      <span className="px-2.5 py-1 rounded-xl bg-slate-100 text-slate-700 border border-slate-200">
                        {translateDifficulty(item.difficultyLevel)}
                      </span>
                    </td>
                    <td className="py-4 px-4 font-black text-emerald-700">
                      {item.estimatedCost ? formatCurrency(item.estimatedCost) : '--'}
                    </td>
                    <td className="py-4 px-4 text-right">
                      <div className="flex items-center justify-end gap-1.5">
                        <button
                          onClick={() => {
                            setSelectedRecipeId(item.id);
                            setOpenDetailModal(true);
                          }}
                          className="p-2 rounded-xl bg-emerald-50 hover:bg-emerald-100 text-emerald-700 transition-colors cursor-pointer"
                          title="Xem chi tiết công thức"
                        >
                          <Eye className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => {
                            setEditingRecipe(item);
                            setOpenAddEditModal(true);
                          }}
                          className="p-2 rounded-xl bg-blue-50 hover:bg-blue-100 text-blue-700 transition-colors cursor-pointer"
                          title="Chỉnh sửa công thức"
                        >
                          <Edit2 className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => handleDelete(item)}
                          className="p-2 rounded-xl bg-rose-50 hover:bg-rose-100 text-rose-600 transition-colors cursor-pointer"
                          title="Xóa công thức"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
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
              Hiển thị {recipes.length} / {total} công thức
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

      {/* Recipe Detail Modal */}
      <RecipeDetailModal
        isOpen={openDetailModal}
        onClose={() => setOpenDetailModal(false)}
        recipeId={selectedRecipeId}
      />

      {/* Add / Edit Recipe Modal */}
      <AddEditRecipeModal
        isOpen={openAddEditModal}
        onClose={() => setOpenAddEditModal(false)}
        onSuccess={fetchRecipes}
        recipe={editingRecipe}
      />

      {/* Custom Delete Confirmation Modal */}
      {recipeToDelete && (
        <div className="fixed inset-0 bg-emerald-950/40 backdrop-blur-xs z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-[32px] max-w-md w-full p-6 sm:p-8 space-y-6 shadow-2xl border border-rose-100 animate__animated animate__zoomIn animate__faster text-center">
            <div className="w-16 h-16 rounded-full bg-rose-50 text-rose-600 flex items-center justify-center mx-auto border border-rose-100 shadow-xs">
              <Trash2 className="w-8 h-8" />
            </div>

            <div className="space-y-2">
              <h4 className="text-xl font-black text-slate-900">Xác Nhận Xóa Công Thức</h4>
              <p className="text-xs sm:text-sm text-slate-500 font-medium">
                Bạn có chắc chắn muốn xóa công thức món ăn{' '}
                <strong className="text-rose-600 font-bold">"{recipeToDelete.title}"</strong>? Hành động này không thể hoàn tác.
              </p>
            </div>

            <div className="flex items-center gap-3 pt-2">
              <button
                type="button"
                onClick={() => setRecipeToDelete(null)}
                className="flex-1 py-3 rounded-2xl bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs sm:text-sm transition-all cursor-pointer"
              >
                Hủy Bỏ
              </button>
              <button
                type="button"
                disabled={deleting}
                onClick={confirmDeleteRecipe}
                className="flex-1 py-3 rounded-2xl bg-rose-600 hover:bg-rose-700 text-white font-extrabold text-xs sm:text-sm shadow-md shadow-rose-600/20 transition-all cursor-pointer flex items-center justify-center gap-2"
              >
                {deleting ? <Loader2 className="w-4 h-4 animate-spin" /> : <Trash2 className="w-4 h-4" />}
                <span>{deleting ? 'Đang Xóa...' : 'Xóa Công Thức'}</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default RecipeManagement;
