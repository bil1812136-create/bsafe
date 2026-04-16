import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bsafe_app/features/defect_reporting/data/models/report_model.dart';
import 'package:bsafe_app/core/theme/app_theme.dart';

class ReportDetailCard extends StatelessWidget {
  final ReportModel report;
  final VoidCallback? onTap;

  const ReportDetailCard({super.key, required this.report, this.onTap});

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'severe':
        return AppTheme.riskHigh;
      case 'moderate':
        return AppTheme.riskMedium;
      default:
        return AppTheme.riskLow;
    }
  }

  Widget _buildHeaderImage(ReportModel r) {
    if (!kIsWeb && r.imagePath != null && r.imagePath!.isNotEmpty) {
      return Image.file(File(r.imagePath!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _urlOrBase64Header(r));
    }
    return _urlOrBase64Header(r);
  }

  Widget _urlOrBase64Header(ReportModel r) {
    if (r.imageUrl != null && r.imageUrl!.isNotEmpty) {
      return Image.network(r.imageUrl!,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => _base64Header(r));
    }
    return _base64Header(r);
  }

  Widget _base64Header(ReportModel r) {
    if (r.imageBase64 != null && r.imageBase64!.isNotEmpty) {
      try {
        return Image.memory(base64Decode(r.imageBase64!), fit: BoxFit.cover);
      } catch (_) {}
    }
    return Center(
        child: Icon(Icons.image, size: 40, color: Colors.grey.shade400));
  }

  @override
  Widget build(BuildContext context) {
    final hasImage =
        (!kIsWeb && report.imagePath != null && report.imagePath!.isNotEmpty) ||
            (report.imageUrl != null && report.imageUrl!.isNotEmpty) ||
            (report.imageBase64 != null && report.imageBase64!.isNotEmpty);
    return GestureDetector(
      onTap: onTap,
      child: Stack(children: [
        Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2))
              ]),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (hasImage)
              Stack(children: [
                ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Container(
                        height: 120,
                        width: double.infinity,
                        color: Colors.grey.shade200,
                        child: _buildHeaderImage(report))),
                Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: AppTheme.getRiskColor(report.riskLevel),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4)
                            ]),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('${report.riskScore}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(AppTheme.getRiskLabel(report.riskLevel),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12))
                        ]))),
                if (report.isUrgent)
                  Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4)),
                          child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning,
                                    color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text('緊急',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold))
                              ]))),
              ]),
            Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(report.title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(children: [
                        _Tag(
                            icon: Icons.category,
                            label:
                                ReportModel.getCategoryLabel(report.category),
                            color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        _Tag(
                            icon: Icons.warning_amber,
                            label:
                                ReportModel.getSeverityLabel(report.severity),
                            color: _getSeverityColor(report.severity)),
                      ]),
                      const SizedBox(height: 8),
                      Text(report.description,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 12),
                      Row(children: [
                        if (report.location != null &&
                            report.location!.isNotEmpty) ...[
                          Icon(Icons.location_on,
                              size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(report.location!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                        ] else
                          const Spacer(),
                        Icon(Icons.access_time,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(DateFormat('MM/dd HH:mm').format(report.createdAt),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500)),
                        if (!report.synced) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.cloud_off,
                              size: 14, color: Colors.orange.shade600)
                        ],
                      ]),
                    ])),
          ]),
        ),
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
                            blurRadius: 4)
                      ]))),
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Tag({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ]),
      );
}
