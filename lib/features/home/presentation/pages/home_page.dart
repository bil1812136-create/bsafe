import 'dart:convert';
import 'dart:typed_data';
import 'package:bsafe_app/core/providers/connectivity_provider.dart';
import 'package:bsafe_app/core/providers/language_provider.dart';
import 'package:bsafe_app/core/providers/navigation_provider.dart';
import 'package:bsafe_app/features/defect_reporting/presentation/providers/report_provider.dart';
import 'package:bsafe_app/core/theme/app_theme.dart';
import 'package:bsafe_app/shared/widgets/shimmer_loading.dart';
import 'package:bsafe_app/shared/widgets/stat_card.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageNotifierProvider);
    final report = ref.watch(reportNotifierProvider);
    return Scaffold(
      body: Builder(
        builder: (context) {
          if (report.isLoading && report.reports.isEmpty) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ShimmerLoading(
                    width: double.infinity,
                    height: 150,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ShimmerLoading(
                          width: double.infinity,
                          height: 100,
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ShimmerLoading(
                          width: double.infinity,
                          height: 100,
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ShimmerLoading(
                          width: double.infinity,
                          height: 100,
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const ShimmerCard(),
                  const ShimmerCard(),
                ],
              ),
            );
          }

          final stats = report.statistics;
          final trendData = report.trendData;

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(reportNotifierProvider.notifier).loadReports(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          language.t('monitor_title'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${language.t('monitor_count_prefix')} ${stats['total'] ?? 0} ${language.t('monitor_count_suffix')}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
                          ),
                        ),
                        if (report.pendingSyncCount > 0) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.sync,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  '${report.pendingSyncCount} ${language.t('pending_sync_suffix')}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    language.t('risk_overview'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: language.t('high_risk'),
                          value: '${stats['highRisk'] ?? 0}',
                          icon: Icons.warning_amber_rounded,
                          color: AppTheme.riskHigh,
                          isClickable: true,
                          onTap: () => ref
                              .read(navigationNotifierProvider.notifier)
                              .goToHistory(filterRisk: 'high'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: language.t('medium_risk'),
                          value: '${stats['mediumRisk'] ?? 0}',
                          icon: Icons.error_outline,
                          color: AppTheme.riskMedium,
                          isClickable: true,
                          onTap: () => ref
                              .read(navigationNotifierProvider.notifier)
                              .goToHistory(filterRisk: 'medium'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: language.t('low_risk'),
                          value: '${stats['lowRisk'] ?? 0}',
                          icon: Icons.check_circle_outline,
                          color: AppTheme.riskLow,
                          isClickable: true,
                          onTap: () => ref
                              .read(navigationNotifierProvider.notifier)
                              .goToHistory(filterRisk: 'low'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: language.t('pending'),
                          value: '${stats['pending'] ?? 0}',
                          icon: Icons.pending_actions,
                          color: Colors.blue,
                          isClickable: true,
                          onTap: () => ref
                              .read(navigationNotifierProvider.notifier)
                              .goToHistoryByStatus('pending'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: language.t('in_progress'),
                          value: '${stats['in_progress'] ?? 0}',
                          icon: Icons.work_history,
                          color: Colors.orange,
                          isClickable: true,
                          onTap: () => ref
                              .read(navigationNotifierProvider.notifier)
                              .goToHistoryByStatus('in_progress'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: language.t('resolved'),
                          value: '${stats['resolved'] ?? 0}',
                          icon: Icons.task_alt,
                          color: Colors.green,
                          isClickable: true,
                          onTap: () => ref
                              .read(navigationNotifierProvider.notifier)
                              .goToHistoryByStatus('resolved'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    language.t('risk_distribution'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 200,
                          child: _buildPieChart(stats),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _LegendItem(
                              color: AppTheme.riskHigh,
                              label: language.t('high_risk'),
                              value: stats['highRisk'] ?? 0,
                            ),
                            _LegendItem(
                              color: AppTheme.riskMedium,
                              label: language.t('medium_risk'),
                              value: stats['mediumRisk'] ?? 0,
                            ),
                            _LegendItem(
                              color: AppTheme.riskLow,
                              label: language.t('low_risk'),
                              value: stats['lowRisk'] ?? 0,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    language.t('trend_7days'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 220,
                          child: _buildLineChart(trendData),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _ChartLegend(
                                color: AppTheme.riskHigh,
                                label: language.t('high_abbr')),
                            const SizedBox(width: 20),
                            _ChartLegend(
                                color: AppTheme.riskMedium,
                                label: language.t('medium_abbr')),
                            const SizedBox(width: 20),
                            _ChartLegend(
                                color: AppTheme.riskLow,
                                label: language.t('low_abbr')),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    language.t('processing_status'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: SizedBox(
                      height: 200,
                      child: _buildBarChart(stats),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '📌 重點數據',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: '需緊急處理',
                          value: '${stats['urgent'] ?? 0}',
                          icon: Icons.warning_amber_rounded,
                          color: AppTheme.riskHigh,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: '本月新增',
                          value: '${stats['total'] ?? 0}',
                          icon: Icons.add_chart,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: '處理中',
                          value:
                              '${(stats['total'] ?? 0) - (stats['pending'] ?? 0) - (stats['resolved'] ?? 0)}',
                          icon: Icons.autorenew,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: '完成率',
                          value: _calculateCompletionRate(stats),
                          icon: Icons.check_circle,
                          color: AppTheme.riskLow,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    language.t('quick_report'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const _HomeQuickReportPanel(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HomeQuickReportPanel extends ConsumerStatefulWidget {
  const _HomeQuickReportPanel();

  @override
  ConsumerState<_HomeQuickReportPanel> createState() =>
      _HomeQuickReportPanelState();
}

class _HomeQuickReportPanelState extends ConsumerState<_HomeQuickReportPanel> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _locationTextController = TextEditingController();

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _imageBase64;
  bool _isAnalyzing = false;
  bool _isSubmitting = false;
  bool _isLoadingFloorPlans = true;
  Map<String, dynamic>? _aiResult;
  List<String> _folderOptions = [];
  String? _selectedFolder;
  List<Map<String, dynamic>> _floorPlanOptions = [];
  Map<String, dynamic>? _selectedFloorPlan;
  double? _selectedPinX;
  double? _selectedPinY;

  List<Map<String, dynamic>> get _filteredFloorPlanOptions {
    if (_selectedFolder == null || _selectedFolder!.isEmpty) return [];
    return _floorPlanOptions
        .where((item) => item['buildingName']?.toString() == _selectedFolder)
        .toList();
  }

  String _extractBuildingName(
      Map<String, dynamic> payload, String? floorPlanPath) {
    final fromPayload =
        (payload['building_name'] ?? payload['buildingName'])?.toString();
    if (fromPayload != null && fromPayload.trim().isNotEmpty) {
      return fromPayload.trim();
    }

    final path = floorPlanPath ?? payload['floorPlanPath']?.toString();
    if (path != null && path.startsWith('buildings/')) {
      final parts = path.split('/');
      if (parts.length >= 2 && parts[1].isNotEmpty) {
        return parts[1];
      }
    }

    return '未分類';
  }

  String? _normalizeFloorPlanUrl(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return Supabase.instance.client.storage
        .from('floor-plans')
        .getPublicUrl(value);
  }

  @override
  void initState() {
    super.initState();
    _loadFloorPlanOptions();
  }

  @override
  void dispose() {
    _locationTextController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImage = image;
        _selectedImageBytes = bytes;
        _imageBase64 = base64Encode(bytes);
        _aiResult = null;
      });

      await _analyzeImage();
    } catch (e) {
      _showMessage('無法選擇圖片: $e', isError: true);
    }
  }

  Future<void> _analyzeImage() async {
    if (_imageBase64 == null) return;

    setState(() => _isAnalyzing = true);
    try {
      final reportProvider = ref.read(reportNotifierProvider.notifier);
      final result = await reportProvider.analyzeImage(_imageBase64!);
      if (!mounted) return;

      setState(() {
        _aiResult = result;
      });

      if (result != null && result['_ai_mode'] == 'local_fallback') {
        _showMessage('✓ 已使用本地評估（因網絡或地區限制）');
      } else {
        _showMessage('✓ AI 分析完成，可直接提交');
      }
    } catch (e) {
      _showMessage('分析中遇到問題: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _loadFloorPlanOptions() async {
    setState(() => _isLoadingFloorPlans = true);
    try {
      final rows = await Supabase.instance.client
          .from('inspection_sessions')
          .select('session_id, floor, floor_plan_path, payload, created_at')
          .order('created_at', ascending: false)
          .limit(100);

      final options = <Map<String, dynamic>>[];
      for (final row in rows) {
        final payload = row['payload'];
        if (payload is! Map<String, dynamic>) continue;

        final floorPlanUrl =
            (payload['floor_plan_url'] ?? payload['floorPlanUrl'])?.toString();
        final floorPlanBase64 = payload['floor_plan_base64']?.toString();
        final floorPlanPath =
            (row['floor_plan_path'] ?? payload['floorPlanPath'])?.toString();

        String? resolvedUrl = _normalizeFloorPlanUrl(floorPlanUrl);
        if ((resolvedUrl == null || resolvedUrl.isEmpty) &&
            floorPlanPath != null &&
            floorPlanPath.isNotEmpty) {
          resolvedUrl = _normalizeFloorPlanUrl(floorPlanPath);
        }

        if ((resolvedUrl == null || resolvedUrl.isEmpty) &&
            (floorPlanBase64 == null || floorPlanBase64.isEmpty)) {
          continue;
        }

        final floorNumber = row['floor'] ?? payload['floor'];
        final buildingName = _extractBuildingName(payload, floorPlanPath);

        options.add({
          'session_id': row['session_id'],
          'label': 'F$floorNumber',
          'floorNumber': floorNumber,
          'buildingName': buildingName,
          'floorPlanUrl': resolvedUrl,
          'floorPlanBase64': floorPlanBase64,
          'payload': payload,
        });
      }

      if (!mounted) return;
      setState(() {
        _floorPlanOptions = options;
        _folderOptions = options
            .map((e) => e['buildingName']?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        _selectedFolder =
            _folderOptions.isNotEmpty ? _folderOptions.first : null;
        final filtered = _filteredFloorPlanOptions;
        _selectedFloorPlan = filtered.isNotEmpty ? filtered.first : null;
        _selectedPinX = null;
        _selectedPinY = null;
        if (_selectedFloorPlan != null) {
          _locationTextController.text =
              '${_selectedFloorPlan!['buildingName']} / ${_selectedFloorPlan!['label']} - 未選 pin';
        } else {
          _locationTextController.clear();
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _folderOptions = [];
        _selectedFolder = null;
        _floorPlanOptions = [];
        _selectedFloorPlan = null;
      });
    } finally {
      if (mounted) setState(() => _isLoadingFloorPlans = false);
    }
  }

  Future<void> _appendPinToSelectedSession() async {
    if (_selectedFloorPlan == null ||
        _selectedPinX == null ||
        _selectedPinY == null) {
      return;
    }

    final sessionId = _selectedFloorPlan!['session_id'];
    final payload = Map<String, dynamic>.from(
      _selectedFloorPlan!['payload'] as Map<String, dynamic>? ?? {},
    );
    final pins = List<dynamic>.from(payload['pins'] as List<dynamic>? ?? []);

    final aiText = _extractAiText();

    pins.add({
      'id': 'rp_${DateTime.now().millisecondsSinceEpoch}',
      'x': _selectedPinX,
      'y': _selectedPinY,
      'note': _locationTextController.text.trim(),
      'defects': [
        {
          'imageBase64': _imageBase64,
          'description': aiText,
          'createdAt': DateTime.now().toIso8601String(),
        }
      ],
    });

    payload['pins'] = pins;

    await Supabase.instance.client.from('inspection_sessions').update({
      'payload': payload,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('session_id', sessionId);
  }

  Future<void> _submit() async {
    if (_selectedImage == null || _imageBase64 == null) {
      _showMessage('請先拍照或從相簿選擇圖片', isError: true);
      return;
    }
    if (_aiResult == null) {
      _showMessage('請先等待 AI 生成結果', isError: true);
      return;
    }
    if (_selectedFloorPlan == null) {
      _showMessage('請先選擇樓層圖', isError: true);
      return;
    }
    if (_selectedPinX == null || _selectedPinY == null) {
      _showMessage('請在樓層圖上點選 pin 位置', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final reportNotifier = ref.read(reportNotifierProvider.notifier);
      final connectivity = ref.read(connectivityNotifierProvider);
      final navigation = ref.read(navigationNotifierProvider.notifier);

      final title = (_aiResult?['title'] as String?)?.trim();
      final description = _extractAiText().trim();
      final category = (_aiResult?['category'] as String?) ?? 'structural';
      final severity = (_aiResult?['severity'] as String?) ?? 'moderate';

      final saved = await reportNotifier.addReport(
        title: (title?.isNotEmpty ?? false) ? title! : '建築安全問題',
        description: description.isNotEmpty ? description : 'AI 分析結果',
        category: category,
        severity: severity,
        imagePath: _selectedImage!.path,
        imageBase64: _imageBase64,
        location: _locationTextController.text.trim(),
        latitude: _selectedPinX,
        longitude: _selectedPinY,
        isOnline: connectivity.isOnline,
        precomputedAnalysis: _aiResult,
      );

      if (!mounted) return;
      if (saved != null) {
        await _appendPinToSelectedSession();
        _showMessage('報告已提交');
        setState(() {
          _selectedImage = null;
          _selectedImageBytes = null;
          _imageBase64 = null;
          _aiResult = null;
          _selectedPinX = null;
          _selectedPinY = null;
        });
        navigation.goToHistory();
      } else {
        _showMessage(ref.read(reportNotifierProvider).error ?? '提交失敗',
            isError: true);
      }
    } catch (e) {
      _showMessage('提交失敗: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _extractAiText() {
    return (_aiResult?['analysis'] ??
            _aiResult?['formatted_report'] ??
            _aiResult?['description'] ??
            '')
        .toString();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('選擇樓層圖來源', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_isLoadingFloorPlans)
            const LinearProgressIndicator()
          else if (_floorPlanOptions.isEmpty)
            Text(
              '未找到樓層圖資料（可先到 Web 樓層圖管理上傳）',
              style: TextStyle(color: Colors.grey.shade600),
            )
          else ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedFolder,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                labelText: 'Folder / 建築名稱',
              ),
              items: _folderOptions
                  .map((folder) => DropdownMenuItem<String>(
                        value: folder,
                        child: Text(folder),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedFolder = value;
                  _selectedPinX = null;
                  _selectedPinY = null;
                  final filtered = _filteredFloorPlanOptions;
                  _selectedFloorPlan =
                      filtered.isNotEmpty ? filtered.first : null;
                  _locationTextController.text = _selectedFloorPlan == null
                      ? ''
                      : '${_selectedFloorPlan!['buildingName']} / ${_selectedFloorPlan!['label']} - 未選 pin';
                });
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<Map<String, dynamic>>(
              initialValue: _selectedFloorPlan,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                labelText: '樓層圖',
              ),
              items: _filteredFloorPlanOptions
                  .map((item) => DropdownMenuItem<Map<String, dynamic>>(
                        value: item,
                        child: Text(item['label'] as String),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedFloorPlan = value;
                  _selectedPinX = null;
                  _selectedPinY = null;
                  _locationTextController.text =
                      '${value['buildingName']} / ${value['label']} - 未選 pin';
                });
              },
            ),
          ],
          if (_selectedFloorPlan == null) ...[
            const SizedBox(height: 10),
            Text(
              '請先選擇 folder 及樓層圖，之後才可拍照與選 pin 上報。',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('拍照'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('相簿'),
                  ),
                ),
              ],
            ),
            if (_selectedImageBytes != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  _selectedImageBytes!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            if (_isAnalyzing) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('AI 生成中...'),
                ],
              ),
            ],
            if (_aiResult != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _aiResult!['_ai_mode'] == 'local_fallback'
                      ? Colors.orange.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _aiResult!['_ai_mode'] == 'local_fallback'
                        ? Colors.orange.shade200
                        : Colors.green.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _aiResult!['_ai_mode'] == 'local_fallback'
                          ? Icons.info
                          : Icons.check_circle,
                      color: _aiResult!['_ai_mode'] == 'local_fallback'
                          ? Colors.orange
                          : Colors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _aiResult!['_ai_mode'] == 'local_fallback'
                                ? '本地評估: ${_aiResult?['title'] ?? '已分析'}'
                                : 'AI 分析: ${_aiResult?['title'] ?? '已分析'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (_aiResult!['_ai_mode'] == 'local_fallback')
                            Text(
                              '(網絡或地區限制)',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade700,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            const Text('當前位置', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (((_selectedFloorPlan?['floorPlanUrl'] as String?)?.isNotEmpty ==
                    true) ||
                ((_selectedFloorPlan?['floorPlanBase64'] as String?)
                        ?.isNotEmpty ==
                    true)) ...[
              const SizedBox(height: 10),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onTapDown: (details) {
                        final local = details.localPosition;
                        final nx =
                            (local.dx / constraints.maxWidth).clamp(0.0, 1.0);
                        final ny =
                            (local.dy / constraints.maxHeight).clamp(0.0, 1.0);
                        setState(() {
                          _selectedPinX = nx * 100;
                          _selectedPinY = (1 - ny) * 100;
                          _locationTextController.text =
                              '${_selectedFloorPlan!['buildingName']} / ${_selectedFloorPlan!['label']} - Pin(${_selectedPinX!.toStringAsFixed(1)}, ${_selectedPinY!.toStringAsFixed(1)})';
                        });
                      },
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: (_selectedFloorPlan!['floorPlanUrl']
                                              as String?)
                                          ?.isNotEmpty ==
                                      true
                                  ? Image.network(
                                      _selectedFloorPlan!['floorPlanUrl']
                                          as String,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) {
                                        final fallback = (_selectedFloorPlan![
                                                'floorPlanBase64'] as String?)
                                            ?.trim();
                                        if (fallback != null &&
                                            fallback.isNotEmpty) {
                                          return Image.memory(
                                            base64Decode(fallback),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              color: Colors.grey.shade100,
                                              alignment: Alignment.center,
                                              child: const Text('樓層圖載入失敗'),
                                            ),
                                          );
                                        }
                                        return Container(
                                          color: Colors.grey.shade100,
                                          alignment: Alignment.center,
                                          child: const Text('樓層圖載入失敗'),
                                        );
                                      },
                                    )
                                  : Image.memory(
                                      base64Decode(
                                        _selectedFloorPlan!['floorPlanBase64']
                                            as String,
                                      ),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.grey.shade100,
                                        alignment: Alignment.center,
                                        child: const Text('樓層圖載入失敗'),
                                      ),
                                    ),
                            ),
                          ),
                          if (_selectedPinX != null && _selectedPinY != null)
                            Positioned(
                              left: constraints.maxWidth *
                                      (_selectedPinX! / 100) -
                                  10,
                              top: constraints.maxHeight *
                                      (1 - (_selectedPinY! / 100)) -
                                  10,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.place,
                                    size: 12, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _selectedPinX == null
                    ? '請點擊樓層圖以設定 pin 位置'
                    : '已選 pin: (${_selectedPinX!.toStringAsFixed(1)}, ${_selectedPinY!.toStringAsFixed(1)})',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _locationTextController,
              decoration: const InputDecoration(
                labelText: '位置文字（可修改）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send),
                label: Text(_isSubmitting ? '提交中...' : '生成報告並提交'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Chart helpers ───────────────────────────────────────────────────────────

String _calculateCompletionRate(Map<String, dynamic> stats) {
  final total = stats['total'] ?? 0;
  final resolved = stats['resolved'] ?? 0;
  if (total == 0) return '0%';
  return '${((resolved / total) * 100).toStringAsFixed(1)}%';
}

Widget _buildPieChart(Map<String, dynamic> stats) {
  final high = (stats['highRisk'] ?? 0).toDouble();
  final medium = (stats['mediumRisk'] ?? 0).toDouble();
  final low = (stats['lowRisk'] ?? 0).toDouble();
  final total = high + medium + low;

  if (total == 0) {
    return const Center(
      child: Text('暫無數據', style: TextStyle(color: Colors.grey)),
    );
  }

  return PieChart(
    PieChartData(
      sectionsSpace: 2,
      centerSpaceRadius: 40,
      sections: [
        PieChartSectionData(
          value: high,
          color: AppTheme.riskHigh,
          title: high > 0 ? '${(high / total * 100).toStringAsFixed(0)}%' : '',
          titleStyle: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          radius: 60,
        ),
        PieChartSectionData(
          value: medium,
          color: AppTheme.riskMedium,
          title:
              medium > 0 ? '${(medium / total * 100).toStringAsFixed(0)}%' : '',
          titleStyle: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          radius: 60,
        ),
        PieChartSectionData(
          value: low,
          color: AppTheme.riskLow,
          title: low > 0 ? '${(low / total * 100).toStringAsFixed(0)}%' : '',
          titleStyle: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          radius: 60,
        ),
      ],
    ),
  );
}

Widget _buildLineChart(List<Map<String, dynamic>> trendData) {
  if (trendData.isEmpty) {
    return const Center(
      child: Text('暫無數據', style: TextStyle(color: Colors.grey)),
    );
  }

  return LineChart(
    LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 1,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: Colors.grey.shade200, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (value, meta) => Text(
              value.toInt().toString(),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index >= 0 && index < trendData.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    trendData[index]['date'] ?? '',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: trendData
              .asMap()
              .entries
              .map((e) =>
                  FlSpot(e.key.toDouble(), (e.value['high'] ?? 0).toDouble()))
              .toList(),
          color: AppTheme.riskHigh,
          barWidth: 3,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
              show: true, color: AppTheme.riskHigh.withValues(alpha: 0.1)),
        ),
        LineChartBarData(
          spots: trendData
              .asMap()
              .entries
              .map((e) =>
                  FlSpot(e.key.toDouble(), (e.value['medium'] ?? 0).toDouble()))
              .toList(),
          color: AppTheme.riskMedium,
          barWidth: 3,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
              show: true, color: AppTheme.riskMedium.withValues(alpha: 0.1)),
        ),
        LineChartBarData(
          spots: trendData
              .asMap()
              .entries
              .map((e) =>
                  FlSpot(e.key.toDouble(), (e.value['low'] ?? 0).toDouble()))
              .toList(),
          color: AppTheme.riskLow,
          barWidth: 3,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
              show: true, color: AppTheme.riskLow.withValues(alpha: 0.1)),
        ),
      ],
    ),
  );
}

Widget _buildBarChart(Map<String, dynamic> stats) {
  final pending = (stats['pending'] ?? 0).toDouble();
  final inProgress =
      ((stats['total'] ?? 0) - pending - (stats['resolved'] ?? 0)).toDouble();
  final resolved = (stats['resolved'] ?? 0).toDouble();

  return BarChart(
    BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: [pending, inProgress, resolved].reduce((a, b) => a > b ? a : b) + 2,
      barGroups: [
        BarChartGroupData(x: 0, barRods: [
          BarChartRodData(
              toY: pending,
              color: Colors.orange,
              width: 40,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6))),
        ]),
        BarChartGroupData(x: 1, barRods: [
          BarChartRodData(
              toY: inProgress,
              color: Colors.blue,
              width: 40,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6))),
        ]),
        BarChartGroupData(x: 2, barRods: [
          BarChartRodData(
              toY: resolved,
              color: AppTheme.riskLow,
              width: 40,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6))),
        ]),
      ],
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (value, meta) => Text(
              value.toInt().toString(),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              const titles = ['待處理', '處理中', '已解決'];
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  titles[value.toInt()],
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12),
                ),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 1,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: Colors.grey.shade200, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
    ),
  );
}

// ─── Legend / summary widgets ─────────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(
          '$value',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
