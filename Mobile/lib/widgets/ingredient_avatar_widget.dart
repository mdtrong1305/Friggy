import 'package:flutter/material.dart';
import '../config/app_constants.dart';
import '../data/models/ingredient_model.dart';

class IngredientAvatarWidget extends StatelessWidget {
  final IngredientModel item;
  final double size;

  const IngredientAvatarWidget({
    super.key,
    required this.item,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    final fullUrl = AppConstants.getImageUrl(item.imagePath) ?? '';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        color: const Color(0xFFF0F7F1),
        border: Border.all(
          color: const Color(0xFFA5E69C).withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: fullUrl.isNotEmpty
            ? Image.network(
                fullUrl,
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
