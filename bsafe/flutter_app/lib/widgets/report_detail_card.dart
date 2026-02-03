import 'dart:io';
import 'package:flutter/material.dart';
import 'package:bsafe_app/models/report_model.dart';
import 'package:bsafe_app/theme/app_theme.dart';
import 'package:intl/intl.dart';

class ReportDetailCard extends StatelessWidget {
  final ReportModel report;
  final VoidCallback? onTap;

  const ReportDetailCard({
    super.key,
    required this.report,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Header
            if (report.imagePath != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      color: Colors.grey.shade200,
                      child: Image.file(
                        File(report.imagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(
                              Icons.image,
                              size: 40,
                              color: Colors.grey.shade400,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Risk Badge Overlay
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.getRiskColor(report.riskLevel),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${report.riskScore}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            AppTheme.getRiskLabel(report.riskLevel),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Urgent Badge
                  if (report.isUrgent)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '緊急',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    report.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Tags Row
                  Row(
                    children: [
                      _Tag(
                        icon: Icons.category,
                        label: ReportModel.getCategoryLabel(report.category),
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      _Tag(
                        icon: Icons.warning_amber,
                        label: ReportModel.getSeverityLabel(report.severity),
                        color: _getSeverityColor(report.severity),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Description
                  Text(
                    report.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 12),

                  // Footer
                  Row(
                    children: [
                      if (report.location != null && report.location!.isNotEmpty) ...[
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            report.location!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else
                        const Spacer(),
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MM/dd HH:mm').format(report.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      if (!report.synced) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.cloud_off,
                          size: 14,
                          color: Colors.orange.shade600,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Tag({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
