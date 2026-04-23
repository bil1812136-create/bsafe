import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bsafe_app/theme/app_theme.dart';
import 'package:bsafe_app/screens/web/web_report_detail_screen.dart';
import 'package:intl/intl.dart';

/// 公司管理後台 — 主 Dashboard
class WebDashboardScreen extends StatefulWidget {
  const WebDashboardScreen({super.key});

  @override
  State<WebDashboardScreen> createState() => _WebDashboardScreenState();
}

class _WebDashboardScreenState extends State<WebDashboardScreen> {
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _floorPlans = [];
  final Set<String> _selectedReportIds = <String>{};
  bool _isLoading = true;
  bool _isFloorPlanLoading = true;
  bool _isUploadingFloorPlan = false;
  bool _isBatchDeletingReports = false;
  String? _selectedFloorPlanFolder;
  String? _deletingSessionId;
  String? _error;
  String? _floorPlanError;
  String _filterRiskLevel = 'all'; // 'all', 'high', 'medium', 'low'
  String _activeSection = 'reports'; // reports | floor_plans
  final TextEditingController _buildingNameController = TextEditingController();
  final TextEditingController _floorNumberController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  StreamSubscription<List<Map<String, dynamic>>>? _reportsSubscription;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadReports();
    _loadFloorPlans();
    _subscribeToReportsRealtime();
  }

  @override
  void dispose() {
    _reportsSubscription?.cancel();
    _buildingNameController.dispose();
    _floorNumberController.dispose();
    super.dispose();
  }

  void _subscribeToReportsRealtime() {
    _reportsSubscription?.cancel();
    _reportsSubscription =
        _supabase.from('reports').stream(primaryKey: ['id']).listen((_) {
      if (!mounted) return;
      _loadReports(silent: true);
    });
  }

  Future<void> _loadFloorPlans({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isFloorPlanLoading = true;
        _floorPlanError = null;
      });
    }

    try {
      final rows = await _supabase
          .from('inspection_sessions')
          .select('session_id, floor, floor_plan_path, payload, created_at')
          .order('created_at', ascending: false)
          .limit(100);

      if (!mounted) return;
      setState(() {
        _floorPlans = List<Map<String, dynamic>>.from(rows);
        final folders = _groupFloorPlansByBuilding(_floorPlans).keys.toList();
        if (_selectedFloorPlanFolder != null &&
            !folders.contains(_selectedFloorPlanFolder)) {
          _selectedFloorPlanFolder = null;
        }
        _isFloorPlanLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFloorPlanLoading = false;
        _floorPlanError = '載入樓層圖失敗: $e';
      });
    }
  }

  Future<void> _pickAndUploadFloorPlan() async {
    final buildingName = _buildingNameController.text.trim();
    final floorText = _floorNumberController.text.trim();
    final floorNumber = int.tryParse(floorText);
    if (buildingName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先輸入建築名稱（folder）')),
      );
      return;
    }
    if (floorNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先輸入正確樓層（數字）')),
      );
      return;
    }

    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 2500,
      maxHeight: 2500,
    );

    if (file == null) return;

    setState(() => _isUploadingFloorPlan = true);
    try {
      final bytes = await file.readAsBytes();
      final buildingFolder = buildingName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff_-]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      final path =
          'buildings/${buildingFolder.isEmpty ? 'default' : buildingFolder}/floor_${floorNumber}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      String? publicUrl;
      String? floorPlanPath;
      String? floorPlanBase64;

      try {
        await _supabase.storage.from('floor-plans').uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'image/jpeg',
              ),
            );
        publicUrl = _supabase.storage.from('floor-plans').getPublicUrl(path);
        floorPlanPath = path;
      } catch (storageError) {
        floorPlanBase64 = base64Encode(bytes);
        floorPlanPath = null;
        publicUrl = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Storage 無權限，已改為資料庫儲存樓層圖: $storageError',
              ),
            ),
          );
        }
      }

      final sessionId = 'web_${DateTime.now().millisecondsSinceEpoch}';
      await _supabase.from('inspection_sessions').insert({
        'session_id': sessionId,
        'name': '$buildingName - F$floorNumber',
        'project_id': 'web-dashboard',
        'floor': floorNumber,
        'floor_plan_path': floorPlanPath,
        'status': 'active',
        'payload': {
          'id': sessionId,
          'name': '$buildingName - F$floorNumber',
          'projectId': 'web-dashboard',
          'building_name': buildingName,
          'building_folder': buildingFolder,
          'floor': floorNumber,
          'floor_plan_url': publicUrl,
          'floorPlanPath': floorPlanPath,
          'floor_plan_base64': floorPlanBase64,
          'pins': [],
        },
      });

      if (!mounted) return;
      _floorNumberController.clear();
      await _loadFloorPlans(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('樓層圖已上傳並建立成功')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上傳失敗: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingFloorPlan = false);
    }
  }

  String? _resolveFloorPlanUrl(Map<String, dynamic> row) {
    final payload = row['payload'];
    if (payload is! Map) return null;
    final payloadMap = Map<String, dynamic>.from(payload);
    final direct = (payloadMap['floor_plan_url'] ?? payloadMap['floorPlanUrl'])
        ?.toString();
    if (direct != null && direct.isNotEmpty) {
      if (_looksLikeLocalPath(direct)) return null;
      if (direct.startsWith('http://') || direct.startsWith('https://')) {
        return _normalizeStorageObjectUrl(direct);
      }
      return _supabase.storage.from('floor-plans').getPublicUrl(direct);
    }

    final rowPath = row['floor_plan_path']?.toString();
    if (rowPath != null && rowPath.isNotEmpty) {
      if (_looksLikeLocalPath(rowPath)) return null;
      if (rowPath.startsWith('http://') || rowPath.startsWith('https://')) {
        return _normalizeStorageObjectUrl(rowPath);
      }
      if (rowPath.contains('buildings/')) {
        final idx = rowPath.indexOf('buildings/');
        if (idx >= 0) {
          final storagePath = rowPath.substring(idx);
          return _supabase.storage
              .from('floor-plans')
              .getPublicUrl(storagePath);
        }
      }
      return _supabase.storage.from('floor-plans').getPublicUrl(rowPath);
    }

    final path = (payloadMap['floorPlanPath'] ?? payloadMap['floor_plan_path'])
        ?.toString();
    if (path == null || path.isEmpty) return null;
    if (_looksLikeLocalPath(path)) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return _normalizeStorageObjectUrl(path);
    }
    if (path.contains('buildings/')) {
      final idx = path.indexOf('buildings/');
      if (idx >= 0) {
        final storagePath = path.substring(idx);
        return _supabase.storage.from('floor-plans').getPublicUrl(storagePath);
      }
    }
    return _supabase.storage.from('floor-plans').getPublicUrl(path);
  }

  String _normalizeStorageObjectUrl(String url) {
    if (!url.contains('/storage/v1/object/')) return url;
    if (url.contains('/storage/v1/object/public/')) return url;
    return url.replaceFirst(
        '/storage/v1/object/', '/storage/v1/object/public/');
  }

  bool _looksLikeLocalPath(String raw) {
    final value = raw.trim();
    final lower = value.toLowerCase();
    if (lower.startsWith('file://')) return true;
    if (lower.startsWith('/data/')) return true;
    if (lower.startsWith('/storage/')) return true;
    if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value)) return true;
    return false;
  }

  String? _resolveFloorPlanBase64(Map<String, dynamic> row) {
    final payload = row['payload'];
    if (payload is! Map) return null;
    final payloadMap = Map<String, dynamic>.from(payload);
    final raw =
        (payloadMap['floor_plan_base64'] ?? payloadMap['floorPlanBase64'])
            ?.toString();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  Uint8List? _decodeBase64Safe(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final cleaned = raw.contains(',') ? raw.split(',').last : raw;
      return base64Decode(cleaned);
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _extractPins(Map<String, dynamic> row) {
    final payload = Map<String, dynamic>.from(
      row['payload'] as Map<String, dynamic>? ?? {},
    );
    final pins = payload['pins'] as List<dynamic>? ?? const [];
    return pins
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  void _showFloorPlanPreviewDialog(Map<String, dynamic> row) {
    final imageUrl = _resolveFloorPlanUrl(row);
    final imageBase64 = _resolveFloorPlanBase64(row);
    final imageBytes = _decodeBase64Safe(imageBase64);
    final pins = _extractPins(row);

    showDialog(
      context: context,
      builder: (ctx) {
        Map<String, dynamic>? selectedPin;
        Map<String, dynamic>? selectedReport;

        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 1080,
            height: 620,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StatefulBuilder(
                builder: (context, setLocalState) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '樓層圖預覽與 Pin',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const Spacer(),
                          Text('Pins: ${pins.length}'),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _FloorPlanPreviewWithPins(
                                imageUrl: imageUrl,
                                imageBytes: imageBytes,
                                pins: pins,
                                selectedPinId: selectedPin?['id']?.toString(),
                                onPinTap: (pin) async {
                                  setLocalState(() {
                                    selectedPin = pin;
                                    selectedReport = null;
                                  });

                                  final linkedReport =
                                      await _findReportByPinAcrossData(
                                    row: row,
                                    pin: pin,
                                  );
                                  if (!mounted) return;
                                  if (linkedReport != null) {
                                    if (Navigator.of(ctx).canPop()) {
                                      Navigator.pop(ctx);
                                    }
                                    _openDetail(linkedReport);
                                    return;
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 330,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.borderColor),
                              ),
                              child: selectedPin == null
                                  ? Center(
                                      child: Text(
                                        '點擊地圖上的 Pin 可查看對應報告',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Pin ${selectedPin!['id'] ?? ''}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '座標: (${((selectedPin!['pin_x_percent'] ?? selectedPin!['pinXPercent']) as num?) != null ? (((selectedPin!['pin_x_percent'] ?? selectedPin!['pinXPercent']) as num).toDouble() * 100).toStringAsFixed(1) : (selectedPin!['x'] as num?)?.toStringAsFixed(1) ?? '-'}, ${((selectedPin!['pin_y_percent'] ?? selectedPin!['pinYPercent']) as num?) != null ? (((selectedPin!['pin_y_percent'] ?? selectedPin!['pinYPercent']) as num).toDouble() * 100).toStringAsFixed(1) : (selectedPin!['y'] as num?)?.toStringAsFixed(1) ?? '-'})',
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        if (selectedReport == null)
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color:
                                                      Colors.orange.shade200),
                                            ),
                                            child: const Text(
                                              '此 Pin 尚未找到對應報告。',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          )
                                        else ...[
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: AppTheme.borderColor),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _buildReportImagePreview(
                                                  selectedReport!,
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  selectedReport!['title']
                                                          ?.toString() ??
                                                      '未命名報告',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '狀態: ${selectedReport!['status'] ?? 'pending'}',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                Text(
                                                  '風險: ${selectedReport!['risk_level'] ?? '-'}',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '類別: ${_categoryLabel((selectedReport!["category"] ?? "").toString())}',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '基本資料: ${_singleLine(selectedReport!["description"]?.toString() ?? "")}',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'AI 報告: ${_singleLine(selectedReport!["ai_analysis"]?.toString() ?? "")}',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '跟進對話: ${_conversationSummary(selectedReport!)}',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                _openDetail(selectedReport!);
                                              },
                                              icon:
                                                  const Icon(Icons.open_in_new),
                                              label: const Text('開啟完整報告（可編輯）'),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '可編輯內容：基本資料、處理狀態、AI 報告、跟進對話、對應照片。',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Map<String, dynamic>? _findReportByPin({
    required Map<String, dynamic> row,
    required Map<String, dynamic> pin,
  }) {
    return _findReportByPinInSource(
      source: _reports,
      row: row,
      pin: pin,
    );
  }

  Future<Map<String, dynamic>?> _findReportByPinAcrossData({
    required Map<String, dynamic> row,
    required Map<String, dynamic> pin,
  }) async {
    final local =
        _findReportByPinInSource(source: _reports, row: row, pin: pin);
    if (local != null) return local;

    try {
      final rows = await _supabase
          .from('reports')
          .select()
          .order('created_at', ascending: false)
          .limit(500);
      final allReports = List<Map<String, dynamic>>.from(rows);
      return _findReportByPinInSource(source: allReports, row: row, pin: pin);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _findReportByPinInSource({
    required List<Map<String, dynamic>> source,
    required Map<String, dynamic> row,
    required Map<String, dynamic> pin,
  }) {
    final sessionId = row['session_id']?.toString();
    final pinId = pin['id']?.toString();
    final pinPercentX =
        ((pin['pin_x_percent'] ?? pin['pinXPercent']) as num?)?.toDouble();
    final pinPercentY =
        ((pin['pin_y_percent'] ?? pin['pinYPercent']) as num?)?.toDouble();
    final pinLegacyX = (pin['x'] as num?)?.toDouble();
    final pinLegacyY = (pin['y'] as num?)?.toDouble();

    if ((sessionId == null || sessionId.isEmpty) &&
        (pinId == null || pinId.isEmpty)) {
      return null;
    }

    for (final report in source) {
      final ref = _extractInspectionRefFromLocation(
        report['location']?.toString(),
      );
      final reportSessionId = ref['sessionId'] as String?;
      final reportPinId = ref['pinId'] as String?;

      final sameSession = sessionId != null && sessionId == reportSessionId;
      final samePin = pinId != null && pinId == reportPinId;

      if (sameSession && samePin) return report;
    }

    for (final report in source) {
      final ref = _extractInspectionRefFromLocation(
        report['location']?.toString(),
      );
      final reportPinId = ref['pinId'] as String?;
      if (pinId != null && pinId == reportPinId) {
        return report;
      }
    }

    for (final report in source) {
      final reportPinX = (report['pin_x_percent'] as num?)?.toDouble();
      final reportPinY = (report['pin_y_percent'] as num?)?.toDouble();
      if (pinPercentX == null || pinPercentY == null) continue;
      if (reportPinX == null || reportPinY == null) continue;

      final dx = (reportPinX - pinPercentX).abs();
      final dy = (reportPinY - pinPercentY).abs();
      if (dx <= 0.003 && dy <= 0.003) {
        return report;
      }
    }

    for (final report in source) {
      final reportX = (report['latitude'] as num?)?.toDouble();
      final reportY = (report['longitude'] as num?)?.toDouble();
      if (pinLegacyX == null || pinLegacyY == null) continue;
      if (reportX == null || reportY == null) continue;

      final dx = (reportX - pinLegacyX).abs();
      final dy = (reportY - pinLegacyY).abs();
      if (dx <= 0.8 && dy <= 0.8) {
        return report;
      }
    }

    return null;
  }

  String _extractBuildingNameFromRow(Map<String, dynamic> row) {
    final payload = Map<String, dynamic>.from(
      row['payload'] as Map<String, dynamic>? ?? {},
    );

    final explicit =
        (payload['building_name'] ?? payload['buildingName'])?.toString();
    if (explicit != null && explicit.trim().isNotEmpty) {
      return explicit.trim();
    }

    final path =
        (row['floor_plan_path'] ?? payload['floorPlanPath'])?.toString().trim();
    if (path != null && path.startsWith('buildings/')) {
      final parts = path.split('/');
      if (parts.length >= 2 && parts[1].isNotEmpty) {
        return parts[1];
      }
    }

    return '未分類';
  }

  Map<String, List<Map<String, dynamic>>> _groupFloorPlansByBuilding(
    List<Map<String, dynamic>> source,
  ) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final row in source) {
      final building = _extractBuildingNameFromRow(row);
      map.putIfAbsent(building, () => []).add(row);
    }
    final sortedKeys = map.keys.toList()..sort();
    return {for (final key in sortedKeys) key: map[key]!};
  }

  Future<void> _deleteFloorPlan(Map<String, dynamic> row) async {
    final sessionId = row['session_id']?.toString();
    if (sessionId == null || sessionId.isEmpty) return;

    final payload = Map<String, dynamic>.from(
      row['payload'] as Map<String, dynamic>? ?? {},
    );
    final floorPlanPath =
        (row['floor_plan_path'] ?? payload['floorPlanPath'])?.toString();

    setState(() => _deletingSessionId = sessionId);
    try {
      if (floorPlanPath != null && floorPlanPath.isNotEmpty) {
        try {
          await _supabase.storage.from('floor-plans').remove([floorPlanPath]);
        } catch (_) {
          // Ignore storage cleanup failures; DB deletion is still primary.
        }
      }

      await _supabase
          .from('inspection_sessions')
          .delete()
          .eq('session_id', sessionId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('樓層圖已刪除')),
      );
      await _loadFloorPlans(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刪除失敗: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingSessionId = null);
      }
    }
  }

  Future<void> _loadReports({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      var query = _supabase.from('reports').select();

      if (_filterRiskLevel != 'all') {
        query = query.eq('risk_level', _filterRiskLevel);
      }

      final data = await query.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _reports = List<Map<String, dynamic>>.from(data);
          final validIds = _reports
              .map((r) => r['id']?.toString())
              .whereType<String>()
              .toSet();
          _selectedReportIds.removeWhere((id) => !validIds.contains(id));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '載入失敗: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Row(
        children: [
          // ── 左側邊欄 ──
          _buildSidebar(),

          // ── 主內容區 ──
          Expanded(
            child: _activeSection == 'reports'
                ? Column(
                    children: [
                      _buildTopBar(screenWidth),
                      _buildStatsRow(),
                      _buildFilterBar(),
                      Expanded(child: _buildReportTable()),
                    ],
                  )
                : _buildFloorPlanManagement(),
          ),
        ],
      ),
    );
  }

  // ═══════════ 側邊欄 ═══════════

  Widget _buildSidebar() {
    return Container(
      width: 240,
      color: AppTheme.primaryDark,
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Logo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: const Row(
              children: [
                Icon(Icons.shield, color: Colors.white, size: 32),
                SizedBox(width: 12),
                Text(
                  'B-SAFE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '公司管理後台',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 40),
          // Nav items
          _sidebarItem(
            Icons.dashboard,
            '報告總覽',
            _activeSection == 'reports',
            onTap: () {
              setState(() => _activeSection = 'reports');
            },
          ),
          _sidebarItem(Icons.analytics, '統計分析', false),
          _sidebarItem(
            Icons.map,
            '樓層圖管理',
            _activeSection == 'floor_plans',
            onTap: () {
              setState(() => _activeSection = 'floor_plans');
              _loadFloorPlans();
            },
          ),
          _sidebarItem(Icons.settings, '設定', false),
          const Spacer(),
          // Connection status
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Supabase 已連接',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(
    IconData icon,
    String label,
    bool active, {
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: active ? Colors.white.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading:
            Icon(icon, color: active ? Colors.white : Colors.white54, size: 22),
        title: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white54,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        dense: true,
        onTap: onTap,
      ),
    );
  }

  Widget _buildFloorPlanManagement() {
    final grouped = _groupFloorPlansByBuilding(_floorPlans);
    final selectedRows = _selectedFloorPlanFolder == null
        ? <Map<String, dynamic>>[]
        : grouped[_selectedFloorPlanFolder] ?? <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          color: Colors.white,
          child: Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '樓層圖管理',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '上傳樓層圖供手機端選擇、加 pin 並上報',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                ],
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _loadFloorPlans,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('刷新'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 20, 32, 12),
          child: Row(
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _buildingNameController,
                  decoration: const InputDecoration(
                    labelText: '建築名稱 / Folder',
                    hintText: '例如: Building_A',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _floorNumberController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '樓層 (例如 3)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed:
                    _isUploadingFloorPlan ? null : _pickAndUploadFloorPlan,
                icon: _isUploadingFloorPlan
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(_isUploadingFloorPlan ? '上傳中...' : '上傳樓層圖'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isFloorPlanLoading
              ? const Center(child: CircularProgressIndicator())
              : _floorPlanError != null
                  ? Center(child: Text(_floorPlanError!))
                  : _floorPlans.isEmpty
                      ? const Center(child: Text('尚未有樓層圖'))
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: grouped.keys
                                      .map(
                                        (folder) => ChoiceChip(
                                          label: Text(
                                              '$folder (${grouped[folder]!.length})'),
                                          selected: _selectedFloorPlanFolder ==
                                              folder,
                                          onSelected: (_) {
                                            setState(() {
                                              _selectedFloorPlanFolder = folder;
                                            });
                                          },
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                            Expanded(
                              child: _selectedFloorPlanFolder == null
                                  ? const Center(
                                      child: Text('請先點選一個 folder 查看對應樓層圖'),
                                    )
                                  : selectedRows.isEmpty
                                      ? const Center(
                                          child: Text('此 folder 暫無樓層圖'))
                                      : ListView.separated(
                                          padding: const EdgeInsets.fromLTRB(
                                              32, 8, 32, 24),
                                          itemCount: selectedRows.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(height: 12),
                                          itemBuilder: (context, index) {
                                            final row = selectedRows[index];
                                            final floor = row['floor'] ?? '-';
                                            final payload =
                                                Map<String, dynamic>.from(
                                              row['payload'] as Map<String,
                                                      dynamic>? ??
                                                  {},
                                            );
                                            final buildingName = (payload[
                                                            'building_name'] ??
                                                        payload['buildingName'])
                                                    ?.toString() ??
                                                '未命名建築';
                                            final imageUrl =
                                                _resolveFloorPlanUrl(row);
                                            final imageBase64 =
                                                _resolveFloorPlanBase64(row);
                                            final imageBytes =
                                                _decodeBase64Safe(imageBase64);

                                            return Container(
                                              padding: const EdgeInsets.all(14),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                    color:
                                                        AppTheme.borderColor),
                                              ),
                                              child: LayoutBuilder(
                                                builder:
                                                    (context, constraints) {
                                                  final compact =
                                                      constraints.maxWidth <
                                                          760;

                                                  final Widget preview =
                                                      GestureDetector(
                                                    onTap: () =>
                                                        _showFloorPlanPreviewDialog(
                                                            row),
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      child: imageUrl != null
                                                          ? Image.network(
                                                              imageUrl,
                                                              width: compact
                                                                  ? constraints
                                                                      .maxWidth
                                                                  : 140,
                                                              height: 90,
                                                              fit: BoxFit.cover,
                                                              errorBuilder:
                                                                  (_, __, ___) {
                                                                if (imageBytes !=
                                                                    null) {
                                                                  return Image
                                                                      .memory(
                                                                    imageBytes,
                                                                    width: compact
                                                                        ? constraints
                                                                            .maxWidth
                                                                        : 140,
                                                                    height: 90,
                                                                    fit: BoxFit
                                                                        .cover,
                                                                    errorBuilder: (_,
                                                                            __,
                                                                            ___) =>
                                                                        Container(
                                                                      width: compact
                                                                          ? constraints
                                                                              .maxWidth
                                                                          : 140,
                                                                      height:
                                                                          90,
                                                                      color: Colors
                                                                          .grey
                                                                          .shade200,
                                                                      alignment:
                                                                          Alignment
                                                                              .center,
                                                                      child: const Text(
                                                                          '載入失敗'),
                                                                    ),
                                                                  );
                                                                }
                                                                return Container(
                                                                  width: compact
                                                                      ? constraints
                                                                          .maxWidth
                                                                      : 140,
                                                                  height: 90,
                                                                  color: Colors
                                                                      .grey
                                                                      .shade200,
                                                                  alignment:
                                                                      Alignment
                                                                          .center,
                                                                  child:
                                                                      const Text(
                                                                          '載入失敗'),
                                                                );
                                                              },
                                                            )
                                                          : imageBytes != null
                                                              ? Image.memory(
                                                                  imageBytes,
                                                                  width: compact
                                                                      ? constraints
                                                                          .maxWidth
                                                                      : 140,
                                                                  height: 90,
                                                                  fit: BoxFit
                                                                      .cover,
                                                                  errorBuilder: (_,
                                                                          __,
                                                                          ___) =>
                                                                      Container(
                                                                    width: compact
                                                                        ? constraints
                                                                            .maxWidth
                                                                        : 140,
                                                                    height: 90,
                                                                    color: Colors
                                                                        .grey
                                                                        .shade200,
                                                                    alignment:
                                                                        Alignment
                                                                            .center,
                                                                    child: const Text(
                                                                        '載入失敗'),
                                                                  ),
                                                                )
                                                              : Container(
                                                                  width: compact
                                                                      ? constraints
                                                                          .maxWidth
                                                                      : 140,
                                                                  height: 90,
                                                                  color: Colors
                                                                      .grey
                                                                      .shade200,
                                                                  alignment:
                                                                      Alignment
                                                                          .center,
                                                                  child:
                                                                      const Text(
                                                                          '無圖片'),
                                                                ),
                                                    ),
                                                  );

                                                  final Widget info = Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        '$buildingName - $floor F',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        'Session ID: ${row['session_id']}',
                                                        style: const TextStyle(
                                                          color: AppTheme
                                                              .textSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  );

                                                  final Widget deleteButton =
                                                      ElevatedButton.icon(
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                    onPressed:
                                                        _deletingSessionId ==
                                                                row['session_id']
                                                            ? null
                                                            : () async {
                                                                final ok =
                                                                    await showDialog<
                                                                            bool>(
                                                                          context:
                                                                              context,
                                                                          builder: (ctx) =>
                                                                              AlertDialog(
                                                                            title:
                                                                                const Text('刪除樓層圖'),
                                                                            content:
                                                                                Text(
                                                                              '確定刪除「$buildingName - $floor F」嗎？',
                                                                            ),
                                                                            actions: [
                                                                              TextButton(
                                                                                onPressed: () => Navigator.pop(ctx, false),
                                                                                child: const Text('取消'),
                                                                              ),
                                                                              ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                  backgroundColor: Colors.red,
                                                                                ),
                                                                                onPressed: () => Navigator.pop(ctx, true),
                                                                                child: const Text('刪除'),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ) ??
                                                                        false;
                                                                if (!ok) return;
                                                                await _deleteFloorPlan(
                                                                    row);
                                                              },
                                                    icon: _deletingSessionId ==
                                                            row['session_id']
                                                        ? const SizedBox(
                                                            width: 14,
                                                            height: 14,
                                                            child:
                                                                CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          )
                                                        : const Icon(Icons
                                                            .delete_outline),
                                                    label: Text(
                                                      _deletingSessionId ==
                                                              row['session_id']
                                                          ? '刪除中'
                                                          : '刪除',
                                                    ),
                                                  );

                                                  if (compact) {
                                                    return Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        preview,
                                                        const SizedBox(
                                                            height: 12),
                                                        info,
                                                        const SizedBox(
                                                            height: 10),
                                                        Align(
                                                          alignment: Alignment
                                                              .centerLeft,
                                                          child: deleteButton,
                                                        ),
                                                      ],
                                                    );
                                                  }

                                                  return Row(
                                                    children: [
                                                      preview,
                                                      const SizedBox(width: 14),
                                                      Expanded(child: info),
                                                      const SizedBox(width: 8),
                                                      deleteButton,
                                                    ],
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                        ),
                            ),
                          ],
                        ),
        ),
      ],
    );
  }

  // ═══════════ 頂部欄 ═══════════

  Widget _buildTopBar(double screenWidth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          const titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '報告總覽',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                '手機端上報的 AI 分析報告會自動同步到此頁面',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _loadReports,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('刷新'),
              ),
              Text(
                '共 ${_reports.length} 筆報告',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 12),
                actions,
              ],
            );
          }

          return Row(
            children: [
              titleBlock,
              const Spacer(),
              actions,
            ],
          );
        },
      ),
    );
  }

  // ═══════════ 統計卡 ═══════════

  Widget _buildStatsRow() {
    final total = _reports.length;
    final high = _reports.where((r) => r['risk_level'] == 'high').length;
    final medium = _reports.where((r) => r['risk_level'] == 'medium').length;
    final low = _reports.where((r) => r['risk_level'] == 'low').length;

    final cards = [
      _clickableStatCard(
        label: '全部報告',
        value: '$total',
        color: AppTheme.primaryColor,
        icon: Icons.description,
        isActive: _filterRiskLevel == 'all',
        onTap: () {
          setState(() => _filterRiskLevel = 'all');
          _loadReports();
        },
      ),
      _clickableStatCard(
        label: '高風險',
        value: '$high',
        color: AppTheme.riskHigh,
        icon: Icons.warning,
        isActive: _filterRiskLevel == 'high',
        onTap: () {
          setState(() => _filterRiskLevel = 'high');
          _loadReports();
        },
      ),
      _clickableStatCard(
        label: '中風險',
        value: '$medium',
        color: AppTheme.riskMedium,
        icon: Icons.info,
        isActive: _filterRiskLevel == 'medium',
        onTap: () {
          setState(() => _filterRiskLevel = 'medium');
          _loadReports();
        },
      ),
      _clickableStatCard(
        label: '低風險',
        value: '$low',
        color: AppTheme.riskLow,
        icon: Icons.check_circle,
        isActive: _filterRiskLevel == 'low',
        onTap: () {
          setState(() => _filterRiskLevel = 'low');
          _loadReports();
        },
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1100;
          if (compact) {
            final cardWidth =
                ((constraints.maxWidth - 16) / 2).clamp(220.0, 420.0);
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: cards
                  .map((card) =>
                      SizedBox(width: cardWidth.toDouble(), child: card))
                  .toList(),
            );
          }

          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 16),
              Expanded(child: cards[1]),
              const SizedBox(width: 16),
              Expanded(child: cards[2]),
              const SizedBox(width: 16),
              Expanded(child: cards[3]),
            ],
          );
        },
      ),
    );
  }

  Widget _clickableStatCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isActive
              ? Border.all(color: color, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isActive ? 0.08 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 170;
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            }

            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
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

  // ═══════════ 篩選欄 ═══════════

  Widget _buildFilterBar() {
    final selectedCount = _selectedReportIds.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Row(
        children: [
          const Text('風險等級:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          _filterChip('全部', 'all', _filterRiskLevel, (v) {
            setState(() => _filterRiskLevel = v);
            _loadReports();
          }),
          _filterChip('高風險', 'high', _filterRiskLevel, (v) {
            setState(() => _filterRiskLevel = v);
            _loadReports();
          }),
          _filterChip('中風險', 'medium', _filterRiskLevel, (v) {
            setState(() => _filterRiskLevel = v);
            _loadReports();
          }),
          _filterChip('低風險', 'low', _filterRiskLevel, (v) {
            setState(() => _filterRiskLevel = v);
            _loadReports();
          }),
          const Spacer(),
          if (_reports.isNotEmpty)
            TextButton.icon(
              onPressed: _toggleSelectAllReports,
              icon: Icon(
                _areAllReportsSelected
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 18,
              ),
              label: Text(_areAllReportsSelected ? '取消全選' : '全選'),
            ),
          const SizedBox(width: 8),
          if (selectedCount > 0)
            ElevatedButton.icon(
              onPressed:
                  _isBatchDeletingReports ? null : _confirmBatchDeleteReports,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              icon: _isBatchDeletingReports
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.delete_sweep_outlined, size: 18),
              label: Text(
                _isBatchDeletingReports ? '刪除中...' : '刪除已選取 ($selectedCount)',
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(
      String label, String value, String current, ValueChanged<String> onTap) {
    final active = current == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => onTap(value),
        selectedColor: AppTheme.primaryColor.withOpacity(0.15),
        checkmarkColor: AppTheme.primaryColor,
        labelStyle: TextStyle(
          color: active ? AppTheme.primaryColor : AppTheme.textSecondary,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  // ═══════════ 報告表格 ═══════════

  Widget _buildReportTable() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadReports, child: const Text('重試')),
          ],
        ),
      );
    }
    if (_reports.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox, size: 64, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text(
              '尚無報告',
              style: TextStyle(fontSize: 18, color: AppTheme.textSecondary),
            ),
            SizedBox(height: 8),
            Text(
              '手機端上報後會自動同步到此頁面（每15秒刷新一次）',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Container(
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: DataTable(
                showCheckboxColumn: false,
                headingRowColor: WidgetStateProperty.all(
                  AppTheme.primaryColor.withOpacity(0.05),
                ),
                columnSpacing: 16,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 56,
                columns: [
                  DataColumn(
                    label: Checkbox(
                      value: _areAllReportsSelected,
                      tristate: false,
                      onChanged: (_) => _toggleSelectAllReports(),
                    ),
                  ),
                  const DataColumn(
                      label: Text('#',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('標題',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('類別',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('風險等級',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('狀態',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('日期',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('操作',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _reports.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final report = entry.value;
                  return _buildRow(idx, report);
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(int index, Map<String, dynamic> report) {
    final reportId = report['id']?.toString();
    final isSelected =
        reportId != null && _selectedReportIds.contains(reportId);
    final riskLevel = report['risk_level'] ?? 'low';
    final riskColor = AppTheme.getRiskColor(riskLevel);
    final status = report['status'] ?? 'pending';
    final createdAt = report['created_at'] != null
        ? DateFormat('yyyy/MM/dd HH:mm')
            .format(AppTheme.toUtcPlus8(DateTime.parse(report['created_at'])))
        : '-';
    final category = _categoryLabel(report['category'] ?? '');

    return DataRow(
      selected: isSelected,
      onSelectChanged: reportId == null
          ? null
          : (selected) {
              setState(() {
                if (selected == true) {
                  _selectedReportIds.add(reportId);
                } else {
                  _selectedReportIds.remove(reportId);
                }
              });
            },
      cells: [
        DataCell(
          Checkbox(
            value: isSelected,
            onChanged: reportId == null
                ? null
                : (selected) {
                    setState(() {
                      if (selected == true) {
                        _selectedReportIds.add(reportId);
                      } else {
                        _selectedReportIds.remove(reportId);
                      }
                    });
                  },
          ),
        ),
        DataCell(Text('${index + 1}',
            style: const TextStyle(color: AppTheme.textSecondary))),
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              report['title'] ?? '無標題',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        DataCell(Text(category)),
        DataCell(Text(
          AppTheme.getRiskLabel(riskLevel),
          style: TextStyle(fontWeight: FontWeight.bold, color: riskColor),
        )),
        DataCell(_statusBadge(status)),
        DataCell(Text(
          createdAt,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        )),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility, size: 20),
                color: AppTheme.primaryColor,
                tooltip: '查看 / 編輯',
                onPressed: () => _openDetail(report),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: Colors.red.shade300,
                tooltip: '刪除',
                onPressed: () => _confirmDelete(report),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'resolved':
        color = Colors.green;
        label = '已解決';
        break;
      case 'in_progress':
        color = Colors.orange;
        label = '處理中';
        break;
      default:
        color = Colors.grey;
        label = '待處理';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 12)),
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

  void _openDetail(Map<String, dynamic> report) async {
    final edited = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WebReportDetailScreen(report: report),
      ),
    );
    if (edited == true) {
      _loadReports();
    }
  }

  bool get _areAllReportsSelected {
    if (_reports.isEmpty) return false;
    for (final report in _reports) {
      final id = report['id']?.toString();
      if (id == null || !_selectedReportIds.contains(id)) {
        return false;
      }
    }
    return true;
  }

  void _toggleSelectAllReports() {
    setState(() {
      if (_areAllReportsSelected) {
        _selectedReportIds.clear();
      } else {
        _selectedReportIds
          ..clear()
          ..addAll(
            _reports
                .map((report) => report['id']?.toString())
                .whereType<String>(),
          );
      }
    });
  }

  Future<void> _confirmBatchDeleteReports() async {
    final selectedReports = _reports
        .where(
            (report) => _selectedReportIds.contains(report['id']?.toString()))
        .toList();
    if (selectedReports.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('確認批次刪除'),
        content: Text(
          '確定要刪除 ${selectedReports.length} 筆報告嗎？\n\n將同時刪除這些報告對應的 Pin，且無法復原。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteReportsInBatch(selectedReports);
            },
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteReportsInBatch(
    List<Map<String, dynamic>> reports,
  ) async {
    setState(() => _isBatchDeletingReports = true);
    int success = 0;
    int failed = 0;

    for (final report in reports) {
      try {
        await _deleteSingleReportWithPin(report);
        success++;
      } catch (_) {
        failed++;
      }
    }

    if (!mounted) return;
    setState(() {
      _selectedReportIds.clear();
      _isBatchDeletingReports = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? '已刪除 $success 筆報告與對應 Pin'
              : '已刪除 $success 筆，失敗 $failed 筆',
        ),
      ),
    );
    _loadReports(silent: true);
  }

  void _confirmDelete(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('確認刪除'),
        content:
            Text('確定要刪除報告「${report['title']}」嗎？\n\n將同時刪除此報告對應的 Pin，且無法復原。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _deleteSingleReportWithPin(report);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('報告與對應 Pin 已刪除')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('刪除失敗: $e')),
                  );
                }
              } finally {
                _loadReports();
              }
            },
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSingleReportWithPin(Map<String, dynamic> report) async {
    await _deleteRelatedPinForReport(report);
    await _supabase.from('reports').delete().eq('id', report['id']);
  }

  Widget _buildReportImagePreview(Map<String, dynamic> report) {
    final imageUrl = report['image_url']?.toString();
    final imageBase64 = report['image_base64']?.toString();
    final decoded = _decodeBase64Safe(imageBase64);
    if ((imageUrl == null || imageUrl.isEmpty) && decoded == null) {
      return Container(
        height: 110,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderColor),
        ),
        alignment: Alignment.center,
        child: Text(
          '此報告無現場照片',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 110,
        width: double.infinity,
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  if (decoded == null) {
                    return Container(
                      color: Colors.grey.shade100,
                      alignment: Alignment.center,
                      child: Text(
                        '照片載入失敗',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12),
                      ),
                    );
                  }
                  return Image.memory(decoded, fit: BoxFit.cover);
                },
              )
            : Image.memory(decoded!, fit: BoxFit.cover),
      ),
    );
  }

  String _singleLine(String text) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return normalized.isEmpty ? '未填寫' : normalized;
  }

  String _conversationSummary(Map<String, dynamic> report) {
    final rawConversation = report['conversation'];
    if (rawConversation is List && rawConversation.isNotEmpty) {
      final last = rawConversation.last;
      if (last is Map) {
        final text = last['text']?.toString() ?? '';
        if (text.trim().isNotEmpty) return _singleLine(text);
      }
    }

    if (rawConversation is String && rawConversation.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawConversation);
        if (decoded is List && decoded.isNotEmpty) {
          final last = decoded.last;
          if (last is Map) {
            final text = last['text']?.toString() ?? '';
            if (text.trim().isNotEmpty) return _singleLine(text);
          }
        }
      } catch (_) {
        // Ignore invalid conversation JSON and fallback to legacy fields.
      }
    }

    final notes = report['company_notes']?.toString() ?? '';
    if (notes.trim().isNotEmpty) return _singleLine(notes);
    final worker = report['worker_response']?.toString() ?? '';
    if (worker.trim().isNotEmpty) return _singleLine(worker);
    return '尚無對話';
  }

  Future<void> _deleteRelatedPinForReport(Map<String, dynamic> report) async {
    final locationRef =
        _extractInspectionRefFromLocation(report['location'] as String?);
    final targetSessionId = locationRef['sessionId'] as String?;
    final targetPinId = locationRef['pinId'] as String?;
    final targetFloor = locationRef['floor'] as int?;

    final reportX = (report['latitude'] as num?)?.toDouble();
    final reportY = (report['longitude'] as num?)?.toDouble();

    final rows = await _supabase
        .from('inspection_sessions')
        .select('session_id, floor, payload');

    final sessions = List<Map<String, dynamic>>.from(rows);
    if (sessions.isEmpty) return;

    Map<String, dynamic>? targetRow;
    Map<String, dynamic>? targetSession;
    int? targetPinIndex;

    if (targetSessionId != null && targetSessionId.isNotEmpty) {
      for (final row in sessions) {
        final payload = Map<String, dynamic>.from(
            row['payload'] as Map<String, dynamic>? ?? {});
        final sessionId =
            (payload['id'] ?? row['session_id'])?.toString() ?? '';
        if (sessionId != targetSessionId) continue;

        final pins = (payload['pins'] as List<dynamic>? ?? [])
            .map((p) => Map<String, dynamic>.from(p as Map))
            .toList();

        if (targetPinId != null && targetPinId.isNotEmpty) {
          final idx = pins
              .indexWhere((p) => (p['id']?.toString() ?? '') == targetPinId);
          if (idx >= 0) {
            targetRow = row;
            targetSession = payload;
            targetPinIndex = idx;
            break;
          }
        }
      }
    }

    if (targetRow == null || targetSession == null || targetPinIndex == null) {
      double bestDistance = double.infinity;
      for (final row in sessions) {
        final payload = Map<String, dynamic>.from(
            row['payload'] as Map<String, dynamic>? ?? {});
        if (payload.isEmpty) continue;

        if (targetFloor != null) {
          final floor = (payload['floor'] as num?)?.toInt() ??
              (row['floor'] as num?)?.toInt();
          if (floor != null && floor != targetFloor) continue;
        }

        final pins = (payload['pins'] as List<dynamic>? ?? [])
            .map((p) => Map<String, dynamic>.from(p as Map))
            .toList();
        if (pins.isEmpty) continue;

        for (int i = 0; i < pins.length; i++) {
          final px = (pins[i]['x'] as num?)?.toDouble();
          final py = (pins[i]['y'] as num?)?.toDouble();
          if (reportX == null || reportY == null || px == null || py == null) {
            continue;
          }
          final dx = px - reportX;
          final dy = py - reportY;
          final distance = dx * dx + dy * dy;
          if (distance < bestDistance) {
            bestDistance = distance;
            targetRow = row;
            targetSession = payload;
            targetPinIndex = i;
          }
        }
      }
    }

    if (targetRow == null || targetSession == null || targetPinIndex == null) {
      return;
    }

    final rawPins =
        List<dynamic>.from(targetSession['pins'] as List<dynamic>? ?? []);
    if (targetPinIndex < 0 || targetPinIndex >= rawPins.length) return;

    rawPins.removeAt(targetPinIndex);
    targetSession['pins'] = rawPins;
    targetSession['updatedAt'] = DateTime.now().toUtc().toIso8601String();

    await _supabase.from('inspection_sessions').update({
      'payload': targetSession,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('session_id', targetRow['session_id']);
  }

  Map<String, dynamic> _extractInspectionRefFromLocation(String? location) {
    if (location == null || location.isEmpty) return {};

    final refIndex = location.indexOf('ref:');
    if (refIndex < 0) return {};

    final refText = location.substring(refIndex + 4).trim();
    final parts = refText.split(RegExp(r'[;,&]'));
    String? sessionId;
    String? pinId;
    int? floor;

    for (final part in parts) {
      final kv = part.split('=');
      if (kv.length != 2) continue;
      final key = kv[0].trim();
      final value = kv[1].trim();
      if ((key == 'session' || key == 'session_id' || key == 'sessionId') &&
          value.isNotEmpty) {
        sessionId = value;
      } else if ((key == 'pin' || key == 'pin_id' || key == 'pinId') &&
          value.isNotEmpty) {
        pinId = value;
      } else if (key == 'floor') {
        floor = int.tryParse(value);
      }
    }

    return {
      if (sessionId != null) 'sessionId': sessionId,
      if (pinId != null) 'pinId': pinId,
      if (floor != null) 'floor': floor,
    };
  }
}

class _FloorPlanPreviewWithPins extends StatefulWidget {
  final String? imageUrl;
  final Uint8List? imageBytes;
  final List<Map<String, dynamic>> pins;
  final String? selectedPinId;
  final ValueChanged<Map<String, dynamic>>? onPinTap;

  const _FloorPlanPreviewWithPins({
    required this.imageUrl,
    required this.imageBytes,
    required this.pins,
    this.selectedPinId,
    this.onPinTap,
  });

  @override
  State<_FloorPlanPreviewWithPins> createState() =>
      _FloorPlanPreviewWithPinsState();
}

class _FloorPlanPreviewWithPinsState extends State<_FloorPlanPreviewWithPins> {
  ImageProvider<Object>? _imageProvider;
  Size? _imageSize;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;

  Map<String, double> _resolveBounds() {
    if (widget.pins.isEmpty) {
      return {'minX': 0, 'maxX': 1, 'minY': 0, 'maxY': 1};
    }

    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final pin in widget.pins) {
      final x = (pin['x'] as num?)?.toDouble();
      final y = (pin['y'] as num?)?.toDouble();
      if (x == null || y == null) continue;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    if (!minX.isFinite || !maxX.isFinite || !minY.isFinite || !maxY.isFinite) {
      return {'minX': 0, 'maxX': 1, 'minY': 0, 'maxY': 1};
    }

    if ((maxX - minX).abs() < 0.0001) {
      minX -= 0.5;
      maxX += 0.5;
    }
    if ((maxY - minY).abs() < 0.0001) {
      minY -= 0.5;
      maxY += 0.5;
    }

    return {'minX': minX, 'maxX': maxX, 'minY': minY, 'maxY': maxY};
  }

  Offset? _pinPercentOffset(Map<String, dynamic> pin) {
    final percentX = (pin['pin_x_percent'] ?? pin['pinXPercent']) as num?;
    final percentY = (pin['pin_y_percent'] ?? pin['pinYPercent']) as num?;
    if (percentX == null || percentY == null) return null;
    return Offset(
      percentX.toDouble().clamp(0.0, 1.0),
      percentY.toDouble().clamp(0.0, 1.0),
    );
  }

  @override
  void initState() {
    super.initState();
    _imageProvider = widget.imageBytes != null
        ? MemoryImage(widget.imageBytes!) as ImageProvider<Object>
        : widget.imageUrl != null
            ? NetworkImage(widget.imageUrl!) as ImageProvider<Object>
            : null;
    _resolveImageSize();
  }

  @override
  void didUpdateWidget(covariant _FloorPlanPreviewWithPins oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.imageBytes != widget.imageBytes) {
      _imageProvider = widget.imageBytes != null
          ? MemoryImage(widget.imageBytes!) as ImageProvider<Object>
          : widget.imageUrl != null
              ? NetworkImage(widget.imageUrl!) as ImageProvider<Object>
              : null;
      _imageSize = null;
      _resolveImageSize();
    }
  }

  @override
  void dispose() {
    if (_imageStream != null && _imageStreamListener != null) {
      _imageStream!.removeListener(_imageStreamListener!);
    }
    super.dispose();
  }

  void _resolveImageSize() {
    final provider = _imageProvider;
    if (provider == null) return;

    final stream = provider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(() {
        _imageSize = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
      });
    });

    if (_imageStream != null && _imageStreamListener != null) {
      _imageStream!.removeListener(_imageStreamListener!);
    }
    _imageStream = stream;
    _imageStreamListener = listener;
    stream.addListener(listener);
  }

  Rect _containRect(Size boxSize, Size imageSize) {
    final boxAspect = boxSize.width / boxSize.height;
    final imageAspect = imageSize.width / imageSize.height;

    if (imageAspect > boxAspect) {
      final width = boxSize.width;
      final height = width / imageAspect;
      return Rect.fromLTWH(0, (boxSize.height - height) / 2, width, height);
    }

    final height = boxSize.height;
    final width = height * imageAspect;
    return Rect.fromLTWH((boxSize.width - width) / 2, 0, width, height);
  }

  @override
  Widget build(BuildContext context) {
    final provider = _imageProvider;
    if (provider == null) {
      return Container(
        color: Colors.grey.shade100,
        alignment: Alignment.center,
        child: const Text('無圖片'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = _resolveBounds();
        final minX = bounds['minX']!;
        final maxX = bounds['maxX']!;
        final minY = bounds['minY']!;
        final maxY = bounds['maxY']!;
        final spanX = (maxX - minX).abs() < 0.0001 ? 1.0 : (maxX - minX);
        final spanY = (maxY - minY).abs() < 0.0001 ? 1.0 : (maxY - minY);
        final rect = _imageSize == null
            ? Rect.fromLTWH(0, 0, constraints.maxWidth, constraints.maxHeight)
            : _containRect(
                Size(constraints.maxWidth, constraints.maxHeight),
                _imageSize!,
              );

        return Container(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          color: Colors.grey.shade100,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image(
                  image: provider,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text('樓層圖載入失敗'),
                  ),
                ),
              ),
              if (_imageSize != null)
                ...widget.pins.map((pin) {
                  final percentOffset = _pinPercentOffset(pin);
                  final xValue = (pin['x'] as num?)?.toDouble();
                  final yValue = (pin['y'] as num?)?.toDouble();
                  if (percentOffset == null &&
                      (xValue == null || yValue == null)) {
                    return const SizedBox.shrink();
                  }

                  final nx = percentOffset?.dx ??
                      ((xValue! - minX) / spanX).clamp(0.0, 1.0);
                  final ny = percentOffset?.dy ??
                      ((yValue! - minY) / spanY).clamp(0.0, 1.0);
                  final left = rect.left + rect.width * nx;
                  final top = percentOffset == null
                      ? rect.top + rect.height * (1 - ny)
                      : rect.top + rect.height * ny;

                  return Positioned(
                    left: left - 9,
                    top: top - 9,
                    child: Tooltip(
                      message: percentOffset != null
                          ? 'Pin ${pin['id'] ?? ''} (${(nx * 100).toStringAsFixed(1)}%, ${(ny * 100).toStringAsFixed(1)}%)'
                          : 'Pin ${pin['id'] ?? ''} (${xValue!.toStringAsFixed(1)}, ${yValue!.toStringAsFixed(1)})',
                      child: GestureDetector(
                        onTap: widget.onPinTap == null
                            ? null
                            : () => widget.onPinTap!(pin),
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: widget.selectedPinId == pin['id']?.toString()
                                ? AppTheme.primaryColor
                                : Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
