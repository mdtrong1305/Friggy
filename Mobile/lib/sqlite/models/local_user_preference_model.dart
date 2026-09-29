class LocalUserPreferenceModel {
  final int id; // luôn là 1 (singleton)
  final int? weeklyBudget;
  final int? dailyCalorieTarget;
  final String dietaryStyle;
  final int preferSimpleRecipes; // 0 hoặc 1
  final int? maxCookTimeMinutes;
  final String skillLevel;
  final int householdSize;
  final String aiPersonalityMode;
  final String? primaryGoal;
  final String? cookingFrequency;
  final int? height;
  final int? weight;
  final String? activityLevel;
  final int updatedAt;
  final String syncStatus; // 'synced' | 'pending'

  LocalUserPreferenceModel({
    this.id = 1,
    this.weeklyBudget,
    this.dailyCalorieTarget,
    this.dietaryStyle = 'omnivore',
    this.preferSimpleRecipes = 0,
    this.maxCookTimeMinutes,
    this.skillLevel = 'beginner',
    this.householdSize = 1,
    this.aiPersonalityMode = 'friendly',
    this.primaryGoal,
    this.cookingFrequency,
    this.height,
    this.weight,
    this.activityLevel,
    required this.updatedAt,
    this.syncStatus = 'synced',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'weekly_budget': weeklyBudget,
      'daily_calorie_target': dailyCalorieTarget,
      'dietary_style': dietaryStyle,
      'prefer_simple_recipes': preferSimpleRecipes,
      'max_cook_time_minutes': maxCookTimeMinutes,
      'skill_level': skillLevel,
      'household_size': householdSize,
      'ai_personality_mode': aiPersonalityMode,
      'primary_goal': primaryGoal,
      'cooking_frequency': cookingFrequency,
      'height': height,
      'weight': weight,
      'activity_level': activityLevel,
      'updated_at': updatedAt,
      'sync_status': syncStatus,
    };
  }

  factory LocalUserPreferenceModel.fromMap(Map<String, dynamic> map) {
    return LocalUserPreferenceModel(
      id: map['id'] as int? ?? 1,
      weeklyBudget: map['weekly_budget'] as int?,
      dailyCalorieTarget: map['daily_calorie_target'] as int?,
      dietaryStyle: map['dietary_style'] as String? ?? 'omnivore',
      preferSimpleRecipes: map['prefer_simple_recipes'] as int? ?? 0,
      maxCookTimeMinutes: map['max_cook_time_minutes'] as int?,
      skillLevel: map['skill_level'] as String? ?? 'beginner',
      householdSize: map['household_size'] as int? ?? 1,
      aiPersonalityMode: map['ai_personality_mode'] as String? ?? 'friendly',
      primaryGoal: map['primary_goal'] as String?,
      cookingFrequency: map['cooking_frequency'] as String?,
      height: map['height'] as int?,
      weight: map['weight'] as int?,
      activityLevel: map['activity_level'] as String?,
      updatedAt: map['updated_at'] as int,
      syncStatus: map['sync_status'] as String? ?? 'synced',
    );
  }

  /// Chuyển sang dạng Map để gọi API updatePreferences
  Map<String, dynamic> toApiMap() {
    return {
      'dietaryStyle': dietaryStyle,
      'skillLevel': skillLevel,
      'aiPersonalityMode': aiPersonalityMode,
      'primaryGoal': primaryGoal,
      'cookingFrequency': cookingFrequency,
      'activityLevel': activityLevel,
      'preferSimpleRecipes': preferSimpleRecipes == 1,
      'householdSize': householdSize,
      if (weeklyBudget != null) 'weeklyBudget': weeklyBudget,
      if (dailyCalorieTarget != null) 'dailyCalorieTarget': dailyCalorieTarget,
      if (maxCookTimeMinutes != null) 'maxCookTimeMinutes': maxCookTimeMinutes,
      if (height != null) 'height': height,
      if (weight != null) 'weight': weight,
    };
  }
}
