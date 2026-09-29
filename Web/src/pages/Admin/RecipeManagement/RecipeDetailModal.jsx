import React, { useEffect, useState } from 'react';
import {
  BookOpen,
  Clock,
  Users,
  Flame,
  DollarSign,
  ChefHat,
  X,
  Loader2,
  CheckCircle2,
  ListOrdered,
  Utensils,
  Tag,
} from 'lucide-react';
import { getRecipeDetailApi } from '../../../services/recipeService';
import { showToast } from '../../../components/common/Toast';

export const RecipeDetailModal = ({ isOpen, onClose, recipeId }) => {
  const [recipe, setRecipe] = useState(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (isOpen && recipeId) {
      const fetchDetail = async () => {
        setLoading(true);
        try {
          const res = await getRecipeDetailApi(recipeId);
          const data = res?.data || res;
          setRecipe(data);
        } catch (err) {
          console.error('Lỗi khi tải chi tiết công thức:', err);
          showToast.error('Không thể tải chi tiết công thức nấu ăn');
        } finally {
          setLoading(false);
        }
      };
      fetchDetail();
    } else {
      setRecipe(null);
    }
  }, [isOpen, recipeId]);

  if (!isOpen) return null;

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
    <div className="fixed inset-0 bg-emerald-950/40 backdrop-blur-xs z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-[32px] max-w-2xl w-full max-h-[90vh] overflow-y-auto p-6 sm:p-8 space-y-6 shadow-2xl border border-emerald-100 animate__animated animate__zoomIn animate__faster">
        {/* Modal Header */}
        <div className="flex items-center justify-between border-b border-slate-100 pb-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-emerald-100 text-emerald-700 flex items-center justify-center">
              <ChefHat className="w-5 h-5" />
            </div>
            <div>
              <h4 className="text-lg font-black text-slate-900">Chi Tiết Công Thức Nấu Ăn</h4>
              <p className="text-xs text-slate-500 font-semibold">Mã #{recipeId}</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 rounded-xl text-slate-400 hover:bg-slate-100 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {loading ? (
          <div className="py-20 text-center space-y-3">
            <Loader2 className="w-8 h-8 text-emerald-600 animate-spin mx-auto" />
            <p className="text-xs font-bold text-slate-500">Đang tải thông tin công thức...</p>
          </div>
        ) : recipe ? (
          <div className="space-y-6">
            {/* Title & Banner Info */}
            <div className="p-5 rounded-2xl bg-emerald-50/60 border border-emerald-100 space-y-3">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <h3 className="text-xl font-black text-slate-900">{recipe.title}</h3>
                  {recipe.description && (
                    <p className="text-xs font-medium text-slate-600 mt-1">{recipe.description}</p>
                  )}
                </div>
                <span className="px-3 py-1 rounded-full bg-emerald-600 text-white text-xs font-extrabold shrink-0">
                  {translateMealType(recipe.mealType)}
                </span>
              </div>

              {/* Stats badges */}
              <div className="flex flex-wrap items-center gap-3 text-xs font-bold pt-2 border-t border-emerald-100 text-slate-700">
                <span className="flex items-center gap-1 bg-white px-3 py-1 rounded-xl border border-emerald-200">
                  <Clock className="w-3.5 h-3.5 text-emerald-600" />
                  {recipe.cookTimeMinutes} phút
                </span>
                <span className="flex items-center gap-1 bg-white px-3 py-1 rounded-xl border border-emerald-200">
                  <Users className="w-3.5 h-3.5 text-blue-600" />
                  {recipe.servings} phần
                </span>
                <span className="flex items-center gap-1 bg-white px-3 py-1 rounded-xl border border-emerald-200">
                  <ChefHat className="w-3.5 h-3.5 text-purple-600" />
                  Độ khó: {translateDifficulty(recipe.difficultyLevel)}
                </span>
                {recipe.estimatedCost && (
                  <span className="flex items-center gap-1 bg-white px-3 py-1 rounded-xl border border-emerald-200 text-emerald-700">
                    <DollarSign className="w-3.5 h-3.5 text-emerald-600" />
                    ~{formatCurrency(recipe.estimatedCost)}
                  </span>
                )}
              </div>
            </div>

            {/* Ingredients List */}
            <div className="space-y-3">
              <h4 className="text-sm font-black text-slate-900 flex items-center gap-2">
                <Utensils className="w-4 h-4 text-emerald-600" />
                <span>Danh Sách Nguyên Liệu ({recipe.ingredients?.length || 0})</span>
              </h4>
              {recipe.ingredients && recipe.ingredients.length > 0 ? (
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                  {recipe.ingredients.map((ing, idx) => (
                    <div
                      key={idx}
                      className="p-3 rounded-2xl bg-slate-50 border border-slate-200 flex items-center justify-between text-xs font-semibold"
                    >
                      <span className="text-slate-900 font-bold">{ing.name || ing.ingredient?.name || `Nguyên liệu #${ing.ingredientId}`}</span>
                      <span className="px-2.5 py-1 rounded-xl bg-white text-emerald-700 font-extrabold border border-emerald-200">
                        {ing.quantity} {ing.unit}
                      </span>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-xs text-slate-400 font-medium">Chưa có thông tin nguyên liệu.</p>
              )}
            </div>

            {/* Cooking Steps */}
            <div className="space-y-3">
              <h4 className="text-sm font-black text-slate-900 flex items-center gap-2">
                <ListOrdered className="w-4 h-4 text-emerald-600" />
                <span>Các Bước Thực Hiện</span>
              </h4>
              {recipe.steps && recipe.steps.length > 0 ? (
                <div className="space-y-2.5">
                  {recipe.steps.map((step, idx) => (
                    <div
                      key={idx}
                      className="p-4 rounded-2xl bg-slate-50 border border-slate-200 flex items-start gap-3 text-xs font-semibold"
                    >
                      <span className="w-6 h-6 rounded-full bg-emerald-600 text-white font-black flex items-center justify-center shrink-0 text-[11px]">
                        {step.stepNumber || idx + 1}
                      </span>
                      <div className="space-y-1">
                        <p className="text-slate-800 leading-relaxed font-bold">{step.instruction}</p>
                        {step.durationMinutes && (
                          <span className="text-[11px] text-emerald-600 font-bold flex items-center gap-1">
                            <Clock className="w-3 h-3" /> {step.durationMinutes} phút
                          </span>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-xs text-slate-400 font-medium">Chưa có hướng dẫn các bước nấu.</p>
              )}
            </div>
          </div>
        ) : (
          <p className="text-xs text-center text-slate-400">Không tìm thấy thông tin công thức này.</p>
        )}

        <div className="pt-2 border-t border-slate-100">
          <button
            onClick={onClose}
            className="w-full py-3 rounded-2xl bg-slate-900 text-white font-extrabold text-sm hover:bg-slate-800 transition-all cursor-pointer"
          >
            Đóng
          </button>
        </div>
      </div>
    </div>
  );
};

export default RecipeDetailModal;
