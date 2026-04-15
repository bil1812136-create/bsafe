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
  bool _isLoading = true;
  bool _isFloorPlanLoading = true;
  bool _isUploadingFloorPlan = false;
  String? _selectedFloorPlanFolder;
  String? _deletingSessionId;
  String? _error;
  String? _floorPlanError;
  String _filterRiskLevel = 'all'; // 'all', 'high', 'medium', 'low'
  String _activeSection = 'reports'; // reports | floor_plans
  final TextEditingController _buildingNameController = TextEditingController();
  final TextEditingController _floorNumberController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  Timer? _refreshTimer;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadReports();
    _loadFloorPlans();
    // 每 15 秒自動刷新（接收手機端新報告）
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadReports(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _buildingNameController.dispose();
    _floorNumberController.dispose();
    super.dispose();
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
      if (direct.startsWith('http://') || direct.startsWith('https://')) {
        return direct;
      }
      return _supabase.storage.from('floor-plans').getPublicUrl(direct);
    }

    final rowPath = row['floor_plan_path']?.toString();
    if (rowPath != null && rowPath.isNotEmpty) {
      if (rowPath.startsWith('http://') || rowPath.startsWith('https://')) {
        return rowPath;
      }
      return _supabase.storage.from('floor-plans').getPublicUrl(rowPath);
    }

    final path = (payloadMap['floorPlanPath'] ?? payloadMap['floor_plan_path'])
        ?.toString();
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return _supabase.storage.from('floor-plans').getPublicUrl(path);
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
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 900,
            height: 620,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Container(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          color: Colors.grey.shade100,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: imageUrl != null
                                    ? Image.network(
                                        imageUrl,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) {
                                          if (imageBytes != null) {
                                            return Image.memory(
                                              imageBytes,
                                              fit: BoxFit.contain,
                                            );
                                          }
                                          return const Center(
                                            child: Text('樓層圖載入失敗'),
                                          );
                                        },
                                      )
                                    : imageBytes != null
                                        ? Image.memory(
                                            imageBytes,
                                            fit: BoxFit.contain,
                                          )
                                        : const Center(child: Text('無圖片')),
                              ),
                              ...pins.map((pin) {
                                final x = (pin['x'] as num?)?.toDouble();
                                final y = (pin['y'] as num?)?.toDouble();
                                if (x == null || y == null) {
                                  return const SizedBox.shrink();
                                }
                                final left = constraints.maxWidth * (x / 100);
                                final top =
                                    constraints.maxHeight * (1 - (y / 100));
                                return Positioned(
                                  left: left - 9,
                                  top: top - 9,
                                  child: Tooltip(
                                    message:
                                        'Pin ${pin['id'] ?? ''} (${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})',
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
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
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
                color: Colors.white.withValues(alpha: 0.7),
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
                color: Colors.green.withValues(alpha: 0.15),
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
        color: active ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
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
                                              child: Row(
                                                children: [
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
                                                              width: 140,
                                                              height: 90,
                                                              fit: BoxFit.cover,
                                                              errorBuilder:
                                                                  (_, __, ___) {
                                                                if (imageBytes !=
                                                                    null) {
                                                                  return Image
                                                                      .memory(
                                                                    imageBytes,
                                                                    width: 140,
                                                                    height: 90,
                                                                    fit: BoxFit
                                                                        .cover,
                                                                    errorBuilder: (_,
                                                                            __,
                                                                            ___) =>
                                                                        Container(
                                                                      width:
                                                                          140,
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
                                                                  width: 140,
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
                                                                  width: 140,
                                                                  height: 90,
                                                                  fit: BoxFit
                                                                      .cover,
                                                                  errorBuilder: (_,
                                                                          __,
                                                                          ___) =>
                                                                      Container(
                                                                    width: 140,
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
                                                                  width: 140,
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
                                                  ),
                                                  const SizedBox(width: 14),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          '$buildingName - $floor F',
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 6),
                                                        Text(
                                                          'Session ID: ${row['session_id']}',
                                                          style:
                                                              const TextStyle(
                                                            color: AppTheme
                                                                .textSecondary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
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
                                                  ),
                                                ],
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
      child: Row(
        children: [
          const Column(
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
          ),
          const Spacer(),
          // 手動刷新
          OutlinedButton.icon(
            onPressed: _loadReports,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('刷新'),
          ),
          const SizedBox(width: 12),
          Text(
            '共 ${_reports.length} 筆報告',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════ 統計卡 ═══════════

  Widget _buildStatsRow() {
    final total = _reports.length;
    final high = _reports.where((r) => r['risk_level'] == 'high').length;
    final medium = _reports.where((r) => r['risk_level'] == 'medium').length;
    final low = _reports.where((r) => r['risk_level'] == 'low').length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        children: [
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
          const SizedBox(width: 16),
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
          const SizedBox(width: 16),
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
          const SizedBox(width: 16),
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
        ],
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isActive
                ? Border.all(color: color, width: 2)
                : Border.all(color: Colors.transparent, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isActive ? 0.08 : 0.04),
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
                  color: color.withValues(alpha: 0.1),
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
      ),
    );
  }

  // ═══════════ 篩選欄 ═══════════

  Widget _buildFilterBar() {
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
        selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
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
              color: Colors.black.withValues(alpha: 0.04),
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
                headingRowColor: WidgetStateProperty.all(
                  AppTheme.primaryColor.withValues(alpha: 0.05),
                ),
                columnSpacing: 16,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 56,
                columns: const [
                  DataColumn(
                      label: Text('#',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('標題',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('類別',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('風險分數',
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
    final riskLevel = report['risk_level'] ?? 'low';
    final riskColor = AppTheme.getRiskColor(riskLevel);
    final status = report['status'] ?? 'pending';
    final createdAt = report['created_at'] != null
        ? DateFormat('yyyy/MM/dd HH:mm')
            .format(DateTime.parse(report['created_at']).toLocal())
        : '-';
    final category = _categoryLabel(report['category'] ?? '');

    return DataRow(
      cells: [
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
          '${report['risk_score'] ?? 0}',
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
        color: color.withValues(alpha: 0.1),
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
                await _deleteRelatedPinForReport(report);
                await _supabase.from('reports').delete().eq('id', report['id']);
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
    targetSession['updatedAt'] = DateTime.now().toIso8601String();

    await _supabase.from('inspection_sessions').update({
      'payload': targetSession,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('session_id', targetRow['session_id']);
  }

  Map<String, dynamic> _extractInspectionRefFromLocation(String? location) {
    if (location == null || location.isEmpty) return {};

    final refIndex = location.indexOf('ref:');
    if (refIndex < 0) return {};

    final refText = location.substring(refIndex + 4).trim();
    final parts = refText.split(';');
    String? sessionId;
    String? pinId;
    int? floor;

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
      }
    }

    return {
      if (sessionId != null) 'sessionId': sessionId,
      if (pinId != null) 'pinId': pinId,
      if (floor != null) 'floor': floor,
    };
  }
}
