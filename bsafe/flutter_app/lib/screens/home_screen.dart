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
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
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
    Map<String, dynamic> payload,
    String? floorPlanPath,
  ) {
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

    return 'Uncategorized';
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
      _showMessage('Unable to select image: $e', isError: true);
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
        _showMessage('✓ Local assessment used (network or region limitation)',
            isError: false);
      } else {
        _showMessage('✓ AI analysis completed, ready to submit',
            isError: false);
      }
    } catch (e) {
      _showMessage('Analysis encountered an issue: $e', isError: true);
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
              '${_selectedFloorPlan!['buildingName']} / ${_selectedFloorPlan!['label']} - No pin selected';
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

  int? _parseFloorNumber(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    final match = RegExp(r'-?\d+').firstMatch(value.toString());
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  bool? _toBool(dynamic value) {
    if (value is bool) return value;
    if (value == null) return null;
    final text = value.toString().toLowerCase();
    if (text == 'true') return true;
    if (text == 'false') return false;
    return null;
  }

  String _stripRefSuffix(String text) {
    final trimmed = text.trim();
    final refIndex = trimmed.indexOf('ref:');
    if (refIndex < 0) return trimmed;
    final base = trimmed.substring(0, refIndex).trim();
    return base.replaceFirst(RegExp(r'[;,\s]+$'), '');
  }

  Map<String, double>? _resolveBoundsFromPins(
    List<dynamic> pins, {
    double? extraX,
    double? extraY,
  }) {
    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    void applyPoint(double? x, double? y) {
      if (x == null || y == null) return;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    for (final pin in pins) {
      if (pin is! Map) continue;
      applyPoint(_toDouble(pin['x']), _toDouble(pin['y']));
    }
    applyPoint(extraX, extraY);

    if (!minX.isFinite || !maxX.isFinite || !minY.isFinite || !maxY.isFinite) {
      return null;
    }

    if ((maxX - minX).abs() < 0.0001) {
      minX -= 0.5;
      maxX += 0.5;
    }
    if ((maxY - minY).abs() < 0.0001) {
      minY -= 0.5;
      maxY += 0.5;
    }

    return {
      'minX': minX,
      'maxX': maxX,
      'minY': minY,
      'maxY': maxY,
    };
  }

  double? _payloadDouble(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final value = _toDouble(payload[key]);
      if (value != null) return value;
    }
    return null;
  }

  bool? _payloadBool(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final value = _toBool(payload[key]);
      if (value != null) return value;
    }
    return null;
  }

  String _buildLocationWithRef({
    required String baseLocation,
    required String sessionId,
    required String pinId,
    required int? floorNumber,
    required Map<String, dynamic> payload,
    required List<dynamic> existingPins,
    required double pinX,
    required double pinY,
    double? pinXPercent,
    double? pinYPercent,
  }) {
    final refParts = <String>[
      'session=$sessionId',
      'pin=$pinId',
      if (floorNumber != null) 'floor=$floorNumber',
    ];

    final bounds = _resolveBoundsFromPins(
      existingPins,
      extraX: pinX,
      extraY: pinY,
    );
    if (bounds != null) {
      refParts.addAll([
        'minX=${bounds['minX']}',
        'maxX=${bounds['maxX']}',
        'minY=${bounds['minY']}',
        'maxY=${bounds['maxY']}',
      ]);
    }

    final xOffset = _payloadDouble(payload, const ['xOffset', 'x_offset']);
    final yOffset = _payloadDouble(payload, const ['yOffset', 'y_offset']);
    final xScale = _payloadDouble(payload, const ['xScale', 'x_scale']);
    final yScale = _payloadDouble(payload, const ['yScale', 'y_scale']);
    final flipX = _payloadBool(payload, const ['flipX', 'flip_x']);
    final flipY = _payloadBool(payload, const ['flipY', 'flip_y']);

    if (xOffset != null) refParts.add('xOffset=$xOffset');
    if (yOffset != null) refParts.add('yOffset=$yOffset');
    if (xScale != null) refParts.add('xScale=$xScale');
    if (yScale != null) refParts.add('yScale=$yScale');
    if (flipX != null) refParts.add('flipX=$flipX');
    if (flipY != null) refParts.add('flipY=$flipY');
    if (pinXPercent != null) {
      refParts.add('pinXPercent=${pinXPercent.toStringAsFixed(6)}');
    }
    if (pinYPercent != null) {
      refParts.add('pinYPercent=${pinYPercent.toStringAsFixed(6)}');
    }

    final cleanBase = _stripRefSuffix(baseLocation);
    if (cleanBase.isEmpty) {
      return 'ref:${refParts.join(';')}';
    }
    return '$cleanBase; ref:${refParts.join(';')}';
  }

  Future<void> _appendPinToSelectedSession({
    required String pinId,
    required String pinNote,
  }) async {
    if (_selectedFloorPlan == null ||
        _selectedPinX == null ||
        _selectedPinY == null) {
      return;
    }

    final sessionId = _selectedFloorPlan!['session_id'];
    final rawPayload = _selectedFloorPlan!['payload'];
    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : <String, dynamic>{};
    final pins = List<dynamic>.from(payload['pins'] as List<dynamic>? ?? []);

    final aiText = _extractAiText();
    final pinXPercent = (_selectedPinX! / 100.0).clamp(0.0, 1.0).toDouble();
    final pinYPercent =
        (1.0 - (_selectedPinY! / 100.0)).clamp(0.0, 1.0).toDouble();

    pins.add({
      'id': pinId,
      'x': _selectedPinX,
      'y': _selectedPinY,
      'pin_x_percent': pinXPercent,
      'pin_y_percent': pinYPercent,
      'note': pinNote,
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

    if (mounted && _selectedFloorPlan != null) {
      setState(() {
        _selectedFloorPlan = {
          ..._selectedFloorPlan!,
          'payload': payload,
        };
      });
    }
  }

  Future<void> _removePinFromSelectedSession(String pinId) async {
    if (_selectedFloorPlan == null) return;

    final sessionId = _selectedFloorPlan!['session_id']?.toString();
    if (sessionId == null || sessionId.isEmpty) return;

    final row = await Supabase.instance.client
        .from('inspection_sessions')
        .select('payload')
        .eq('session_id', sessionId)
        .maybeSingle();
    if (row == null) return;

    final rawPayload = row['payload'];
    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : <String, dynamic>{};
    final pins = List<dynamic>.from(payload['pins'] as List<dynamic>? ?? []);
    final originalLength = pins.length;
    pins.removeWhere((pin) => pin is Map && pin['id']?.toString() == pinId);
    if (pins.length == originalLength) return;

    payload['pins'] = pins;

    await Supabase.instance.client.from('inspection_sessions').update({
      'payload': payload,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('session_id', sessionId);

    if (mounted && _selectedFloorPlan != null) {
      setState(() {
        _selectedFloorPlan = {
          ..._selectedFloorPlan!,
          'payload': payload,
        };
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedImage == null || _imageBase64 == null) {
      _showMessage('Please take a photo or select one from gallery first',
          isError: true);
      return;
    }
    if (_aiResult == null) {
      _showMessage('Please wait for AI results first', isError: true);
      return;
    }
    if (_selectedFloorPlan == null) {
      _showMessage('Please select a floor plan first', isError: true);
      return;
    }
    if (_selectedPinX == null || _selectedPinY == null) {
      _showMessage('Please tap a pin location on the floor plan',
          isError: true);
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
      final pinXPercent = (_selectedPinX! / 100.0).clamp(0.0, 1.0).toDouble();
      final pinYPercent =
          (1.0 - (_selectedPinY! / 100.0)).clamp(0.0, 1.0).toDouble();
      final selectedFloorPlan = _selectedFloorPlan!;
      final sessionId =
          (selectedFloorPlan['session_id'] ?? '').toString().trim();
      if (sessionId.isEmpty) {
        _showMessage(
            'Floor plan data missing session_id, please reselect floor plan',
            isError: true);
        return;
      }

      final rawPayload = selectedFloorPlan['payload'];
      final payload = rawPayload is Map
          ? Map<String, dynamic>.from(rawPayload)
          : <String, dynamic>{};
      final pins = List<dynamic>.from(payload['pins'] as List<dynamic>? ?? []);
      final floorNumber = _parseFloorNumber(
        selectedFloorPlan['floorNumber'] ?? selectedFloorPlan['label'],
      );

      final pinId = 'rp_${DateTime.now().millisecondsSinceEpoch}';
      final defaultLocation =
          '${selectedFloorPlan['buildingName']} / ${selectedFloorPlan['label']} - Pin(${_selectedPinX!.toStringAsFixed(1)}, ${_selectedPinY!.toStringAsFixed(1)})';
      final locationBase =
          _stripRefSuffix(_locationTextController.text).isNotEmpty
              ? _stripRefSuffix(_locationTextController.text)
              : defaultLocation;
      final locationWithRef = _buildLocationWithRef(
        baseLocation: locationBase,
        sessionId: sessionId,
        pinId: pinId,
        floorNumber: floorNumber,
        payload: payload,
        existingPins: pins,
        pinX: _selectedPinX!,
        pinY: _selectedPinY!,
        pinXPercent: pinXPercent,
        pinYPercent: pinYPercent,
      );

      await _appendPinToSelectedSession(pinId: pinId, pinNote: locationBase);

      final saved = await reportProvider.addReport(
        title: (title?.isNotEmpty ?? false) ? title! : 'Building Safety Issue',
        description:
            description.isNotEmpty ? description : 'AI Analysis Result',
        category: category,
        severity: severity,
        imagePath: _selectedImage!.path,
        imageBase64: _imageBase64,
        location: locationWithRef,
        latitude: _selectedPinX,
        longitude: _selectedPinY,
        isOnline: connectivity.isOnline,
        precomputedAnalysis: _aiResult,
      );

      if (!mounted) return;
      if (saved != null) {
        _showMessage('Report submitted');
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
        try {
          await _removePinFromSelectedSession(pinId);
        } catch (_) {
          // Best-effort rollback to avoid dangling pins when report save fails.
        }
        _showMessage(reportProvider.error ?? 'Submission failed',
            isError: true);
      }
    } catch (e) {
      _showMessage('Submission failed: $e', isError: true);
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
          const Text('Choose Floor Plan Source',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_isLoadingFloorPlans)
            const LinearProgressIndicator()
          else if (_floorPlanOptions.isEmpty)
            Text(
              'No floor plan data found (upload from Web Floor Plan Management first)',
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
                labelText: 'Folder / Building Name',
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
                      : '${_selectedFloorPlan!['buildingName']} / ${_selectedFloorPlan!['label']} - No pin selected';
                });
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedFloorPlan?['session_id']?.toString(),
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                labelText: 'Floor Plan',
              ),
              items: _filteredFloorPlanOptions
                  .map((item) => DropdownMenuItem<String>(
                        value: item['session_id']?.toString(),
                        child: Text(item['label'] as String),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedFloorPlan = _filteredFloorPlanOptions.firstWhere(
                    (item) => item['session_id']?.toString() == value,
                    orElse: () => _filteredFloorPlanOptions.first,
                  );
                  _selectedPinX = null;
                  _selectedPinY = null;
                  _locationTextController.text =
                      '${_selectedFloorPlan!['buildingName']} / ${_selectedFloorPlan!['label']} - No pin selected';
                });
              },
            ),
          ],
          if (_selectedFloorPlan == null) ...[
            const SizedBox(height: 10),
            Text(
              'Please select a folder and floor plan first, then take photos and pin for reporting.',
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
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
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
                  Text('AI is generating...'),
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
                                ? 'Local Assessment: ${_aiResult?['title'] ?? 'Analyzed'}'
                                : 'AI Analysis: ${_aiResult?['title'] ?? 'Analyzed'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (_aiResult!['_ai_mode'] == 'local_fallback')
                            Text(
                              '(Network or region limitation)',
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
            const Text('Current Location',
                style: TextStyle(fontWeight: FontWeight.bold)),
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
                                              child: const Text(
                                                  'Failed to load floor plan'),
                                            ),
                                          );
                                        }
                                        return Container(
                                          color: Colors.grey.shade100,
                                          alignment: Alignment.center,
                                          child: const Text(
                                              'Failed to load floor plan'),
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
                                        child: const Text(
                                            'Failed to load floor plan'),
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
                    ? 'Tap floor plan to set pin location'
                    : 'Selected pin: (${_selectedPinX!.toStringAsFixed(1)}, ${_selectedPinY!.toStringAsFixed(1)})',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
              if (_selectedPinX != null && _selectedPinY != null)
                Text(
                  'normalized: x=${(_selectedPinX! / 100).toStringAsFixed(4)}, y=${(1 - (_selectedPinY! / 100)).toStringAsFixed(4)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _locationTextController,
              decoration: const InputDecoration(
                labelText: 'Location text (editable)',
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
                label: Text(_isSubmitting
                    ? 'Submitting...'
                    : 'Generate Report and Submit'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}
