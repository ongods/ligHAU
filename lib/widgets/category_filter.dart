import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CategoryFilter extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;
  final double horizontalPadding;
  final Color borderColor;

  const CategoryFilter({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
    this.horizontalPadding = 20,
    this.borderColor = AppColors.pathway,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = cat == selected;
          return ChoiceChip(
            label: Text(cat),
            selected: isSelected,
            onSelected: (_) => onSelected(cat),
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppColors.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            backgroundColor: AppColors.surface,
            side: BorderSide(
              color: isSelected ? AppColors.primary : borderColor,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}
