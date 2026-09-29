import React, { useState, useEffect } from 'react';
import {
  Utensils,
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
  Flame,
  CheckCircle2,
  Tag,
  DollarSign,
  FolderPlus,
} from 'lucide-react';
import {
  getIngredientsApi,
  getCategoriesApi,
  deleteIngredientApi,
} from '../../../services/ingredientService';
import { AddEditIngredientModal } from './AddEditIngredientModal';
import { IngredientDetailModal } from './IngredientDetailModal';
import { CategoryManagementModal } from './CategoryManagementModal';
import { showToast } from '../../../components/common/Toast';

export const IngredientManagement = () => {
  const [ingredients, setIngredients] = useState([]);
  const [categories, setCategories] = useState([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [limit, setLimit] = useState(10);
  const [totalPages, setTotalPages] = useState(1);
  const [loading, setLoading] = useState(true);

  // Filters
  const [search, setSearch] = useState('');
  const [selectedCategoryId, setSelectedCategoryId] = useState('');
  const [isCommonFilter, setIsCommonFilter] = useState('');

  // Modals state
  const [openAddEditModal, setOpenAddEditModal] = useState(false);
  const [editingIngredient, setEditingIngredient] = useState(null);
  const [openDetailModal, setOpenDetailModal] = useState(false);
  const [selectedDetailId, setSelectedDetailId] = useState(null);
  const [openCategoryModal, setOpenCategoryModal] = useState(false);

  // Fetch Category Tree on Mount
  const fetchCategories = async () => {
    try {
      const res = await getCategoriesApi();
      const list = Array.isArray(res?.data) ? res.data : Array.isArray(res) ? res : [];
      setCategories(list);
    } catch (err) {
      console.error('Lỗi khi tải danh mục nguyên liệu:', err);
    }
  };

  // Fetch Ingredients List
  const fetchIngredients = async () => {
    setLoading(true);
    try {
      const params = {
        page,
        limit,
        search: search.trim() || undefined,
        categoryId: selectedCategoryId ? Number(selectedCategoryId) : undefined,
        isCommon: isCommonFilter !== '' ? isCommonFilter === 'true' : undefined,
      };

      const res = await getIngredientsApi(params);
      const resData = res?.data || res;

      if (resData) {
        setIngredients(resData.data || []);
        setTotal(resData.total || 0);
        setTotalPages(resData.totalPages || 1);
      }
    } catch (err) {
      console.error('Lỗi khi tải danh sách nguyên liệu:', err);
      showToast.error('Không thể tải danh sách nguyên liệu');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchCategories();
  }, []);

  useEffect(() => {
    fetchIngredients();
  }, [page, limit, selectedCategoryId, isCommonFilter]);

  const handleSearchSubmit = (e) => {
    e.preventDefault();
    setPage(1);
    fetchIngredients();
  };

  const handleDelete = async (ingredient) => {
    if (window.confirm(`Bạn có chắc chắn muốn xóa nguyên liệu "${ingredient.name}"?`)) {
      try {
        await deleteIngredientApi(ingredient.id);
        showToast.success('Xóa nguyên liệu thành công!');
        fetchIngredients();
      } catch (err) {
        console.error('Lỗi xóa nguyên liệu:', err);
        showToast.error(err.message || 'Xóa nguyên liệu thất bại');
      }
    }
  };

  const handleOpenAdd = () => {
    setEditingIngredient(null);
    setOpenAddEditModal(true);
  };

  const handleOpenEdit = (ingredient) => {
    setEditingIngredient(ingredient);
    setOpenAddEditModal(true);
  };

  const handleOpenDetail = (id) => {
    setSelectedDetailId(id);
    setOpenDetailModal(true);
  };

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(amount || 0);
  };

  // Flatten categories array for filter select dropdown
  const flattenCategories = (catList, prefix = '') => {
    let result = [];
    catList.forEach((cat) => {
      result.push({ id: cat.id, name: `${prefix}${cat.name}` });
      if (cat.children && cat.children.length > 0) {
        result = result.concat(flattenCategories(cat.children, `${prefix}${cat.name} > `));
      }
    });
    return result;
  };

  const categoryOptions = flattenCategories(categories);

  return (
    <div className="space-y-8 pb-12 animate__animated animate__fadeIn animate__faster">
      {/* Action Header Banner */}
      <div className="p-6 sm:p-8 rounded-[32px] bg-white border border-emerald-100 shadow-xs flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h3 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight flex items-center gap-2">
            <span>Quản Lý Kho Nguyên Liệu Thực Phẩm</span>
            <Sparkles className="w-5 h-5 text-emerald-600" />
          </h3>
          <p className="text-xs sm:text-sm text-slate-500 font-medium mt-1">
            Quản lý nguyên liệu tủ lạnh, danh mục phân loại & thông tin dinh dưỡng.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-3 self-start md:self-auto">
          <button
            onClick={() => setOpenCategoryModal(true)}
            className="px-5 py-3 rounded-2xl bg-emerald-50 hover:bg-emerald-100 text-emerald-700 font-extrabold text-xs sm:text-sm border border-emerald-200 transition-all cursor-pointer flex items-center gap-2"
          >
            <FolderPlus className="w-4 h-4 text-emerald-600" />
            <span>Quản Lý Danh Mục</span>
          </button>

          <button
            onClick={handleOpenAdd}
            className="px-6 py-3 rounded-2xl bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-700 hover:to-teal-700 text-white font-extrabold text-xs sm:text-sm shadow-md shadow-emerald-600/20 hover:scale-105 transition-all duration-200 cursor-pointer flex items-center gap-2"
          >
            <Plus className="w-4 h-4 stroke-[3]" />
            <span>Thêm Nguyên Liệu Mới</span>
          </button>
        </div>
      </div>

      {/* Control & Search Bar */}
      <div className="p-6 rounded-[32px] bg-white border border-slate-100 shadow-md space-y-4">
        <form onSubmit={handleSearchSubmit} className="grid grid-cols-1 sm:grid-cols-12 gap-3">
          {/* Search Field */}
          <div className="sm:col-span-5 relative">
            <Search className="w-4 h-4 text-slate-400 absolute left-4 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Tìm kiếm theo tên nguyên liệu..."
              className="w-full pl-10 pr-4 py-2.5 rounded-2xl bg-slate-50 border border-slate-200 text-xs sm:text-sm font-semibold outline-hidden focus:border-emerald-500 focus:bg-white transition-all"
            />
          </div>

          {/* Category Filter Dropdown */}
          <div className="sm:col-span-4 relative">
            <select
              value={selectedCategoryId}
              onChange={(e) => {
                setSelectedCategoryId(e.target.value);
                setPage(1);
              }}
              className="w-full px-4 py-2.5 rounded-2xl bg-slate-50 border border-slate-200 text-xs sm:text-sm font-semibold text-slate-700 outline-hidden focus:border-emerald-500 transition-all cursor-pointer"
            >
              <option value="">-- Tất cả danh mục --</option>
              {categoryOptions.map((cat) => (
                <option key={cat.id} value={cat.id}>
                  {cat.name}
                </option>
              ))}
            </select>
          </div>

          {/* Is Common Filter */}
          <div className="sm:col-span-3 relative">
            <select
              value={isCommonFilter}
              onChange={(e) => {
                setIsCommonFilter(e.target.value);
                setPage(1);
              }}
              className="w-full px-4 py-2.5 rounded-2xl bg-slate-50 border border-slate-200 text-xs sm:text-sm font-semibold text-slate-700 outline-hidden focus:border-emerald-500 transition-all cursor-pointer"
            >
              <option value="">Lọc: Tất cả</option>
              <option value="true">Chỉ loại Phổ Biến</option>
              <option value="false">Chỉ loại Thường</option>
            </select>
          </div>
        </form>

        {/* Total stats info */}
        <div className="flex items-center justify-between text-xs font-semibold text-slate-500 pt-2 border-t border-slate-100">
          <span>Tìm thấy tổng cộng <strong className="text-emerald-700 font-extrabold">{total}</strong> nguyên liệu</span>
          <span>Trang {page} / {totalPages}</span>
        </div>
      </div>

      {/* Main Data Table */}
      <div className="animate__animated animate__fadeInUp p-6 rounded-[32px] bg-white border border-slate-100 shadow-md space-y-4">
        {loading ? (
          <div className="py-20 text-center space-y-3">
            <Loader2 className="w-8 h-8 text-emerald-600 animate-spin mx-auto" />
            <p className="text-xs font-bold text-slate-500">Đang tải danh sách nguyên liệu...</p>
          </div>
        ) : ingredients.length === 0 ? (
          <div className="py-16 text-center text-slate-400 font-medium text-sm space-y-2">
            <Utensils className="w-10 h-10 text-slate-300 mx-auto" />
            <p>Không tìm thấy nguyên liệu nào phù hợp với bộ lọc hiện tại.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse min-w-[900px]">
              <thead>
                <tr className="border-b border-emerald-100 bg-emerald-50/60 text-[11px] font-black text-emerald-950 uppercase tracking-wider">
                  <th className="py-3.5 px-4 rounded-l-2xl">Mã ID</th>
                  <th className="py-3.5 px-4">Hình Ảnh</th>
                  <th className="py-3.5 px-4">Tên Nguyên Liệu</th>
                  <th className="py-3.5 px-4">Danh Mục</th>
                  <th className="py-3.5 px-4">Đơn Vị</th>
                  <th className="py-3.5 px-4">Calo / 100g</th>
                  <th className="py-3.5 px-4">Giá TB (VND)</th>
                  <th className="py-3.5 px-4">Phổ Biến</th>
                  <th className="py-3.5 px-4 rounded-r-2xl text-right">Thao Tác</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 text-xs">
                {ingredients.map((item) => (
                  <tr key={item.id} className="hover:bg-slate-50/80 transition-colors font-semibold text-slate-800">
                    <td className="py-4 px-4 font-mono font-bold text-emerald-700">#{item.id}</td>
                    <td className="py-3 px-4">
                      <IngredientSquareImage imagePath={item.imagePath} name={item.name} />
                    </td>
                    <td className="py-4 px-4 font-black text-slate-900 text-sm">
                      <div className="flex items-center gap-2">
                        <span>{item.name}</span>
                      </div>
                    </td>
                    <td className="py-4 px-4 font-bold text-slate-700">
                      <span className="px-2.5 py-1 rounded-xl bg-slate-100 text-slate-700 border border-slate-200">
                        {item.categoryName || `DM #${item.categoryId}`}
                      </span>
                    </td>
                    <td className="py-4 px-4 font-extrabold text-slate-600">{item.defaultUnit}</td>
                    <td className="py-4 px-4">
                      {item.caloriesPer100g ? (
                        <span className="font-extrabold text-amber-600 flex items-center gap-1">
                          <Flame className="w-3.5 h-3.5" />
                          {item.caloriesPer100g} kcal
                        </span>
                      ) : (
                        <span className="text-slate-400 font-normal">--</span>
                      )}
                    </td>
                    <td className="py-4 px-4 font-black text-emerald-700">
                      {item.averagePricePerUnit ? formatCurrency(item.averagePricePerUnit) : '--'}
                    </td>
                    <td className="py-4 px-4">
                      {item.isCommon ? (
                        <span className="px-2.5 py-1 rounded-full bg-emerald-50 text-emerald-700 text-[10px] font-extrabold border border-emerald-200 inline-flex items-center gap-1">
                          <CheckCircle2 className="w-3 h-3 text-emerald-600" /> Phổ biến
                        </span>
                      ) : (
                        <span className="px-2.5 py-1 rounded-full bg-slate-100 text-slate-500 text-[10px] font-bold border border-slate-200">
                          Thường
                        </span>
                      )}
                    </td>
                    <td className="py-4 px-4 text-right">
                      <div className="flex items-center justify-end gap-1.5">
                        <button
                          onClick={() => handleOpenDetail(item.id)}
                          className="p-2 rounded-xl bg-emerald-50 hover:bg-emerald-100 text-emerald-700 transition-colors cursor-pointer"
                          title="Xem chi tiết nguyên liệu"
                        >
                          <Eye className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => handleOpenEdit(item)}
                          className="p-2 rounded-xl bg-blue-50 hover:bg-blue-100 text-blue-700 transition-colors cursor-pointer"
                          title="Chỉnh sửa nguyên liệu"
                        >
                          <Edit2 className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => handleDelete(item)}
                          className="p-2 rounded-xl bg-rose-50 hover:bg-rose-100 text-rose-600 transition-colors cursor-pointer"
                          title="Xóa nguyên liệu"
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
              Hiển thị {ingredients.length} / {total} nguyên liệu
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

      {/* Add / Edit Ingredient Modal */}
      <AddEditIngredientModal
        isOpen={openAddEditModal}
        onClose={() => setOpenAddEditModal(false)}
        onSuccess={fetchIngredients}
        ingredient={editingIngredient}
        categories={categories}
      />

      {/* Ingredient Detail Modal */}
      <IngredientDetailModal
        isOpen={openDetailModal}
        onClose={() => setOpenDetailModal(false)}
        ingredientId={selectedDetailId}
      />

      {/* Category Management Modal */}
      <CategoryManagementModal
        isOpen={openCategoryModal}
        onClose={() => setOpenCategoryModal(false)}
        onSuccess={fetchCategories}
      />
    </div>
  );
};

// Helper component for Table Row Image Square Frame
const IngredientSquareImage = ({ imagePath, name }) => {
  const [error, setError] = useState(false);

  return (
    <div className="w-10 h-10 rounded-xl bg-slate-50 border border-slate-200 flex items-center justify-center overflow-hidden shrink-0 shadow-2xs">
      {imagePath && !error ? (
        <img
          src={imagePath}
          alt={name}
          className="w-full h-full object-cover"
          onError={() => setError(true)}
        />
      ) : (
        <span className="text-slate-300 text-xs font-semibold">--</span>
      )}
    </div>
  );
};

export default IngredientManagement;
