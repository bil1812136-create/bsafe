import 'package:flutter/material.dart';
import 'package:bsafe_app/models/report_model.dart';
import 'package:bsafe_app/theme/app_theme.dart';

class SeveritySelector extends StatelessWidget {
  final String selectedSeverity;
  final Function(String) onSelected;

  const SeveritySelector({
    super.key,
    required this.selectedSeverity,
    required this.onSelected,
  });

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'severe':
        return AppTheme.riskHigh;
      case 'moderate':
        return AppTheme.riskMedium;
      case 'mild':
      default:
        return AppTheme.riskLow;
    }
  }

  IconData _getSeverityIcon(String severity) {
    switch (severity) {
      case 'severe':
        return Icons.warning;
      case 'moderate':
        return Icons.error_outline;
      case 'mild':
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: ReportModel.severities.map((severity) {
        final isSelected = selectedSeverity == severity['value'];
        final color = _getSeverityColor(severity['value']!);
        final icon = _getSeverityIcon(severity['value']!);

        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(severity['value']!),
            child: Container(
              margin: EdgeInsets.only(
                right: severity['value'] != 'severe' ? 8 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? color : AppTheme.borderColor,
                  width: 2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  Icon(
                    icon,
                    color: isSelected ? Colors.white : color,
                    size: 28,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    severity['label']!,
                    style: TextStyle(
                      color: isSelected ? Colors.white : color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
