import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
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
    // 從雲端刷新最新資料（包含 conversation）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ReportProvider>();
      provider.refreshFromCloud();
      // 清除未讀標記
      provider.clearUnreadCompany(_report);
      // 🔴 新增：訂閱實時更新 — 當 webapp/另一個 app 發送信息時自動刷新
      provider.subscribeToReport(_report);
    });
  }

  @override
  void dispose() {
    // 🔴 新增：離開詳情頁面時，取消實時監聽
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().unsubscribeFromCurrentReport();
    });
    super.dispose();
  }

  /// 打開「更新資料」表單 — 上傳圖片＋輸入文字＋發送
  void _showUpdateForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _WorkerResponseForm(
        report: _report,
        onSubmitted: (updatedReport) {
          setState(() => _report = updatedReport);
        },
      ),
    );
  }

  /// 全屏檢視圖片
  void _openImageViewer(Widget imageWidget) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: imageWidget,
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: SafeArea(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 構建圖片區域 — 支援本地檔案、網路 URL、Base64
  Widget _buildImageSection() {
    // 手機本地檔案（Web 不支援 Image.file）
    if (!kIsWeb && _report.imagePath != null && _report.imagePath!.isNotEmpty) {
      final file = File(_report.imagePath!);
      return GestureDetector(
        onTap: () => _openImageViewer(Image.file(file, fit: BoxFit.contain)),
        child: Container(
          width: double.infinity,
          height: 250,
          decoration: BoxDecoration(color: Colors.grey.shade200),
          child: Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildImageFromUrl(),
          ),
        ),
      );
    }
    return _buildImageFromUrl();
  }

  Widget _buildImageFromUrl() {
    if (_report.imageUrl != null && _report.imageUrl!.isNotEmpty) {
      return GestureDetector(
        onTap: () => _openImageViewer(
            Image.network(_report.imageUrl!, fit: BoxFit.contain)),
        child: Container(
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
        ),
      );
    }
    return _buildImageFromBase64();
  }

  Widget _buildImageFromBase64() {
    if (_report.imageBase64 != null && _report.imageBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(_report.imageBase64!);
        return GestureDetector(
          onTap: () =>
              _openImageViewer(Image.memory(bytes, fit: BoxFit.contain)),
          child: Container(
            width: double.infinity,
            height: 250,
            decoration: BoxDecoration(color: Colors.grey.shade200),
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
        );
      } catch (_) {}
    }
    // 無圖片
    return const SizedBox.shrink();
  }

  Map<String, dynamic> _extractInspectionRefFromLocation(String? location) {
    if (location == null || location.isEmpty) return {};

    final refIndex = location.indexOf('ref:');
    if (refIndex < 0) {
      final legacyFloorMatch =
          RegExp(r'\bF\s*(\d+)\b', caseSensitive: false).firstMatch(location);
      final legacyPinMatch = RegExp(
              r'Pin\s*\(\s*([-+]?\d+(?:\.\d+)?)\s*,\s*([-+]?\d+(?:\.\d+)?)\s*\)',
              caseSensitive: false)
          .firstMatch(location);
      final legacyPercentMatch = RegExp(
              r'pinXPercent\s*=\s*([-+]?\d+(?:\.\d+)?)\s*;\s*pinYPercent\s*=\s*([-+]?\d+(?:\.\d+)?)',
              caseSensitive: false)
          .firstMatch(location);

      return {
        if (legacyFloorMatch != null)
          'floor': int.tryParse(legacyFloorMatch.group(1) ?? ''),
        if (legacyPinMatch != null) ...{
          'legacyPinX': double.tryParse(legacyPinMatch.group(1) ?? ''),
          'legacyPinY': double.tryParse(legacyPinMatch.group(2) ?? ''),
        },
        if (legacyPercentMatch != null) ...{
          'pinXPercent': double.tryParse(legacyPercentMatch.group(1) ?? ''),
          'pinYPercent': double.tryParse(legacyPercentMatch.group(2) ?? ''),
        },
      };
    }

    final refText = location.substring(refIndex + 4).trim();
    final parts = refText.split(';');
    String? sessionId;
    String? pinId;
    int? floor;
    double? minX;
    double? maxX;
    double? minY;
    double? maxY;
    double? pinXPercent;
    double? pinYPercent;

    final legacyFloorMatch =
        RegExp(r'\bF\s*(\d+)\b', caseSensitive: false).firstMatch(location);
    if (legacyFloorMatch != null) {
      floor ??= int.tryParse(legacyFloorMatch.group(1) ?? '');
    }

    for (final part in parts) {
      final kv = part.split('=');
      if (kv.length != 2) continue;
      final key = kv[0].trim();
      final value = kv[1].trim();
      if (key == 'session' && value.isNotEmpty) {
        sessionId = value;
      } else if (key == 'pin' && value.isNotEmpty) {
        pinId = value;
      } else if (key == 'floor') {
        floor = int.tryParse(value);
      } else if (key == 'minX') {
        minX = double.tryParse(value);
      } else if (key == 'maxX') {
        maxX = double.tryParse(value);
      } else if (key == 'minY') {
        minY = double.tryParse(value);
      } else if (key == 'maxY') {
        maxY = double.tryParse(value);
      } else if (key == 'pinXPercent') {
        pinXPercent = double.tryParse(value);
      } else if (key == 'pinYPercent') {
        pinYPercent = double.tryParse(value);
      }
    }

    return {
      if (sessionId != null) 'sessionId': sessionId,
      if (pinId != null) 'pinId': pinId,
      if (floor != null) 'floor': floor,
      if (minX != null) 'minX': minX,
      if (maxX != null) 'maxX': maxX,
      if (minY != null) 'minY': minY,
      if (maxY != null) 'maxY': maxY,
      if (pinXPercent != null) 'pinXPercent': pinXPercent,
      if (pinYPercent != null) 'pinYPercent': pinYPercent,
    };
  }

  String _buildLocationSummary(String? location) {
    if (location == null || location.isEmpty) return '未指定';

    final ref = _extractInspectionRefFromLocation(location);
    final sessionId = ref['sessionId']?.toString();
    final pinId = ref['pinId']?.toString();
    final floor = ref['floor']?.toString();
    final legacyPinX = (ref['legacyPinX'] as num?)?.toDouble();
    final legacyPinY = (ref['legacyPinY'] as num?)?.toDouble();
    final pinXPercent = (ref['pinXPercent'] as num?)?.toDouble();
    final pinYPercent = (ref['pinYPercent'] as num?)?.toDouble();
    final displayPinX = pinXPercent != null ? (pinXPercent * 100) : legacyPinX;
    final displayPinY =
        pinYPercent != null ? ((1 - pinYPercent) * 100) : legacyPinY;

    final lines = <String>[location];
    if (sessionId != null) lines.add('Session: $sessionId');
    if (pinId != null) lines.add('Pin: $pinId');
    if (floor != null) lines.add('Floor: $floor');
    if (displayPinX != null || displayPinY != null) {
      lines.add(
        '畫布座標: '
        '${displayPinX != null ? displayPinX.toStringAsFixed(1) : '-'}, '
        '${displayPinY != null ? displayPinY.toStringAsFixed(1) : '-'}',
      );
    }
    if (pinXPercent != null || pinYPercent != null) {
      lines.add(
        'Normalized: '
        'x=${pinXPercent?.toStringAsFixed(6) ?? '-'}, '
        'y=${pinYPercent?.toStringAsFixed(6) ?? '-'}',
      );
    }
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    // 🔴 從 Provider 獲取最新的報告資料（支持實時更新）
    final provider = context.watch<ReportProvider>();
    if (provider.currentReport != null &&
        provider.currentReport!.id == _report.id) {
      _report = provider.currentReport!; // 使用最新的實時數據
    }

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
              final prov = context.read<ReportProvider>();
              final updated = prov.reports.cast<ReportModel?>().firstWhere(
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

                  if (_report.location != null && _report.location!.isNotEmpty)
                    _DetailSection(
                      title: '位置資訊',
                      icon: Icons.location_on,
                      content: _buildLocationSummary(_report.location),
                    ),

                  if (_report.aiAnalysis != null &&
                      _report.aiAnalysis!.isNotEmpty)
                    _DetailSection(
                      title: 'AI 分析結果',
                      icon: Icons.auto_awesome,
                      content: _report.aiAnalysis!,
                    ),

                  // 對話 / 跟進記錄（多輪對話）
                  _ConversationSection(report: _report),

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
                  onPressed: _showUpdateForm,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('更新資料'),
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

/// 多輪對話區塊（合併公司回饋 + 工人回覆）
class _ConversationSection extends StatelessWidget {
  final ReportModel report;
  const _ConversationSection({required this.report});

  void _openImageViewer(BuildContext context, Widget imageWidget) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: imageWidget,
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: SafeArea(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = report.mergedConversation;
    if (messages.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.forum, size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Text(
                '跟進對話（${messages.length}）',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(10),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isCompany = msg.sender == 'company';
                return _buildMobileBubble(context, msg, isCompany);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBubble(
      BuildContext context, ConversationMessage msg, bool isCompany) {
    final time = DateFormat('MM/dd HH:mm').format(msg.timestamp.toLocal());
    return Align(
      alignment: isCompany ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isCompany ? Colors.blue.shade50 : Colors.teal.shade50,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isCompany ? 2 : 12),
            bottomRight: Radius.circular(isCompany ? 12 : 2),
          ),
          border: Border.all(
            color: isCompany ? Colors.blue.shade200 : Colors.teal.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCompany ? Icons.business : Icons.engineering,
                  size: 14,
                  color:
                      isCompany ? Colors.blue.shade700 : Colors.teal.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  isCompany ? '公司' : '工人',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color:
                        isCompany ? Colors.blue.shade700 : Colors.teal.shade700,
                  ),
                ),
                const SizedBox(width: 6),
                Text(time,
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ],
            ),
            const SizedBox(height: 4),
            // 圖片
            if (msg.image != null && msg.image!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GestureDetector(
                  onTap: () => _openImageViewer(
                    context,
                    msg.image!.startsWith('http')
                        ? Image.network(msg.image!, fit: BoxFit.contain)
                        : Image.memory(
                            base64Decode(msg.image!),
                            fit: BoxFit.contain,
                          ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: msg.image!.startsWith('http')
                        ? Image.network(
                            msg.image!,
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          )
                        : Image.memory(
                            base64Decode(msg.image!),
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                  ),
                ),
              ),
            Text(
              msg.text,
              style: TextStyle(
                fontSize: 13,
                color: isCompany ? Colors.blue.shade900 : Colors.teal.shade900,
              ),
            ),
          ],
        ),
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

/// 更新資料表單（底部抽屜） — 上傳圖片＋輸入文字＋發送（添加到多輪對話）
class _WorkerResponseForm extends StatefulWidget {
  final ReportModel report;
  final ValueChanged<ReportModel> onSubmitted;

  const _WorkerResponseForm({
    required this.report,
    required this.onSubmitted,
  });

  @override
  State<_WorkerResponseForm> createState() => _WorkerResponseFormState();
}

class _WorkerResponseFormState extends State<_WorkerResponseForm> {
  final _textController = TextEditingController();
  final _picker = ImagePicker();
  String? _imageBase64;
  Uint8List? _imageBytes;
  bool _isSending = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageBase64 = base64Encode(bytes);
      });
    } catch (e) {
      debugPrint('選取圖片失敗: $e');
    }
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請輸入回覆內容'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    final provider = context.read<ReportProvider>();
    final success = await provider.submitWorkerResponse(
      widget.report,
      text,
      _imageBase64,
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (success) {
      // 構建帶有更新對話的報告
      final updatedConv =
          List<ConversationMessage>.from(widget.report.mergedConversation);
      updatedConv.add(ConversationMessage(
        sender: 'worker',
        text: text,
        image: _imageBase64,
        timestamp: DateTime.now(),
      ));
      final updated = widget.report.copyWith(
        status: 'in_progress',
        workerResponse: text,
        workerResponseImage: _imageBase64,
        conversation: updatedConv,
        hasUnreadCompany: false,
        updatedAt: DateTime.now(),
      );
      widget.onSubmitted(updated);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('回覆已發送，狀態更新為「處理中」'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('發送失敗，請稍後再試'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標題列
          Row(
            children: [
              const Icon(Icons.edit_note, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '更新資料',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),

          // 最近公司訊息提示
          if (widget.report.mergedConversation.isNotEmpty)
            Builder(builder: (_) {
              final companyMsgs = widget.report.mergedConversation
                  .where((m) => m.sender == 'company')
                  .toList();
              if (companyMsgs.isEmpty) return const SizedBox.shrink();
              final last = companyMsgs.last;
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.task_alt, size: 18, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '最新公司跟進：',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            last.text,
                            style: TextStyle(
                                fontSize: 13, color: Colors.blue.shade900),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

          // 上傳圖片區域
          const Text('📷 上傳圖片', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _showImageSourceDialog(),
            child: Container(
              width: double.infinity,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _imageBytes != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            _imageBytes!,
                            width: double.infinity,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _imageBytes = null;
                              _imageBase64 = null;
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo,
                            size: 40, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text('點擊上傳現場照片',
                            style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // 文字輸入
          const Text('📝 回覆內容', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: '輸入處理情況、進度說明...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 20),

          // 發送按鈕
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: Text(_isSending ? '發送中...' : '發送回覆'),
            ),
          ),
        ],
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('從相簿選擇'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}
