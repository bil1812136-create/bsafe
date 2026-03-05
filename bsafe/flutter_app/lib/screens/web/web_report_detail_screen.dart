import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bsafe_app/theme/app_theme.dart';
import 'package:intl/intl.dart';

/// 報告詳情 & 編輯頁面（公司後台用）
///
/// 功能：
///  - 顯示手機端 AI 生成的分析報告
///  - 可編輯 AI 分析文字內容
///  - 修改狀態（待處理 / 處理中 / 已解決）
///  - 儲存到 Supabase 作為公司記錄
class WebReportDetailScreen extends StatefulWidget {
  final Map<String, dynamic> report;
  const WebReportDetailScreen({super.key, required this.report});

  @override
  State<WebReportDetailScreen> createState() => _WebReportDetailScreenState();
}

class _WebReportDetailScreenState extends State<WebReportDetailScreen> {
  late TextEditingController _analysisController;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _notesController;
  late String _status;
  late String _severity;
  bool _isSaving = false;
  bool _hasChanges = false;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    final r = widget.report;
    _titleController = TextEditingController(text: r['title'] ?? '');
    _descriptionController =
        TextEditingController(text: r['description'] ?? '');
    _analysisController = TextEditingController(text: r['ai_analysis'] ?? '');
    _notesController = TextEditingController(text: r['company_notes'] ?? '');
    _status = r['status'] ?? 'pending';
    _severity = r['severity'] ?? 'moderate';

    _titleController.addListener(_markChanged);
    _descriptionController.addListener(_markChanged);
    _analysisController.addListener(_markChanged);
    _notesController.addListener(_markChanged);
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _analysisController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _supabase.from('reports').update({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'ai_analysis': _analysisController.text,
        'status': _status,
        'severity': _severity,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.report['id']);

      if (mounted) {
        setState(() {
          _isSaving = false;
          _hasChanges = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('報告已儲存'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('儲存失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final riskLevel = r['risk_level'] ?? 'low';
    final riskScore = r['risk_score'] ?? 0;
    final riskColor = AppTheme.getRiskColor(riskLevel);
    final createdAt = r['created_at'] != null
        ? DateFormat('yyyy/MM/dd HH:mm')
            .format(DateTime.parse(r['created_at']).toLocal())
        : '-';
    final imageUrl = r['image_url'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('報告詳情 / 編輯'),
        actions: [
          if (_hasChanges)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save, color: Colors.white),
                label: Text(
                  _isSaving ? '儲存中...' : '儲存變更',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 左: 圖片 + 基本資訊 ──
            SizedBox(
              width: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 圖片
                  _buildImageCard(imageUrl),
                  const SizedBox(height: 24),
                  // 基本資訊
                  _buildInfoCard(riskLevel, riskScore, riskColor, createdAt),
                  const SizedBox(height: 24),
                  // 狀態修改
                  _buildStatusCard(),
                ],
              ),
            ),
            const SizedBox(width: 32),

            // ── 右: AI 分析 + 編輯區 ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEditableSection(
                    title: '報告標題',
                    icon: Icons.title,
                    controller: _titleController,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 24),
                  _buildEditableSection(
                    title: '報告描述',
                    icon: Icons.description,
                    controller: _descriptionController,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  _buildEditableSection(
                    title: 'AI 分析結果（可修改）',
                    icon: Icons.smart_toy,
                    controller: _analysisController,
                    maxLines: 12,
                    highlight: true,
                  ),
                  const SizedBox(height: 24),
                  // 儲存按鈕
                  if (_hasChanges)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save),
                        label: Text(_isSaving ? '儲存中...' : '儲存所有變更'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════ Widget builders ═══════════

  Widget _buildImageCard(String? imageUrl) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.photo, color: AppTheme.primaryColor, size: 20),
              SizedBox(width: 8),
              Text('現場照片',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    height: 260,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _noImagePlaceholder(),
                  )
                : _noImagePlaceholder(),
          ),
        ],
      ),
    );
  }

  Widget _noImagePlaceholder() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text('無照片', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
      String riskLevel, int riskScore, Color riskColor, String createdAt) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
              SizedBox(width: 8),
              Text('基本資訊',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow('類別', _categoryLabel(widget.report['category'] ?? '')),
          _infoRow('位置', widget.report['location'] ?? '未指定'),
          _infoRow('建立時間', createdAt),
          const Divider(height: 24),
          // 風險指標
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: riskColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        AppTheme.getRiskLabel(riskLevel),
                        style: TextStyle(
                          color: riskColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('風險等級',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: riskColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$riskScore',
                        style: TextStyle(
                          color: riskColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('風險分數',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flag, color: AppTheme.primaryColor, size: 20),
              SizedBox(width: 8),
              Text('處理狀態',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          _statusOption('pending', '待處理', Icons.pending, Colors.grey),
          _statusOption('in_progress', '處理中', Icons.engineering, Colors.orange),
          _statusOption('resolved', '已解決', Icons.check_circle, Colors.green),
          const Divider(height: 24),
          const Text('嚴重程度',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              _severityOption('mild', '輕微', Colors.green),
              const SizedBox(width: 8),
              _severityOption('moderate', '中度', Colors.orange),
              const SizedBox(width: 8),
              _severityOption('severe', '嚴重', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusOption(String value, String label, IconData icon, Color color) {
    final active = _status == value;
    return InkWell(
      onTap: () {
        setState(() {
          _status = value;
          _hasChanges = true;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: active ? Border.all(color: color.withOpacity(0.5)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: active ? color : Colors.grey, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                color: active ? color : AppTheme.textSecondary,
              ),
            ),
            const Spacer(),
            if (active) Icon(Icons.check, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _severityOption(String value, String label, Color color) {
    final active = _severity == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _severity = value;
            _hasChanges = true;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.15) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: active ? Border.all(color: color) : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? color : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditableSection({
    required String title,
    required IconData icon,
    required TextEditingController controller,
    int maxLines = 1,
    bool highlight = false,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  color: highlight ? Colors.deepOrange : AppTheme.primaryColor,
                  size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: highlight ? Colors.deepOrange : null,
                  )),
              if (highlight) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '可編輯',
                    style: TextStyle(
                      color: Colors.deepOrange,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: highlight
                      ? Colors.deepOrange.withOpacity(0.3)
                      : AppTheme.borderColor,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: highlight
                      ? Colors.deepOrange.withOpacity(0.3)
                      : AppTheme.borderColor,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: highlight ? Colors.deepOrange : AppTheme.primaryColor,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: highlight
                  ? Colors.orange.withOpacity(0.03)
                  : Colors.grey.shade50,
              hintText: highlight ? '在此修改 AI 分析內容...' : null,
            ),
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: highlight ? Colors.black87 : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(String category) {
    const map = {
      'structural': '結構性問題',
      'exterior': '外牆問題',
      'public_area': '公共區域',
      'electrical': '電氣問題',
      'plumbing': '水管問題',
      'other': '其他',
    };
    return map[category] ?? category;
  }
}
