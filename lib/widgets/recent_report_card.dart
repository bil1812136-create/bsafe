import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bsafe_app/models/report_model.dart';
import 'package:bsafe_app/theme/app_theme.dart';
import 'package:intl/intl.dart';

class RecentReportCard extends StatelessWidget {
  final ReportModel report;

  const RecentReportCard({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          InkWell(
            onTap: () {
              // Navigate to detail
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Thumbnail
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _buildThumbnail(report),
                  ),
                  const SizedBox(width: 12),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _CategoryTag(category: report.category),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('MM/dd HH:mm')
                                  .format(report.createdAt),
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Risk Badge
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.getRiskColor(report.riskLevel),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          AppTheme.getRiskLabel(report.riskLevel),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (report.isUrgent)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber,
                              size: 14,
                              color: Colors.red.shade600,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '緊急',
                              style: TextStyle(
                                color: Colors.red.shade600,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      if (!report.synced)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cloud_off,
                              size: 14,
                              color: Colors.orange.shade600,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '待同步',
                              style: TextStyle(
                                color: Colors.orange.shade600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 紅色未讀標記
          if (report.hasUnreadCompany)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 縮圖：依序試 localFile (mobile only) → URL → base64 → placeholder
  Widget _buildThumbnail(ReportModel report) {
    final radius = BorderRadius.circular(12);
    if (!kIsWeb && report.imagePath != null && report.imagePath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.file(
          File(report.imagePath!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _urlOrBase64Thumbnail(report, radius),
        ),
      );
    }
    return _urlOrBase64Thumbnail(report, radius);
  }

  Widget _urlOrBase64Thumbnail(ReportModel report, BorderRadius radius) {
    if (report.imageUrl != null && report.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.network(
          report.imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _base64Thumbnail(report, radius),
        ),
      );
    }
    return _base64Thumbnail(report, radius);
  }

  Widget _base64Thumbnail(ReportModel report, BorderRadius radius) {
    if (report.imageBase64 != null && report.imageBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(report.imageBase64!);
        return ClipRRect(
          borderRadius: radius,
          child: Image.memory(bytes, fit: BoxFit.cover),
        );
      } catch (_) {}
    }
    return Icon(Icons.image, color: Colors.grey.shade400);
  }
}

class _CategoryTag extends StatelessWidget {
  final String category;

  const _CategoryTag({required this.category});

  String _getEmoji() {
    switch (category) {
      case 'structural':
        return '🏗️';
      case 'exterior':
        return '🧱';
      case 'public_area':
        return '🚪';
      case 'electrical':
        return '⚡';
      case 'plumbing':
        return '🚰';
      default:
        return '📋';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${_getEmoji()} ${ReportModel.getCategoryLabel(category)}',
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }
}
