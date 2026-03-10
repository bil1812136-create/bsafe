import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bsafe_app/models/report_model.dart';
import 'package:bsafe_app/providers/report_provider.dart';
import 'package:bsafe_app/theme/app_theme.dart';
import 'package:intl/intl.dart';

class ReportDetailScreen extends StatefulWidget {
  final ReportModel report;

  const ReportDetailScreen({super.key, required this.report});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  late ReportModel _report;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
    // 從雲端刷新最新資料（包含 company_notes）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().refreshFromCloud();
    });
  }

  /// 顯示更新狀態對話框（手機只能設為「待處理」或「處理中」，已解決由公司 Web 設定）
  Future<void> _showUpdateStatusDialog() async {
    final statuses = [
      {
        'key': 'pending',
        'label': '待處理',
        'icon': Icons.pending_actions,
        'color': Colors.grey
      },
      {
        'key': 'in_progress',
        'label': '處理中',
        'icon': Icons.engineering,
        'color': Colors.orange
      },
    ];

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('更新處理狀態'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...statuses.map((s) {
              final isActive = s['key'] == _report.status;
              return ListTile(
                leading: Icon(
                  s['icon'] as IconData,
                  color: isActive ? s['color'] as Color : Colors.grey,
                ),
                title: Text(
                  s['label'] as String,
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? s['color'] as Color : null,
                  ),
                ),
                trailing: isActive
                    ? Icon(Icons.check, color: s['color'] as Color)
                    : null,
                onTap: () => Navigator.pop(context, s['key'] as String),
              );
            }),
            const Divider(),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '「已解決」由公司後台設定',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    if (selected != null && selected != _report.status && mounted) {
      final provider = context.read<ReportProvider>();
      final success = await provider.updateReportStatus(_report, selected);
      if (success && mounted) {
        setState(() {
          _report =
              _report.copyWith(status: selected, updatedAt: DateTime.now());
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                    '狀態已更新為「${statuses.firstWhere((s) => s['key'] == selected)['label']}」'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  /// 構建圖片區域 — 支援本地檔案、網路 URL、Base64
  Widget _buildImageSection() {
    // 優先用 imagePath（本地檔案），再試 imageUrl（雲端 URL），最後試 imageBase64
    if (_report.imagePath != null && _report.imagePath!.isNotEmpty) {
      final file = File(_report.imagePath!);
      return Container(
        width: double.infinity,
        height: 250,
        decoration: BoxDecoration(color: Colors.grey.shade200),
        child: Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildImageFromUrl(),
        ),
      );
    }
    return _buildImageFromUrl();
  }

  Widget _buildImageFromUrl() {
    if (_report.imageUrl != null && _report.imageUrl!.isNotEmpty) {
      return Container(
        width: double.infinity,
        height: 250,
        decoration: BoxDecoration(color: Colors.grey.shade200),
        child: Image.network(
          _report.imageUrl!,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (_, __, ___) => _buildImageFromBase64(),
        ),
      );
    }
    return _buildImageFromBase64();
  }

  Widget _buildImageFromBase64() {
    if (_report.imageBase64 != null && _report.imageBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(_report.imageBase64!);
        return Container(
          width: double.infinity,
          height: 250,
          decoration: BoxDecoration(color: Colors.grey.shade200),
          child: Image.memory(bytes, fit: BoxFit.cover),
        );
      } catch (_) {}
    }
    // 無圖片
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('報告詳情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '從雲端刷新',
            onPressed: () async {
              await context.read<ReportProvider>().refreshFromCloud();
              // 重新取得最新報告
              final provider = context.read<ReportProvider>();
              final updated = provider.reports.cast<ReportModel?>().firstWhere(
                    (r) => r?.id == _report.id,
                    orElse: () => null,
                  );
              if (updated != null && mounted) {
                setState(() => _report = updated);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已從雲端刷新'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            _buildImageSection(),

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
                          _report.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _RiskBadge(riskLevel: _report.riskLevel),
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
                        DateFormat('yyyy/MM/dd HH:mm')
                            .format(_report.createdAt),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (!_report.synced) ...[
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
                      color: AppTheme.getRiskColor(_report.riskLevel)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.getRiskColor(_report.riskLevel)
                            .withValues(alpha: 0.3),
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
                              color: AppTheme.getRiskColor(_report.riskLevel),
                              width: 4,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${_report.riskScore}',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.getRiskColor(_report.riskLevel),
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
                                AppTheme.getRiskLabel(_report.riskLevel),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      AppTheme.getRiskColor(_report.riskLevel),
                                ),
                              ),
                              if (_report.isUrgent)
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
                    content: ReportModel.getCategoryLabel(_report.category),
                  ),

                  _DetailSection(
                    title: '嚴重程度',
                    icon: Icons.warning_amber,
                    content: ReportModel.getSeverityLabel(_report.severity),
                  ),

                  _DetailSection(
                    title: '詳細描述',
                    icon: Icons.description,
                    content: _report.description,
                  ),

                  if (_report.location != null && _report.location!.isNotEmpty)
                    _DetailSection(
                      title: '位置資訊',
                      icon: Icons.location_on,
                      content: _report.location!,
                    ),

                  if (_report.aiAnalysis != null &&
                      _report.aiAnalysis!.isNotEmpty)
                    _DetailSection(
                      title: 'AI 分析結果',
                      icon: Icons.auto_awesome,
                      content: _report.aiAnalysis!,
                    ),

                  // 公司回饋 / 跟進任務
                  if (_report.companyNotes != null &&
                      _report.companyNotes!.isNotEmpty)
                    _CompanyFeedbackSection(notes: _report.companyNotes!),

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
                  _StatusStepper(status: _report.status),

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
                  onPressed: () async {
                    await context.read<ReportProvider>().refreshFromCloud();
                    final provider = context.read<ReportProvider>();
                    final updated =
                        provider.reports.cast<ReportModel?>().firstWhere(
                              (r) => r?.id == _report.id,
                              orElse: () => null,
                            );
                    if (updated != null && mounted) {
                      setState(() => _report = updated);
                    }
                  },
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('同步雲端'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showUpdateStatusDialog,
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

/// 公司回饋 / 跟進任務區塊
class _CompanyFeedbackSection extends StatelessWidget {
  final String notes;
  const _CompanyFeedbackSection({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.feedback, size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Text(
                '公司回饋 / 跟進任務',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              notes,
              style: TextStyle(fontSize: 15, color: Colors.blue.shade900),
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
                            ? (isCurrent
                                ? AppTheme.primaryColor
                                : AppTheme.riskLow)
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
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
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
