import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bsafe_app/models/report_model.dart';
import 'package:bsafe_app/theme/app_theme.dart';
import 'package:intl/intl.dart';

class ReportDetailCard extends StatelessWidget {
  final ReportModel report;
  final int? displayNumber;
  final VoidCallback? onTap;

  const ReportDetailCard({
    super.key,
    required this.report,
    this.displayNumber,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String _simplifyLocation(String? location) {
      if (location == null || location.isEmpty) return '';
      // Remove any 'ref:' suffix and Pin(...) coordinate parts
      try {
        // Keep original for pin extraction
        final original = location;

        // remove ref: and following text
        var loc = original;
        final refIndex = loc.toLowerCase().indexOf('ref:');
        if (refIndex >= 0) loc = loc.substring(0, refIndex).trim();

        // find first Pin(...) in original string
        final pinMatch = RegExp(r'Pin\s*\([^)]*\)').firstMatch(original);
        final pinText = pinMatch?.group(0) ?? '';

        // attempt to extract building/floor pattern from loc
        final bfMatch =
            RegExp(r'building[^/\\]*\\/\s*F?\d+', caseSensitive: false)
                .firstMatch(loc);
        String buildingFloor;
        if (bfMatch != null) {
          buildingFloor = bfMatch.group(0)!.trim();
        } else {
          // fallback: take text before first '-' or ';' or ':'
          final parts = loc.split(RegExp(r'[-;:]'));
          buildingFloor = parts.isNotEmpty ? parts[0].trim() : loc.trim();
        }

        if (buildingFloor.isEmpty && pinText.isEmpty) return '';
        if (pinText.isNotEmpty)
          return '${buildingFloor.isEmpty ? pinText : '$buildingFloor - $pinText'}';
        return buildingFloor;
      } catch (_) {
        return location;
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Header
                if ((!kIsWeb &&
                        report.imagePath != null &&
                        report.imagePath!.isNotEmpty) ||
                    (report.imageUrl != null && report.imageUrl!.isNotEmpty) ||
                    (report.imageBase64 != null &&
                        report.imageBase64!.isNotEmpty))
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
                          child: _buildHeaderImage(report),
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
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppTheme.getRiskLabel(report.riskLevel),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '#${displayNumber ?? report.id ?? '-'}',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _Tag(
                            icon: Icons.category,
                            label:
                                ReportModel.getCategoryLabel(report.category),
                            color: AppTheme.primaryColor,
                          ),
                          _Tag(
                            icon: Icons.warning_amber,
                            label:
                                ReportModel.getSeverityLabel(report.severity),
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
                          if (report.location != null &&
                              report.location!.isNotEmpty) ...[
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _simplifyLocation(report.location!),
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
          // 紅色未讀標記
          if (report.hasUnreadCompany)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 14,
                height: 14,
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

  /// 標頭圖片：依序試 localFile (mobile only) → URL → base64 → placeholder
  Widget _buildHeaderImage(ReportModel report) {
    if (!kIsWeb && report.imagePath != null && report.imagePath!.isNotEmpty) {
      return Image.file(
        File(report.imagePath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _urlOrBase64Header(report),
      );
    }
    return _urlOrBase64Header(report);
  }

  Widget _urlOrBase64Header(ReportModel report) {
    if (report.imageUrl != null && report.imageUrl!.isNotEmpty) {
      return Image.network(
        report.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _base64Header(report),
      );
    }
    return _base64Header(report);
  }

  Widget _base64Header(ReportModel report) {
    if (report.imageBase64 != null && report.imageBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(report.imageBase64!);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    }
    return Center(
      child: Icon(Icons.image, size: 40, color: Colors.grey.shade400),
    );
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
        color: color.withValues(alpha: 0.1),
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
