import React, { useState, useEffect, useRef } from 'react';
import { X, Sparkles, Check, Loader2, Utensils, Flame, DollarSign, Image, Upload, Trash2 } from 'lucide-react';
import { createIngredientApi, updateIngredientApi } from '../../../services/ingredientService';
import { showToast } from '../../../components/common/Toast';

export const AddEditIngredientModal = ({
  isOpen,
  onClose,
  onSuccess,
  ingredient = null,
  categories = [],
}) => {
  const isEditing = Boolean(ingredient);
  const fileInputRef = useRef(null);

  const [formData, setFormData] = useState({
    name: '',
    categoryId: '',
    defaultUnit: 'gram',
    caloriesPer100g: '',
    averagePricePerUnit: '',
    imagePath: '',
    isCommon: false,
  });

  const [submitting, setSubmitting] = useState(false);
  const [imgError, setImgError] = useState(false);

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

  useEffect(() => {
    setImgError(false);
    if (ingredient) {
      setFormData({
        name: ingredient.name || '',
        categoryId: ingredient.categoryId || (categoryOptions[0]?.id ?? ''),
        defaultUnit: ingredient.defaultUnit || 'gram',
        caloriesPer100g: ingredient.caloriesPer100g ?? '',
        averagePricePerUnit: ingredient.averagePricePerUnit ?? '',
        imagePath: ingredient.imagePath || '',
        isCommon: Boolean(ingredient.isCommon),
      });
    } else {
      setFormData({
        name: '',
        categoryId: categoryOptions[0]?.id || '',
        defaultUnit: 'gram',
        caloriesPer100g: '',
        averagePricePerUnit: '',
        imagePath: '',
        isCommon: false,
      });
    }
  }, [ingredient, isOpen, categories]);

  const handleChange = (e) => {
    const { name, value, type, checked } = e.target;
    if (name === 'imagePath') setImgError(false);
    setFormData((prev) => ({
      ...prev,
      [name]: type === 'checkbox' ? checked : value,
    }));
  };

  const handleFileChange = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (!file.type.startsWith('image/')) {
      showToast.error('Vui lòng chọn file hình ảnh (PNG, JPG, WEBP...)');
      return;
    }

    const reader = new FileReader();
    reader.onload = (event) => {
      setImgError(false);
      setFormData((prev) => ({
        ...prev,
        imagePath: event.target?.result || '',
      }));
      showToast.success('Tải ảnh từ máy lên thành công!');
    };
    reader.readAsDataURL(file);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!formData.name.trim()) {
      showToast.error('Vui lòng nhập tên nguyên liệu!');
      return;
    }
    if (!formData.categoryId) {
      showToast.error('Vui lòng chọn danh mục nguyên liệu!');
      return;
    }

    setSubmitting(true);
    try {
      const payload = {
        name: formData.name.trim(),
        categoryId: Number(formData.categoryId),
        defaultUnit: formData.defaultUnit.trim() || 'gram',
        caloriesPer100g: formData.caloriesPer100g !== '' ? Number(formData.caloriesPer100g) : undefined,
        averagePricePerUnit: formData.averagePricePerUnit !== '' ? Number(formData.averagePricePerUnit) : undefined,
        imagePath: formData.imagePath.trim() || undefined,
        isCommon: Boolean(formData.isCommon),
      };

      if (isEditing) {
        await updateIngredientApi(ingredient.id, payload);
        showToast.success('Cập nhật nguyên liệu thành công!');
      } else {
        await createIngredientApi(payload);
        showToast.success('Thêm nguyên liệu mới thành công!');
      }

      onSuccess();
      onClose();
    } catch (err) {
      console.error('Lỗi khi lưu nguyên liệu:', err);
      showToast.error(err.message || 'Không thể lưu thông tin nguyên liệu');
    } finally {
      setSubmitting(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-emerald-950/40 backdrop-blur-xs animate__animated animate__fadeIn animate__faster">
      <div
        className="bg-white rounded-[32px] border border-emerald-100 shadow-2xl w-full max-w-lg overflow-hidden flex flex-col max-h-[90vh] animate__animated animate__zoomIn animate__faster"
      >
          {/* Header */}
          <div className="p-6 border-b border-emerald-100 flex items-center justify-between bg-gradient-to-r from-emerald-50 via-teal-50 to-emerald-100/50">
            <div className="flex items-center gap-3">
              <div className="w-11 h-11 rounded-2xl bg-emerald-600 text-white flex items-center justify-center shadow-md">
                <Utensils className="w-5.5 h-5.5" />
              </div>
              <div>
                <h3 className="font-black text-slate-900 text-lg flex items-center gap-1.5">
                  <span>{isEditing ? 'Chỉnh Sửa Nguyên Liệu' : 'Thêm Nguyên Liệu Mới'}</span>
                  <Sparkles className="w-4 h-4 text-emerald-600" />
                </h3>
                <p className="text-xs text-emerald-800 font-bold">
                  {isEditing ? `Mã ID: #${ingredient.id}` : 'Thêm dữ liệu nguyên liệu thực phẩm vào hệ thống'}
                </p>
              </div>
            </div>

            <button
              onClick={onClose}
              className="p-2 rounded-xl text-slate-400 hover:text-slate-600 hover:bg-white/80 transition-colors cursor-pointer"
            >
              <X className="w-5 h-5" />
            </button>
          </div>

          {/* Form Body */}
          <form onSubmit={handleSubmit} className="p-6 space-y-4 overflow-y-auto flex-1">
            {/* Tên nguyên liệu */}
            <div className="space-y-1">
              <label className="text-xs font-bold text-slate-700 flex items-center justify-between">
                <span>Tên nguyên liệu <span className="text-rose-500">*</span></span>
              </label>
              <input
                type="text"
                name="name"
                value={formData.name}
                onChange={handleChange}
                placeholder="VD: Thịt bò Úc, Cà chua, Tỏi tây..."
                className="w-full px-4 py-2.5 rounded-2xl bg-slate-50 focus:bg-white border border-slate-200 focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20 text-xs sm:text-sm font-semibold outline-hidden transition-all"
                required
              />
            </div>

            {/* Danh mục & Đơn vị mặc định */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="space-y-1">
                <label className="text-xs font-bold text-slate-700">
                  Danh mục <span className="text-rose-500">*</span>
                </label>
                <select
                  name="categoryId"
                  value={formData.categoryId}
                  onChange={handleChange}
                  className="w-full px-4 py-2.5 rounded-2xl bg-slate-50 focus:bg-white border border-slate-200 focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20 text-xs sm:text-sm font-semibold outline-hidden transition-all cursor-pointer"
                  required
                >
                  <option value="" disabled>-- Chọn danh mục --</option>
                  {categoryOptions.map((cat) => (
                    <option key={cat.id} value={cat.id}>
                      {cat.name}
                    </option>
                  ))}
                </select>
              </div>

              <div className="space-y-1">
                <label className="text-xs font-bold text-slate-700">
                  Đơn vị mặc định <span className="text-rose-500">*</span>
                </label>
                <input
                  type="text"
                  name="defaultUnit"
                  value={formData.defaultUnit}
                  onChange={handleChange}
                  placeholder="gram, kg, quả, củ, ml..."
                  className="w-full px-4 py-2.5 rounded-2xl bg-slate-50 focus:bg-white border border-slate-200 focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20 text-xs sm:text-sm font-semibold outline-hidden transition-all"
                  required
                />
              </div>
            </div>

            {/* Calo & Giá trung bình */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="space-y-1">
                <label className="text-xs font-bold text-slate-700 flex items-center gap-1">
                  <Flame className="w-3.5 h-3.5 text-amber-500" />
                  <span>Lượng Calo / 100g (kcal)</span>
                </label>
                <input
                  type="number"
                  name="caloriesPer100g"
                  value={formData.caloriesPer100g}
                  onChange={handleChange}
                  placeholder="VD: 250"
                  min="0"
                  step="0.1"
                  className="w-full px-4 py-2.5 rounded-2xl bg-slate-50 focus:bg-white border border-slate-200 focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20 text-xs sm:text-sm font-semibold outline-hidden transition-all"
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-bold text-slate-700 flex items-center gap-1">
                  <DollarSign className="w-3.5 h-3.5 text-green-600" />
                  <span>Giá trung bình (VND / đơn vị)</span>
                </label>
                <input
                  type="number"
                  name="averagePricePerUnit"
                  value={formData.averagePricePerUnit}
                  onChange={handleChange}
                  placeholder="VD: 150000"
                  min="0"
                  step="500"
                  className="w-full px-4 py-2.5 rounded-2xl bg-slate-50 focus:bg-white border border-slate-200 focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20 text-xs sm:text-sm font-semibold outline-hidden transition-all"
                />
              </div>
            </div>

            {/* Đường dẫn & Tải hình ảnh */}
            <div className="space-y-2">
              <label className="text-xs font-bold text-slate-700 flex items-center justify-between">
                <span className="flex items-center gap-1">
                  <Image className="w-3.5 h-3.5 text-blue-600" />
                  <span>Hình ảnh nguyên liệu (imagePath)</span>
                </span>
                <span className="text-[11px] text-slate-400 font-normal">URL hoặc File từ máy</span>
              </label>

              <input
                type="file"
                ref={fileInputRef}
                onChange={handleFileChange}
                accept="image/*"
                className="hidden"
              />

              <div className="flex items-center gap-3">
                <input
                  type="text"
                  name="imagePath"
                  value={formData.imagePath}
                  onChange={handleChange}
                  placeholder="Dán URL ảnh hoặc chọn file từ máy..."
                  className="flex-1 px-4 py-2.5 rounded-2xl bg-slate-50 focus:bg-white border border-slate-200 focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20 text-xs sm:text-sm font-semibold outline-hidden transition-all"
                />

                <button
                  type="button"
                  onClick={() => fileInputRef.current?.click()}
                  className="px-3.5 py-2.5 rounded-2xl bg-emerald-50 hover:bg-emerald-100 text-emerald-700 border border-emerald-200 font-extrabold text-xs transition-all flex items-center gap-1.5 shrink-0 cursor-pointer"
                  title="Chọn ảnh từ máy tính"
                >
                  <Upload className="w-3.5 h-3.5" />
                  <span>Tải ảnh từ máy</span>
                </button>

                <div className="w-10 h-10 rounded-2xl bg-slate-100 border border-slate-200 flex items-center justify-center overflow-hidden shrink-0">
                  {formData.imagePath && !imgError ? (
                    <img
                      src={formData.imagePath}
                      alt="Preview"
                      className="w-full h-full object-cover"
                      onError={() => setImgError(true)}
                    />
                  ) : (
                    <Image className="w-4 h-4 text-slate-400" />
                  )}
                </div>
              </div>
            </div>

            {/* Checkbox Phổ Biến */}
            <div className="pt-1">
              <label className="flex items-center gap-3 p-3.5 rounded-2xl bg-emerald-50/50 border border-emerald-100/90 cursor-pointer select-none">
                <input
                  type="checkbox"
                  name="isCommon"
                  checked={formData.isCommon}
                  onChange={handleChange}
                  className="w-4 h-4 text-emerald-600 rounded-md focus:ring-emerald-500 border-slate-300 cursor-pointer"
                />
                <div>
                  <span className="text-xs font-extrabold text-emerald-950 block">
                    Đánh dấu Nguyên Liệu Phổ Biến
                  </span>
                  <span className="text-[11px] text-slate-500 font-medium block">
                    Hiển thị ưu tiên trong các đề xuất AI và danh sách tìm kiếm nhanh
                  </span>
                </div>
              </label>
            </div>

            {/* Modal Buttons */}
            <div className="pt-4 flex items-center justify-end gap-3 border-t border-slate-100">
              <button
                type="button"
                onClick={onClose}
                disabled={submitting}
                className="px-5 py-2.5 rounded-2xl bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs transition-colors cursor-pointer"
              >
                Hủy
              </button>
              <button
                type="submit"
                disabled={submitting}
                className="px-6 py-2.5 rounded-2xl bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-700 hover:to-teal-700 text-white font-bold text-xs shadow-md shadow-emerald-600/20 transition-all cursor-pointer flex items-center gap-2"
              >
                {submitting ? (
                  <>
                    <Loader2 className="w-4 h-4 animate-spin" />
                    <span>Đang lưu...</span>
                  </>
                ) : (
                  <>
                    <Check className="w-4 h-4 stroke-[3]" />
                    <span>{isEditing ? 'Cập Nhật' : 'Tạo Mới'}</span>
                  </>
                )}
              </button>
            </div>
          </form>
        </div>
      </div>
    );
};

export default AddEditIngredientModal;
