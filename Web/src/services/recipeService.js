import axiosClient from '../utils/axios';

/**
 * Danh sách công thức (có phân trang, tìm kiếm, filter theo mealType, difficulty, tagIds, maxCookTime)
 * GET /api/v1/recipes
 */
export const getRecipesApi = async (params = {}) => {
  return await axiosClient.get('/recipes', { params });
};

/**
 * Chi tiết công thức nấu ăn
 * GET /api/v1/recipes/:id
 */
export const getRecipeDetailApi = async (id) => {
  return await axiosClient.get(`/recipes/${id}`);
};

/**
 * Tạo công thức nấu ăn mới (Admin only)
 * POST /api/v1/recipes
 * Body: { title, description, mealType, cookTimeMinutes, servings, difficultyLevel, estimatedCost, ingredients, steps, tagIds }
 */
export const createRecipeApi = async (data) => {
  return await axiosClient.post('/recipes', data);
};

/**
 * Cập nhật thông tin công thức nấu ăn (Admin only)
 * PATCH /api/v1/recipes/:id
 * Body: { title, description, mealType, cookTimeMinutes, servings, difficultyLevel, estimatedCost }
 */
export const updateRecipeApi = async (id, data) => {
  return await axiosClient.patch(`/recipes/${id}`, data);
};

/**
 * Xóa công thức nấu ăn (Soft delete - Admin only)
 * DELETE /api/v1/admin/recipes/:id (hoặc /api/v1/recipes/:id)
 */
export const deleteRecipeApi = async (id) => {
  try {
    return await axiosClient.delete(`/admin/recipes/${id}`);
  } catch (err) {
    if (err.message?.includes('404') || err.response?.status === 404) {
      return await axiosClient.delete(`/recipes/${id}`);
    }
    throw err;
  }
};
