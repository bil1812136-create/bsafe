import 'package:flutter/material.dart';
import 'package:bsafe_app/models/report_model.dart';
import 'package:bsafe_app/theme/app_theme.dart';

class CategorySelector extends StatelessWidget {
  final String selectedCategory;
  final Function(String) onSelected;

  const CategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ReportModel.categories.map((category) {
        final isSelected = selectedCategory == category['value'];
        return GestureDetector(
          onTap: () => onSelected(category['value']!),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.borderColor,
                width: 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category['icon']!,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 6),
                Text(
                  category['label']!,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
