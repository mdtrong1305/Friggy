import React, { useState, useEffect } from 'react';
import {
  X,
  Plus,
  Trash2,
  ChefHat,
  Loader2,
  Utensils,
  Clock,
  Users,
  DollarSign,
  ListOrdered,
} from 'lucide-react';
import { createRecipeApi, updateRecipeApi } from '../../../services/recipeService';
import { getIngredientsApi } from '../../../services/ingredientService';
import { showToast } from '../../../components/common/Toast';

export const AddEditRecipeModal = ({
  isOpen,
  onClose,
  onSuccess,
  recipe = null,
}) => {
  const isEditing = Boolean(recipe);

  // Form fields
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [mealType, setMealType] = useState('lunch');
  const [cookTimeMinutes, setCookTimeMinutes] = useState(30);
  const [servings, setServings] = useState(2);
  const [difficultyLevel, setDifficultyLevel] = useState('medium');
  const [estimatedCost, setEstimatedCost] = useState('');

  // Dynamic Lists
  const [ingredientsList, setIngredientsList] = useState([]);
  const [stepsList, setStepsList] = useState([]);

  // Master ingredients dropdown list
  const [masterIngredients, setMasterIngredients] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (isOpen) {
      // Fetch ingredients for dropdown selector
      getIngredientsApi({ limit: 100 })
        .then((res) => {
          const list = res?.data?.data || res?.data || res || [];
          setMasterIngredients(Array.isArray(list) ? list : []);
        })
        .catch((err) => console.error('Lỗi khi tải danh sách nguyên liệu:', err));

      if (recipe) {
        setTitle(recipe.title || '');
        setDescription(recipe.description || '');
        setMealType(recipe.mealType || 'lunch');
        setCookTimeMinutes(recipe.cookTimeMinutes || 30);
        setServings(recipe.servings || 2);
        setDifficultyLevel(recipe.difficultyLevel || 'medium');
        setEstimatedCost(recipe.estimatedCost || '');

        // Pre-fill ingredients & steps if editing
        setIngredientsList(
          recipe.ingredients && recipe.ingredients.length > 0
            ? recipe.ingredients.map((ing) => ({
                ingredientId: ing.ingredientId,
                quantity: ing.quantity || 1,
                unit: ing.unit || ing.ingredient?.defaultUnit || 'g',
              }))
            : []
        );

        setStepsList(
          recipe.steps && recipe.steps.length > 0
            ? recipe.steps.map((st, idx) => ({
                stepNumber: st.stepNumber || idx + 1,
                instruction: st.instruction || '',
                durationMinutes: st.durationMinutes || 5,
              }))
            : []
        );
      } else {
        // Reset form
        setTitle('');
        setDescription('');
        setMealType('lunch');
        setCookTimeMinutes(30);
        setServings(2);
        setDifficultyLevel('medium');
        setEstimatedCost('');
        setIngredientsList([]);
        setStepsList([{ stepNumber: 1, instruction: '', durationMinutes: 5 }]);
      }
    }
  }, [isOpen, recipe]);

  if (!isOpen) return null;

  // Add / Remove ingredient row
  const handleAddIngredientRow = () => {
    if (masterIngredients.length === 0) {
      showToast.error('Không có sẵn nguyên liệu master nào');
      return;
    }
    const defaultIng = masterIngredients[0];
    setIngredientsList((prev) => [
      ...prev,
      {
        ingredientId: defaultIng.id,
        quantity: 100,
        unit: defaultIng.defaultUnit || 'g',
      },
    ]);
  };

  const handleRemoveIngredientRow = (index) => {
    setIngredientsList((prev) => prev.filter((_, i) => i !== index));
  };

  const handleIngredientChange = (index, field, value) => {
    setIngredientsList((prev) => {
      const updated = [...prev];
      updated[index] = { ...updated[index], [field]: value };
      if (field === 'ingredientId') {
        const found = masterIngredients.find((m) => m.id === Number(value));
        if (found) {
          updated[index].unit = found.defaultUnit || 'g';
        }
      }
      return updated;
    });
  };

  // Add / Remove step row
  const handleAddStepRow = () => {
    setStepsList((prev) => [
      ...prev,
      {
        stepNumber: prev.length + 1,
        instruction: '',
        durationMinutes: 5,
      },
    ]);
  };

  const handleRemoveStepRow = (index) => {
    setStepsList((prev) => {
      const filtered = prev.filter((_, i) => i !== index);
      return filtered.map((item, idx) => ({ ...item, stepNumber: idx + 1 }));
    });
  };

  const handleStepChange = (index, field, value) => {
    setStepsList((prev) => {
      const updated = [...prev];
      updated[index] = { ...updated[index], [field]: value };
      return updated;
    });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!title.trim()) {
      showToast.error('Vui lòng nhập tên công thức nấu ăn');
      return;
    }

    setLoading(true);
    try {
      const payload = {
        title: title.trim(),
        description: description.trim() || undefined,
        mealType,
        cookTimeMinutes: Number(cookTimeMinutes),
        servings: Number(servings),
        difficultyLevel,
        estimatedCost: estimatedCost ? Number(estimatedCost) : undefined,
      };

      if (!isEditing) {
        payload.ingredients = ingredientsList.map((ing) => ({
          ingredientId: Number(ing.ingredientId),
          quantity: Number(ing.quantity),
          unit: ing.unit || 'g',
        }));
        payload.steps = stepsList
          .filter((st) => st.instruction.trim() !== '')
          .map((st, idx) => ({
            stepNumber: idx + 1,
            instruction: st.instruction.trim(),
            durationMinutes: Number(st.durationMinutes || 5),
          }));
      }

      if (isEditing) {
        await updateRecipeApi(recipe.id, payload);
        showToast.success('Cập nhật công thức thành công!');
      } else {
        await createRecipeApi(payload);
        showToast.success('Tạo mới công thức nấu ăn thành công!');
      }

      onSuccess();
      onClose();
    } catch (err) {
      console.error('Lỗi lưu công thức:', err);
      showToast.error(err.message || 'Lưu công thức nấu ăn thất bại');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-emerald-950/40 backdrop-blur-xs z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-[32px] max-w-3xl w-full max-h-[90vh] overflow-y-auto p-6 sm:p-8 space-y-6 shadow-2xl border border-emerald-100 animate__animated animate__zoomIn animate__faster">
        {/* Modal Header */}
        <div className="flex items-center justify-between border-b border-slate-100 pb-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-gradient-to-tr from-emerald-500 to-teal-500 text-white flex items-center justify-center shadow-md">
              <ChefHat className="w-5 h-5" />
            </div>
            <div>
              <h4 className="text-lg font-black text-slate-900">
                {isEditing ? 'Chỉnh Sửa Công Thức' : 'Tạo Công Thức Mới'}
              </h4>
              <p className="text-xs text-slate-500 font-semibold">
                {isEditing ? `Mã công thức: #${recipe.id}` : 'Nhập đầy đủ thông tin để lưu công thức món ăn'}
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 rounded-xl text-slate-400 hover:bg-slate-100 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Form Body */}
        <form onSubmit={handleSubmit} className="space-y-6">
          {/* Main Info */}
          <div className="space-y-4">
            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1.5">Tên món ăn / công thức *</label>
              <input
                type="text"
                required
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="Ví dụ: Bún Bò Huế Đặc Biệt, Thịt Kho Tàu..."
                className="w-full px-4 py-2.5 rounded-2xl bg-slate-50 border border-slate-200 text-xs sm:text-sm font-semibold outline-hidden focus:border-emerald-500 focus:bg-white transition-all"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1.5">Mô tả ngắn</label>
              <textarea
                rows={2}
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="Mô tả hương vị, nguồn gốc món ăn..."
                className="w-full px-4 py-2.5 rounded-2xl bg-slate-50 border border-slate-200 text-xs sm:text-sm font-semibold outline-hidden focus:border-emerald-500 focus:bg-white transition-all"
              />
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1.5">Loại bữa ăn *</label>
                <select
                  value={mealType}
                  onChange={(e) => setMealType(e.target.value)}
                  className="w-full px-4 py-2.5 rounded-2xl bg-slate-50 border border-slate-200 text-xs sm:text-sm font-semibold text-slate-800 outline-hidden focus:border-emerald-500 transition-all cursor-pointer"
                >
                  <option value="breakfast">Bữa Sáng (breakfast)</option>
                  <option value="lunch">Bữa Trưa (lunch)</option>
                  <option value="dinner">Bữa Tối (dinner)</option>
                  <option value="snack">Ăn Vặt (snack)</option>
                  <option value="dessert">Tráng Miệng (dessert)</option>
                  <option value="drink">Thức Uống (drink)</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1.5">Độ khó *</label>
                <select
                  value={difficultyLevel}
                  onChange={(e) => setDifficultyLevel(e.target.value)}
                  className="w-full px-4 py-2.5 rounded-2xl bg-slate-50 border border-slate-200 text-xs sm:text-sm font-semibold text-slate-800 outline-hidden focus:border-emerald-500 transition-all cursor-pointer"
                >
                  <option value="easy">Dễ (easy)</option>
                  <option value="medium">Trung bình (medium)</option>
                  <option value="hard">Phức tạp (hard)</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1.5">Thời gian nấu (phút) *</label>
                <input
                  type="number"
                  min={1}
                  required
                  value={cookTimeMinutes}
                  onChange={(e) => setCookTimeMinutes(e.target.value)}
                  className="w-full px-4 py-2.5 rounded-2xl bg-slate-50 border border-slate-200 text-xs sm:text-sm font-semibold outline-hidden focus:border-emerald-500 transition-all"
                />
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1.5">Khẩu phần (số người ăn) *</label>
                <input
                  type="number"
                  min={1}
                  required
                  value={servings}
                  onChange={(e) => setServings(e.target.value)}
                  className="w-full px-4 py-2.5 rounded-2xl bg-slate-50 border border-slate-200 text-xs sm:text-sm font-semibold outline-hidden focus:border-emerald-500 transition-all"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1.5">Chi phí ước tính (VND)</label>
                <input
                  type="number"
                  min={0}
                  value={estimatedCost}
                  onChange={(e) => setEstimatedCost(e.target.value)}
                  placeholder="Ví dụ: 50000"
                  className="w-full px-4 py-2.5 rounded-2xl bg-slate-50 border border-slate-200 text-xs sm:text-sm font-semibold outline-hidden focus:border-emerald-500 transition-all"
                />
              </div>
            </div>
          </div>

          {!isEditing && (
            <>
              {/* Dynamic Ingredients Section */}
              <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200 space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-black text-slate-800 uppercase tracking-wider flex items-center gap-1.5">
                    <Utensils className="w-4 h-4 text-emerald-600" />
                    Thành Phần Nguyên Liệu
                  </span>
                  <button
                    type="button"
                    onClick={handleAddIngredientRow}
                    className="px-3 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-extrabold text-xs transition-all flex items-center gap-1 cursor-pointer shadow-2xs"
                  >
                    <Plus className="w-3.5 h-3.5" />
                    Thêm nguyên liệu
                  </button>
                </div>

                {ingredientsList.length === 0 ? (
                  <p className="text-xs text-slate-400 font-medium py-2 text-center">Bấm "Thêm nguyên liệu" để thêm thành phần món ăn.</p>
                ) : (
                  <div className="space-y-2">
                    {ingredientsList.map((ing, idx) => (
                      <div key={idx} className="flex items-center gap-2">
                        <select
                          value={ing.ingredientId}
                          onChange={(e) => handleIngredientChange(idx, 'ingredientId', e.target.value)}
                          className="flex-1 px-3 py-2 rounded-xl bg-white border border-slate-200 text-xs font-semibold"
                        >
                          {masterIngredients.map((m) => (
                            <option key={m.id} value={m.id}>
                              {m.name} ({m.defaultUnit})
                            </option>
                          ))}
                        </select>

                        <input
                          type="number"
                          min={1}
                          value={ing.quantity}
                          onChange={(e) => handleIngredientChange(idx, 'quantity', e.target.value)}
                          placeholder="Số lượng"
                          className="w-24 px-3 py-2 rounded-xl bg-white border border-slate-200 text-xs font-semibold"
                        />

                        <input
                          type="text"
                          value={ing.unit}
                          onChange={(e) => handleIngredientChange(idx, 'unit', e.target.value)}
                          placeholder="Đơn vị"
                          className="w-20 px-3 py-2 rounded-xl bg-white border border-slate-200 text-xs font-semibold"
                        />

                        <button
                          type="button"
                          onClick={() => handleRemoveIngredientRow(idx)}
                          className="p-2 text-rose-600 hover:bg-rose-50 rounded-xl transition-colors cursor-pointer"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* Dynamic Cooking Steps Section */}
              <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200 space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-black text-slate-800 uppercase tracking-wider flex items-center gap-1.5">
                    <ListOrdered className="w-4 h-4 text-emerald-600" />
                    Các Bước Nấu
                  </span>
                  <button
                    type="button"
                    onClick={handleAddStepRow}
                    className="px-3 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-extrabold text-xs transition-all flex items-center gap-1 cursor-pointer shadow-2xs"
                  >
                    <Plus className="w-3.5 h-3.5" />
                    Thêm bước nấu
                  </button>
                </div>

                <div className="space-y-2">
                  {stepsList.map((st, idx) => (
                    <div key={idx} className="flex items-start gap-2">
                      <span className="w-7 h-7 rounded-xl bg-emerald-100 text-emerald-800 font-extrabold flex items-center justify-center shrink-0 text-xs mt-1">
                        #{st.stepNumber}
                      </span>
                      <textarea
                        rows={2}
                        required
                        value={st.instruction}
                        onChange={(e) => handleStepChange(idx, 'instruction', e.target.value)}
                        placeholder={`Mô tả chi tiết bước ${st.stepNumber}...`}
                        className="flex-1 px-3 py-2 rounded-xl bg-white border border-slate-200 text-xs font-semibold outline-hidden focus:border-emerald-500"
                      />
                      <input
                        type="number"
                        min={1}
                        value={st.durationMinutes}
                        onChange={(e) => handleStepChange(idx, 'durationMinutes', e.target.value)}
                        placeholder="Phút"
                        className="w-20 px-3 py-2 rounded-xl bg-white border border-slate-200 text-xs font-semibold"
                      />
                      <button
                        type="button"
                        onClick={() => handleRemoveStepRow(idx)}
                        className="p-2 text-rose-600 hover:bg-rose-50 rounded-xl transition-colors cursor-pointer mt-1"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            </>
          )}

          {/* Submit Action */}
          <div className="flex items-center justify-end gap-3 pt-4 border-t border-slate-100">
            <button
              type="button"
              onClick={onClose}
              className="px-5 py-2.5 rounded-2xl bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs sm:text-sm transition-all cursor-pointer"
            >
              Hủy
            </button>

            <button
              type="submit"
              disabled={loading}
              className="px-6 py-2.5 rounded-2xl bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-700 hover:to-teal-700 text-white font-extrabold text-xs sm:text-sm shadow-md shadow-emerald-600/20 transition-all cursor-pointer flex items-center gap-2"
            >
              {loading && <Loader2 className="w-4 h-4 animate-spin" />}
              <span>{isEditing ? 'Lưu Thay Đổi' : 'Tạo Công Thức'}</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default AddEditRecipeModal;
