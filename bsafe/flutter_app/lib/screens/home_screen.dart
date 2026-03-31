import 'dart:convert';
import 'dart:typed_data';
import 'package:bsafe_app/providers/connectivity_provider.dart';
import 'package:bsafe_app/providers/language_provider.dart';
import 'package:bsafe_app/providers/navigation_provider.dart';
import 'package:bsafe_app/providers/report_provider.dart';
import 'package:bsafe_app/theme/app_theme.dart';
import 'package:bsafe_app/widgets/shimmer_loading.dart';
import 'package:bsafe_app/widgets/stat_card.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    return Scaffold(
      body: Consumer<ReportProvider>(
        builder: (context, reportProvider, _) {
          if (reportProvider.isLoading && reportProvider.reports.isEmpty) {
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

          final stats = reportProvider.statistics;

          return RefreshIndicator(
            onRefresh: () => reportProvider.loadReports(),
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
                        if (reportProvider.pendingSyncCount > 0) ...[
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
                                const Icon(
                                  Icons.sync,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${reportProvider.pendingSyncCount} ${language.t('pending_sync_suffix')}',
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
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Consumer<NavigationProvider>(
                    builder: (context, navProvider, _) {
                      return Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              title: language.t('high_risk'),
                              value: '${stats['highRisk'] ?? 0}',
                              icon: Icons.warning_amber_rounded,
                              color: AppTheme.riskHigh,
                              isClickable: true,
                              onTap: () =>
                                  navProvider.goToHistory(filterRisk: 'high'),
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
                              onTap: () => navProvider.goToHistory(
                                filterRisk: 'medium',
                              ),
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
                              onTap: () =>
                                  navProvider.goToHistory(filterRisk: 'low'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Consumer<NavigationProvider>(
                    builder: (context, navProvider, _) {
                      return Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              title: language.t('pending'),
                              value: '${stats['pending'] ?? 0}',
                              icon: Icons.pending_actions,
                              color: Colors.blue,
                              isClickable: true,
                              onTap: () =>
                                  navProvider.goToHistoryByStatus('pending'),
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
                              onTap: () => navProvider
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
                              onTap: () =>
                                  navProvider.goToHistoryByStatus('resolved'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    language.t('quick_report'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

class _HomeQuickReportPanel extends StatefulWidget {
  const _HomeQuickReportPanel();

  @override
  State<_HomeQuickReportPanel> createState() => _HomeQuickReportPanelState();
}

class _HomeQuickReportPanelState extends State<_HomeQuickReportPanel> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _locationTextController = TextEditingController();

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _imageBase64;
  bool _isAnalyzing = false;
  bool _isSubmitting = false;
  bool _isLoadingFloorPlans = true;
  Map<String, dynamic>? _aiResult;
  List<Map<String, dynamic>> _floorPlanOptions = [];
  Map<String, dynamic>? _selectedFloorPlan;
  double? _selectedPinX;
  double? _selectedPinY;

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
      final reportProvider = context.read<ReportProvider>();
      final result = await reportProvider.analyzeImage(_imageBase64!);
      if (!mounted) return;

      setState(() {
        _aiResult = result;
      });

      // Different feedback based on analysis mode
      if (result != null && result['_ai_mode'] == 'local_fallback') {
        _showMessage('✓ 已使用本地評估（因網絡或地區限制）', isError: false);
      } else {
        _showMessage('✓ AI 分析完成，可直接提交', isError: false);
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

        options.add({
          'session_id': row['session_id'],
          'label': 'F$floorNumber',
          'floorNumber': floorNumber,
          'floorPlanUrl': resolvedUrl,
          'floorPlanBase64': floorPlanBase64,
          'payload': payload,
        });
      }

      if (!mounted) return;
      setState(() {
        _floorPlanOptions = options;
        _selectedFloorPlan = options.isNotEmpty ? options.first : null;
        if (_selectedFloorPlan != null) {
          _locationTextController.text =
              '${_selectedFloorPlan!['label']} - 未選 pin';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
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
      'updated_at': DateTime.now().toIso8601String()
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
      final reportProvider = context.read<ReportProvider>();
      final connectivity = context.read<ConnectivityProvider>();
      final navigation = context.read<NavigationProvider>();

      final title = (_aiResult?['title'] as String?)?.trim();
      final description = _extractAiText().trim();
      final category = (_aiResult?['category'] as String?) ?? 'structural';
      final severity = (_aiResult?['severity'] as String?) ?? 'moderate';

      final saved = await reportProvider.addReport(
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
        _showMessage(reportProvider.error ?? '提交失敗', isError: true);
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
          if (_isLoadingFloorPlans)
            const LinearProgressIndicator()
          else if (_floorPlanOptions.isEmpty)
            Text(
              '未找到樓層圖資料（可先到 Web 樓層圖管理上傳）',
              style: TextStyle(color: Colors.grey.shade600),
            )
          else
            DropdownButtonFormField<Map<String, dynamic>>(
              initialValue: _selectedFloorPlan,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _floorPlanOptions
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
                  _locationTextController.text = '${value['label']} - 未選 pin';
                });
              },
            ),
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
                            '${_selectedFloorPlan!['label']} - Pin(${_selectedPinX!.toStringAsFixed(1)}, ${_selectedPinY!.toStringAsFixed(1)})';
                      });
                    },
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child:
                                (_selectedFloorPlan!['floorPlanUrl'] as String?)
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
                            left:
                                constraints.maxWidth * (_selectedPinX! / 100) -
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
                              child: const Icon(
                                Icons.place,
                                size: 12,
                                color: Colors.white,
                              ),
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
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(_isSubmitting ? '提交中...' : '生成報告並提交'),
            ),
          ),
        ],
      ),
    );
  }
}
