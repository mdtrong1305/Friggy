import 'dart:convert';

class LocalWeeklyPlanModel {
  final String id;
  final String weekStartDate;
  final String daysDataJson;
  final int updatedAt;

  LocalWeeklyPlanModel({
    required this.id,
    required this.weekStartDate,
    required this.daysDataJson,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'week_start_date': weekStartDate,
      'days_data_json': daysDataJson,
      'updated_at': updatedAt,
    };
  }

  factory LocalWeeklyPlanModel.fromMap(Map<String, dynamic> map) {
    return LocalWeeklyPlanModel(
      id: map['id'] as String,
      weekStartDate: map['week_start_date'] as String? ?? '',
      daysDataJson: map['days_data_json'] as String? ?? '[]',
      updatedAt: map['updated_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Decode JSON string of days data into structured List
  List<dynamic> get decodedDaysData {
    try {
      return jsonDecode(daysDataJson) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  /// Get today's meals dynamically from weekly plan
  List<dynamic> getTodayMeals() {
    final days = decodedDaysData;
    if (days.isEmpty) return [];

    final currentDayOfWeek = DateTime.now().weekday;

    for (var day in days) {
      if (day is Map) {
        final dayMap = Map<String, dynamic>.from(day);
        final rawDay = dayMap['dayOfWeek'];
        final dayOfWeekInMap = rawDay is int
            ? rawDay
            : (int.tryParse(rawDay?.toString() ?? '') ?? 1);
        if (dayOfWeekInMap == currentDayOfWeek) {
          if (dayMap['mealSlots'] is List) return dayMap['mealSlots'] as List;
          if (dayMap['meals'] is List) return dayMap['meals'] as List;
        }
      }
    }

    // Fallback to first day if current day of week not found
    if (days.isNotEmpty && days.first is Map) {
      final firstMap = Map<String, dynamic>.from(days.first as Map);
      if (firstMap['mealSlots'] is List) return firstMap['mealSlots'] as List;
      if (firstMap['meals'] is List) return firstMap['meals'] as List;
    }

    return [];
  }
}
