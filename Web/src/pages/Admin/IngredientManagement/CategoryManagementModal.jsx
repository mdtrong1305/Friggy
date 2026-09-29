import React, { useState, useEffect } from 'react';
import { X, Plus, Edit2, Trash2, FolderPlus, Loader2, Save } from 'lucide-react';
import {
  getCategoriesApi,
  createCategoryApi,
  updateCategoryApi,
  deleteCategoryApi,
} from '../../../services/ingredientService';
import { showToast } from '../../../components/common/Toast';

export const CategoryManagementModal = ({ isOpen, onClose, onSuccess }) => {
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);

  // Form state
  const [editingCategory, setEditingCategory] = useState(null);
  const [name, setName] = useState('');
  const [iconPath, setIconPath] = useState('');
  const [parentId, setParentId] = useState('');
  const [defaultShelfLifeDays, setDefaultShelfLifeDays] = useState('');

  const fetchCategories = async () => {
    setLoading(true);
    try {
      const res = await getCategoriesApi();
      const list = Array.isArray(res?.data) ? res.data : Array.isArray(res) ? res : [];
      setCategories(list);
    } catch (err) {
      console.error('Lỗi khi tải danh mục:', err);
      showToast.error('Không thể tải danh sách danh mục');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (isOpen) {
      fetchCategories();
      resetForm();
    }
  }, [isOpen]);

  const resetForm = () => {
    setEditingCategory(null);
    setName('');
    setIconPath('');
    setParentId('');
    setDefaultShelfLifeDays('');
  };

  const handleEditClick = (cat) => {
    setEditingCategory(cat);
    setName(cat.name || '');
    setIconPath(cat.iconPath || '');
    setParentId(cat.parentId ? String(cat.parentId) : '');
    setDefaultShelfLifeDays(cat.defaultShelfLifeDays ? String(cat.defaultShelfLifeDays) : '');
  };

  const handleDeleteClick = async (cat) => {
    if (window.confirm(`Bạn có chắc chắn muốn xóa danh mục "${cat.name}"?`)) {
      try {
        await deleteCategoryApi(cat.id);
        showToast.success('Xóa danh mục thành công!');
        fetchCategories();
        if (onSuccess) onSuccess();
      } catch (err) {
        console.error('Lỗi xóa danh mục:', err);
        showToast.error(err.response?.data?.message || err.message || 'Không thể xóa danh mục (có thể do có chứa nguyên liệu con)');
      }
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!name.trim()) {
      showToast.error('Vui lòng nhập tên danh mục');
      return;
    }

    setSaving(true);
    try {
      const payload = {
        name: name.trim(),
        iconPath: iconPath.trim() || undefined,
        parentId: parentId ? Number(parentId) : undefined,
        defaultShelfLifeDays: defaultShelfLifeDays ? Number(defaultShelfLifeDays) : undefined,
      };

      if (editingCategory) {
        await updateCategoryApi(editingCategory.id, payload);
        showToast.success('Cập nhật danh mục thành công!');
      } else {
        await createCategoryApi(payload);
        showToast.success('Tạo danh mục mới thành công!');
      }

      resetForm();
      fetchCategories();
      if (onSuccess) onSuccess();
    } catch (err) {
      console.error('Lỗi lưu danh mục:', err);
      showToast.error(err.response?.data?.message || err.message || 'Lưu danh mục thất bại');
    } finally {
      setSaving(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-emerald-950/40 backdrop-blur-xs z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-[32px] max-w-2xl w-full max-h-[90vh] overflow-y-auto p-6 sm:p-8 space-y-6 shadow-2xl border border-emerald-100 animate__animated animate__zoomIn animate__faster">
        {/* Header */}
        <div className="flex items-center justify-between border-b border-slate-100 pb-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-emerald-100 text-emerald-700 flex items-center justify-center">
              <FolderPlus className="w-5 h-5" />
            </div>
            <div>
              <h4 className="text-lg font-black text-slate-900">Quản Lý Danh Mục Nguyên Liệu</h4>
              <p className="text-xs text-slate-500 font-semibold">Tạo, sửa và quản lý các nhóm phân loại thực phẩm</p>
            </div>
          </div>
          <button onClick={onClose} className="p-2 rounded-xl text-slate-400 hover:bg-slate-100 transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Add/Edit Form */}
        <form onSubmit={handleSubmit} className="p-4 rounded-2xl bg-slate-50 border border-slate-200 space-y-4">
          <div className="flex items-center justify-between">
            <span className="text-xs font-black uppercase text-emerald-800 tracking-wider">
              {editingCategory ? `Sửa Danh Mục: ${editingCategory.name}` : 'Thêm Danh Mục Mới'}
            </span>
            {editingCategory && (
              <button
                type="button"
                onClick={resetForm}
                className="text-xs text-rose-600 hover:underline font-bold"
              >
                Hủy sửa
              </button>
            )}
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Tên danh mục *</label>
              <input
                type="text"
                required
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Ví dụ: Rau Củ Tươi, Thịt Đỏ..."
                className="w-full px-3 py-2 rounded-xl bg-white border border-slate-200 text-xs font-semibold outline-hidden focus:border-emerald-500"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Danh mục cha (nếu có)</label>
              <select
                value={parentId}
                onChange={(e) => setParentId(e.target.value)}
                className="w-full px-3 py-2 rounded-xl bg-white border border-slate-200 text-xs font-semibold text-slate-700"
              >
                <option value="">-- Danh mục gốc (Không có cha) --</option>
                {categories
                  .filter((cat) => !editingCategory || cat.id !== editingCategory.id)
                  .map((cat) => (
                    <option key={cat.id} value={cat.id}>
                      {cat.name}
                    </option>
                  ))}
              </select>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Thời hạn bảo quản mặc định (ngày)</label>
              <input
                type="number"
                min={1}
                value={defaultShelfLifeDays}
                onChange={(e) => setDefaultShelfLifeDays(e.target.value)}
                placeholder="Ví dụ: 7"
                className="w-full px-3 py-2 rounded-xl bg-white border border-slate-200 text-xs font-semibold outline-hidden focus:border-emerald-500"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Icon Path (tùy chọn)</label>
              <input
                type="text"
                value={iconPath}
                onChange={(e) => setIconPath(e.target.value)}
                placeholder="URL icon..."
                className="w-full px-3 py-2 rounded-xl bg-white border border-slate-200 text-xs font-semibold outline-hidden focus:border-emerald-500"
              />
            </div>
          </div>

          <div className="flex justify-end">
            <button
              type="submit"
              disabled={saving}
              className="px-5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-extrabold text-xs transition-all flex items-center gap-1.5 cursor-pointer shadow-2xs"
            >
              {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
              <span>{editingCategory ? 'Cập Nhật' : 'Tạo Danh Mục'}</span>
            </button>
          </div>
        </form>

        {/* Existing Categories Table */}
        <div className="space-y-3">
          <h5 className="text-xs font-black uppercase text-slate-400 tracking-wider">Danh Sách Danh Mục Hiện Có</h5>
          {loading ? (
            <div className="py-8 text-center">
              <Loader2 className="w-6 h-6 text-emerald-600 animate-spin mx-auto" />
            </div>
          ) : categories.length === 0 ? (
            <p className="text-xs text-slate-400 text-center py-4">Chưa có danh mục nào.</p>
          ) : (
            <div className="divide-y divide-slate-100 max-h-60 overflow-y-auto rounded-2xl border border-slate-200 bg-white">
              {categories.map((cat) => (
                <div key={cat.id} className="p-3 flex items-center justify-between text-xs font-semibold hover:bg-slate-50">
                  <div>
                    <span className="font-extrabold text-slate-900">{cat.name}</span>
                    <span className="text-[11px] text-slate-400 ml-2">(Hạn bảo quản: {cat.defaultShelfLifeDays || 'Mặc định'} ngày)</span>
                  </div>
                  <div className="flex items-center gap-1">
                    <button
                      onClick={() => handleEditClick(cat)}
                      className="p-1.5 rounded-lg bg-blue-50 text-blue-700 hover:bg-blue-100 cursor-pointer"
                      title="Sửa"
                    >
                      <Edit2 className="w-3.5 h-3.5" />
                    </button>
                    <button
                      onClick={() => handleDeleteClick(cat)}
                      className="p-1.5 rounded-lg bg-rose-50 text-rose-600 hover:bg-rose-100 cursor-pointer"
                      title="Xóa"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="pt-2 border-t border-slate-100 flex justify-end">
          <button
            onClick={onClose}
            className="px-5 py-2.5 rounded-2xl bg-slate-900 text-white font-extrabold text-xs hover:bg-slate-800 transition-all cursor-pointer"
          >
            Đóng
          </button>
        </div>
      </div>
    </div>
  );
};

export default CategoryManagementModal;
