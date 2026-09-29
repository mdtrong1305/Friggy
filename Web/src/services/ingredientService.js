import axiosClient from '../utils/axios';

/**
 * Lấy cây danh mục nguyên liệu (có children)
 * GET /api/v1/ingredients/categories
 */
export const getCategoriesApi = async () => {
  return await axiosClient.get('/ingredients/categories');
};

/**
 * Danh sách nguyên liệu (pagination + search + categoryId + isCommon)
 * GET /api/v1/ingredients
 * Params: { page, limit, search, categoryId, isCommon }
 */
export const getIngredientsApi = async (params = {}) => {
  return await axiosClient.get('/ingredients', { params });
};

/**
 * Chi tiết nguyên liệu
 * GET /api/v1/ingredients/:id
 */
export const getIngredientDetailApi = async (id) => {
  return await axiosClient.get(`/ingredients/${id}`);
};

/**
 * Link mua nguyên liệu trên TMĐT (Shopee, Lazada...)
 * GET /api/v1/ingredients/:id/purchase-links
 */
export const getIngredientPurchaseLinksApi = async (id) => {
  return await axiosClient.get(`/ingredients/${id}/purchase-links`);
};

/**
 * Tạo danh mục nguyên liệu mới (Admin only)
 * POST /api/v1/ingredients/categories
 * Body: { name, iconPath?, parentId?, defaultShelfLifeDays? }
 */
export const createCategoryApi = async (data) => {
  return await axiosClient.post('/ingredients/categories', data);
};

/**
 * Cập nhật danh mục nguyên liệu (Admin only)
 * PATCH /api/v1/ingredients/categories/:id
 * Body: { name?, iconPath?, parentId?, defaultShelfLifeDays? }
 */
export const updateCategoryApi = async (id, data) => {
  return await axiosClient.patch(`/ingredients/categories/${id}`, data);
};

/**
 * Xóa danh mục nguyên liệu (Admin only)
 * DELETE /api/v1/ingredients/categories/:id
 */
export const deleteCategoryApi = async (id) => {
  return await axiosClient.delete(`/ingredients/categories/${id}`);
};

/**
 * Tạo nguyên liệu mới (Admin only)
 * POST /api/v1/ingredients
 * Body: { name, categoryId, defaultUnit, caloriesPer100g, averagePricePerUnit, isCommon }
 */
export const createIngredientApi = async (data) => {
  return await axiosClient.post('/ingredients', data);
};

/**
 * Cập nhật nguyên liệu (Admin only)
 * PATCH /api/v1/ingredients/:id
 * Body: { name, categoryId, defaultUnit, caloriesPer100g, averagePricePerUnit, isCommon }
 */
export const updateIngredientApi = async (id, data) => {
  return await axiosClient.patch(`/ingredients/${id}`, data);
};

/**
 * Xóa nguyên liệu (Soft delete - Admin only)
 * DELETE /api/v1/ingredients/:id
 */
export const deleteIngredientApi = async (id) => {
  return await axiosClient.delete(`/ingredients/${id}`);
};

