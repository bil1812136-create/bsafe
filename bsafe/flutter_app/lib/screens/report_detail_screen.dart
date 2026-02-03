import 'dart:io';
import 'package:flutter/material.dart';
import 'package:bsafe_app/models/report_model.dart';
import 'package:bsafe_app/theme/app_theme.dart';
import 'package:intl/intl.dart';

class ReportDetailScreen extends StatelessWidget {
  final ReportModel report;

  const ReportDetailScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('報告詳情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Share report
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            if (report.imagePath != null)
              Container(
                width: double.infinity,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                ),
                child: Image.file(
                  File(report.imagePath!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                    );
                  },
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Risk Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          report.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _RiskBadge(riskLevel: report.riskLevel),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Meta Info
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('yyyy/MM/dd HH:mm').format(report.createdAt),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (!report.synced) ...[
                        Icon(
                          Icons.cloud_off,
                          size: 16,
                          color: Colors.orange.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '未同步',
                          style: TextStyle(
                            color: Colors.orange.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Risk Score Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.getRiskColor(report.riskLevel).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.getRiskColor(report.riskLevel).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: AppTheme.getRiskColor(report.riskLevel),
                              width: 4,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${report.riskScore}',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.getRiskColor(report.riskLevel),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '風險評分',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppTheme.getRiskLabel(report.riskLevel),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.getRiskColor(report.riskLevel),
                                ),
                              ),
                              if (report.isUrgent)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.riskHigh,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '⚠️ 需緊急處理',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Details Section
                  _DetailSection(
                    title: '問題類別',
                    icon: Icons.category,
                    content: ReportModel.getCategoryLabel(report.category),
                  ),

                  _DetailSection(
                    title: '嚴重程度',
                    icon: Icons.warning_amber,
                    content: ReportModel.getSeverityLabel(report.severity),
                  ),

                  _DetailSection(
                    title: '詳細描述',
                    icon: Icons.description,
                    content: report.description,
                  ),

                  if (report.location != null && report.location!.isNotEmpty)
                    _DetailSection(
                      title: '位置資訊',
                      icon: Icons.location_on,
                      content: report.location!,
                    ),

                  if (report.aiAnalysis != null && report.aiAnalysis!.isNotEmpty)
                    _DetailSection(
                      title: 'AI 分析結果',
                      icon: Icons.auto_awesome,
                      content: report.aiAnalysis!,
                    ),

                  const SizedBox(height: 20),

                  // Status Section
                  const Text(
                    '處理狀態',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _StatusStepper(status: report.status),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Edit report
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('編輯'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Update status
                  },
                  icon: const Icon(Icons.update),
                  label: const Text('更新狀態'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final String riskLevel;

  const _RiskBadge({required this.riskLevel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.getRiskColor(riskLevel),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        AppTheme.getRiskLabel(riskLevel),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final String content;

  const _DetailSection({
    required this.title,
    required this.icon,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              content,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusStepper extends StatelessWidget {
  final String status;

  const _StatusStepper({required this.status});

  @override
  Widget build(BuildContext context) {
    final statuses = [
      {'key': 'pending', 'label': '待處理', 'icon': Icons.pending_actions},
      {'key': 'in_progress', 'label': '處理中', 'icon': Icons.autorenew},
      {'key': 'resolved', 'label': '已解決', 'icon': Icons.check_circle},
    ];

    final currentIndex = statuses.indexWhere((s) => s['key'] == status);

    return Row(
      children: statuses.asMap().entries.map((entry) {
        final index = entry.key;
        final s = entry.value;
        final isActive = index <= currentIndex;
        final isCurrent = index == currentIndex;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? (isCurrent ? AppTheme.primaryColor : AppTheme.riskLow)
                            : Colors.grey.shade300,
                      ),
                      child: Icon(
                        s['icon'] as IconData,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? AppTheme.primaryColor : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (index < statuses.length - 1)
                Expanded(
                  child: Container(
                    height: 3,
                    color: index < currentIndex
                        ? AppTheme.riskLow
                        : Colors.grey.shade300,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
