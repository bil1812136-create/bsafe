import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bsafe_app/models/report_model.dart';
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
  late TextEditingController _convoInputController;
  late String _status;
  late String _severity;
  late String _riskLevel;
  late int _riskScore;
  bool _isSaving = false;
  bool _hasChanges = false;
  bool _isSendingMessage = false;
  bool _isLoadingFloorPlan = true;
  bool _showLinkedPhoto = true;
  late List<ConversationMessage> _conversation;
  StreamSubscription<List<Map<String, dynamic>>>? _reportSubscription;
  String? _floorPlanDisplayUrl;
  String? _floorPlanBase64;
  int? _floorNumber;
  List<Map<String, dynamic>> _floorPins = [];
  Map<String, dynamic>? _selectedFloorPin;
  double? _coordMinX;
  double? _coordMaxX;
  double? _coordMinY;
  double? _coordMaxY;
  final Map<String, TextEditingController> _analysisFieldControllers = {};
  late TextEditingController _imageDefectController;
  List<String> _analysisFieldOrder = [];
  final List<String> _baseAnalysisFieldLabels = [
    'Defect Category',
    'Risk Level',
    'Severity',
    'Recommended Action',
  ];

  SupabaseClient get _supabase => Supabase.instance.client;

  String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  @override
  void initState() {
    super.initState();
    final r = widget.report;
    _titleController = TextEditingController(text: _asString(r['title']) ?? '');
    _analysisController =
        TextEditingController(text: _asString(r['ai_analysis']) ?? '');
    _convoInputController = TextEditingController();
    _status = _asString(r['status']) ?? 'pending';
    _severity = _asString(r['severity']) ?? 'moderate';
    _riskLevel = _asString(r['risk_level']) ?? 'medium';
    _riskScore = (r['risk_score'] as num?)?.toInt() ?? 50;

    _initAnalysisFields(_asString(r['ai_analysis']) ?? '');

    // 解析 conversation
    _conversation = ReportModel.conversationFromJson(r['conversation']);
    // 向後兼容：若 conversation 為空，從舊欄位遷移
    if (_conversation.isEmpty) {
      final companyNotes = _asString(r['company_notes']);
      if (companyNotes != null && companyNotes.isNotEmpty) {
        _conversation.add(ConversationMessage(
          sender: 'company',
          text: companyNotes,
          timestamp: r['updated_at'] != null
              ? DateTime.tryParse(r['updated_at'] as String) ?? DateTime.now()
              : DateTime.now(),
        ));
      }
      final workerResponse = _asString(r['worker_response']);
      if (workerResponse != null && workerResponse.isNotEmpty) {
        _conversation.add(ConversationMessage(
          sender: 'worker',
          text: workerResponse,
          image: _asString(r['worker_response_image']),
          timestamp: r['updated_at'] != null
              ? DateTime.tryParse(r['updated_at'] as String) ?? DateTime.now()
              : DateTime.now(),
        ));
      }
    }

    _titleController.addListener(_markChanged);
    _analysisController.addListener(_markChanged);

    // 實時監聽這份報告的變化
    _setupRealtimeListener();

    // 載入樓層圖與 pin 關聯
    _loadFloorPlanContext();
  }

  Future<void> _loadFloorPlanContext() async {
    setState(() => _isLoadingFloorPlan = true);

    try {
      // Query full row data: session_id, floor, floor_plan_path, payload
      final rows = await _supabase
          .from('inspection_sessions')
          .select('session_id, floor, floor_plan_path, payload');

      final sessions = List<Map<String, dynamic>>.from(rows);

      final locationRef = _extractInspectionRefFromLocation(
          widget.report['location'] as String?);
      final targetSessionId = locationRef['sessionId'] as String?;
      final targetPinId = locationRef['pinId'] as String?;
      final targetFloor = locationRef['floor'] as int?;
      final refMinX = locationRef['minX'] as double?;
      final refMaxX = locationRef['maxX'] as double?;
      final refMinY = locationRef['minY'] as double?;
      final refMaxY = locationRef['maxY'] as double?;

      final reportX = (widget.report['latitude'] as num?)?.toDouble();
      final reportY = (widget.report['longitude'] as num?)?.toDouble();

      Map<String, dynamic>? bestSession;
      Map<String, dynamic>? bestSessionRow;
      Map<String, dynamic>? matchedPin;
      double bestDistance = double.infinity;

      if (targetSessionId != null && targetSessionId.isNotEmpty) {
        for (final row in sessions) {
          final session = Map<String, dynamic>.from(
              row['payload'] as Map<String, dynamic>? ?? {});
          if (session.isEmpty) continue;

          final sessionId =
              (session['id'] ?? row['session_id'])?.toString() ?? '';
          if (sessionId != targetSessionId) continue;

          final pinsRaw = (session['pins'] as List<dynamic>? ?? [])
              .map((p) => Map<String, dynamic>.from(p as Map))
              .toList();

          Map<String, dynamic>? exactPin;
          if (targetPinId != null && targetPinId.isNotEmpty) {
            for (final pin in pinsRaw) {
              if ((pin['id']?.toString() ?? '') == targetPinId) {
                exactPin = pin;
                break;
              }
            }
          }

          bestSession = session;
          bestSessionRow = row;
          matchedPin = exactPin ?? (pinsRaw.isNotEmpty ? pinsRaw.first : null);
          bestDistance = 0;
          break;
        }
      }

      if (bestSession == null) {
        for (final row in sessions) {
          final session = Map<String, dynamic>.from(
              row['payload'] as Map<String, dynamic>? ?? {});
          if (session.isEmpty) continue;

          if (targetFloor != null) {
            final floor = (session['floor'] as num?)?.toInt();
            if (floor != null && floor != targetFloor) {
              continue;
            }
          }

          final pinsRaw = (session['pins'] as List<dynamic>? ?? [])
              .map((p) => Map<String, dynamic>.from(p as Map))
              .toList();
          if (pinsRaw.isEmpty) continue;

          for (final pin in pinsRaw) {
            final px = (pin['x'] as num?)?.toDouble();
            final py = (pin['y'] as num?)?.toDouble();
            if (reportX == null ||
                reportY == null ||
                px == null ||
                py == null) {
              continue;
            }
            final dx = px - reportX;
            final dy = py - reportY;
            final distance = (dx * dx + dy * dy);
            if (distance < bestDistance) {
              bestDistance = distance;
              bestSession = session;
              bestSessionRow = row;
              matchedPin = pin;
            }
          }
        }
      }

      // Fallback to first session if no pin match found
      if (bestSession == null && sessions.isNotEmpty) {
        Map<String, dynamic>? fallbackRow;
        Map<String, dynamic>? fallbackSession;

        for (final row in sessions) {
          final session = Map<String, dynamic>.from(
              row['payload'] as Map<String, dynamic>? ?? {});
          final pinsRaw = (session['pins'] as List<dynamic>? ?? []);
          if (session.isNotEmpty && pinsRaw.isNotEmpty) {
            fallbackRow = row;
            fallbackSession = session;
            break;
          }
        }

        fallbackRow ??= sessions.first;
        fallbackSession ??= Map<String, dynamic>.from(
            fallbackRow['payload'] as Map<String, dynamic>? ?? {});

        bestSessionRow = fallbackRow;
        bestSession = fallbackSession;

        final pinsRaw = (fallbackSession['pins'] as List<dynamic>? ?? [])
            .map((p) => Map<String, dynamic>.from(p as Map))
            .toList();
        if (pinsRaw.isNotEmpty) {
          matchedPin = pinsRaw.first;
        }
      }

      if (bestSession != null && bestSessionRow != null) {
        // Priority: payload floor_plan_url > payload floor_plan_base64 > row floor_plan_path
        String? resolvedUrl;
        String? base64Data;

        // Check payload first
        final payloadUrl =
            (bestSession['floor_plan_url'] ?? bestSession['floorPlanUrl'])
                ?.toString();
        final payloadBase64 =
            (bestSession['floor_plan_base64'] ?? bestSession['floorPlanBase64'])
                ?.toString();

        if (payloadUrl != null && payloadUrl.isNotEmpty) {
          if (payloadUrl.startsWith('http://') ||
              payloadUrl.startsWith('https://')) {
            resolvedUrl = payloadUrl;
          } else if (payloadUrl.contains('buildings/')) {
            final idx = payloadUrl.indexOf('buildings/');
            final storagePath = payloadUrl.substring(idx);
            resolvedUrl =
                _supabase.storage.from('floor-plans').getPublicUrl(storagePath);
          }
        } else if (payloadBase64 != null && payloadBase64.isNotEmpty) {
          base64Data = payloadBase64;
        } else {
          // Fallback to row floor_plan_path
          final floorPlanPath = bestSessionRow['floor_plan_path'] as String?;
          if (floorPlanPath != null && floorPlanPath.isNotEmpty) {
            if (floorPlanPath.startsWith('http://') ||
                floorPlanPath.startsWith('https://')) {
              resolvedUrl = floorPlanPath;
            } else if (floorPlanPath.contains('buildings/')) {
              final idx = floorPlanPath.indexOf('buildings/');
              final storagePath = floorPlanPath.substring(idx);
              resolvedUrl = _supabase.storage
                  .from('floor-plans')
                  .getPublicUrl(storagePath);
            }
          }
        }

        final pins = (bestSession['pins'] as List<dynamic>? ?? [])
            .map((p) => Map<String, dynamic>.from(p as Map))
            .toList();
        final bounds = _resolveCoordinateBounds(bestSession, pins);
        final finalMinX = refMinX ?? bounds['minX'];
        final finalMaxX = refMaxX ?? bounds['maxX'];
        final finalMinY = refMinY ?? bounds['minY'];
        final finalMaxY = refMaxY ?? bounds['maxY'];

        setState(() {
          _floorPlanDisplayUrl = resolvedUrl;
          _floorPlanBase64 = base64Data;
          _floorNumber = (bestSessionRow!['floor'] as num?)?.toInt();
          _floorPins = pins;
          _coordMinX = finalMinX;
          _coordMaxX = finalMaxX;
          _coordMinY = finalMinY;
          _coordMaxY = finalMaxY;
          _selectedFloorPin =
              matchedPin ?? (pins.isNotEmpty ? pins.first : null);
          _isLoadingFloorPlan = false;
        });
        return;
      }

      if (mounted) {
        setState(() {
          _isLoadingFloorPlan = false;
          _floorPlanDisplayUrl = null;
          _floorPlanBase64 = null;
          _floorPins = [];
          _coordMinX = null;
          _coordMaxX = null;
          _coordMinY = null;
          _coordMaxY = null;
          _selectedFloorPin = null;
        });
      }
    } catch (e) {
      debugPrint('Floor plan load error: $e');
      if (mounted) {
        setState(() {
          _isLoadingFloorPlan = false;
          _floorPlanDisplayUrl = null;
          _floorPlanBase64 = null;
          _floorPins = [];
          _coordMinX = null;
          _coordMaxX = null;
          _coordMinY = null;
          _coordMaxY = null;
          _selectedFloorPin = null;
        });
      }
    }
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
    double? minX;
    double? maxX;
    double? minY;
    double? maxY;

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
    };
  }

  Map<String, double> _resolveCoordinateBounds(
    Map<String, dynamic> session,
    List<Map<String, dynamic>> pins,
  ) {
    final rawBounds = session['coordinate_bounds'];
    if (rawBounds is Map) {
      final map = Map<String, dynamic>.from(rawBounds);
      final minX = (map['minX'] as num?)?.toDouble();
      final maxX = (map['maxX'] as num?)?.toDouble();
      final minY = (map['minY'] as num?)?.toDouble();
      final maxY = (map['maxY'] as num?)?.toDouble();
      if (minX != null && maxX != null && minY != null && maxY != null) {
        return {
          'minX': minX,
          'maxX': maxX,
          'minY': minY,
          'maxY': maxY,
        };
      }
    }

    if (pins.isEmpty) {
      return {'minX': 0, 'maxX': 1, 'minY': 0, 'maxY': 1};
    }

    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final pin in pins) {
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

    return {
      'minX': minX,
      'maxX': maxX,
      'minY': minY,
      'maxY': maxY,
    };
  }

  String? _pinImageUrl(Map<String, dynamic>? pin) {
    if (pin == null) return null;
    final defects = pin['defects'] as List<dynamic>? ?? [];
    if (defects.isNotEmpty) {
      final firstDefect = Map<String, dynamic>.from(defects.first as Map);
      final imgPath = firstDefect['imagePath'] as String?;
      if (imgPath != null &&
          (imgPath.startsWith('http://') || imgPath.startsWith('https://'))) {
        return imgPath;
      }
    }
    return null;
  }

  String? _pinImageBase64(Map<String, dynamic>? pin) {
    if (pin == null) return null;
    final defects = pin['defects'] as List<dynamic>? ?? [];
    if (defects.isNotEmpty) {
      final firstDefect = Map<String, dynamic>.from(defects.first as Map);
      final base64 = firstDefect['imageBase64'] as String?;
      if (base64 != null && base64.isNotEmpty) return base64;
    }
    return pin['imageBase64'] as String?;
  }

  /// 計算風險等級和分數從嚴重程度
  void _updateRiskFromSeverity(String severity) {
    final category = widget.report['category'] ?? 'structural';

    switch (severity) {
      case 'severe':
        _riskScore = 80 + (category == 'structural' ? 15 : 5);
        _riskLevel = 'high';
        break;
      case 'moderate':
        _riskScore = 50 + (category == 'structural' ? 20 : 10);
        _riskLevel = _riskScore >= 70 ? 'high' : 'medium';
        break;
      case 'mild':
      default:
        _riskScore = 20 + (category == 'structural' ? 15 : 5);
        _riskLevel = 'low';
    }

    _riskScore = _riskScore.clamp(0, 100);
  }

  /// 實時監聽報告變化（工人回覆等）
  void _setupRealtimeListener() {
    _reportSubscription = _supabase
        .from('reports')
        .stream(primaryKey: ['id'])
        .eq('id', widget.report['id'])
        .listen((rows) {
          if (!mounted || rows.isEmpty) return;

          final data = rows.first;
          final newStatus = data['status'] as String? ?? _status;
          final newSeverity = data['severity'] as String? ?? _severity;
          final newRiskLevel = data['risk_level'] as String? ?? _riskLevel;
          final newRiskScore =
              (data['risk_score'] as num?)?.toInt() ?? _riskScore;

          final newConv =
              ReportModel.conversationFromJson(data['conversation']);
          final hasNewMsg = newConv.length > _conversation.length;

          setState(() {
            _status = newStatus;
            _severity = newSeverity;
            _riskLevel = newRiskLevel;
            _riskScore = newRiskScore;
            if (newConv.isNotEmpty) {
              _conversation = newConv;
            }
          });

          if (hasNewMsg) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.message, color: Colors.white),
                    SizedBox(width: 8),
                    Text('收到新消息'),
                  ],
                ),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 2),
              ),
            );
          }
        });
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  void _initAnalysisFields(String aiAnalysisText) {
    for (final controller in _analysisFieldControllers.values) {
      controller.dispose();
    }
    _analysisFieldControllers.clear();

    final parsed = _parseAnalysisText(aiAnalysisText);
    final fields = Map<String, String>.from(
      parsed['fields'] as Map<String, String>? ?? <String, String>{},
    );
    final imageItems = List<String>.from(
      parsed['imageItems'] as List<String>? ?? <String>[],
    );

    final order = <String>[];
    for (final label in _baseAnalysisFieldLabels) {
      order.add(label);
    }
    for (final key in fields.keys) {
      if (!order.contains(key)) {
        order.add(key);
      }
    }
    _analysisFieldOrder = order;

    for (final label in _analysisFieldOrder) {
      final controller = TextEditingController(text: fields[label] ?? '');
      controller.addListener(_syncAnalysisControllerFromFields);
      _analysisFieldControllers[label] = controller;
    }

    _imageDefectController = TextEditingController(
      text: imageItems.join('\n').trim(),
    );
    _imageDefectController.addListener(_syncAnalysisControllerFromFields);

    _analysisController.text = _composeAnalysisText();
  }

  void _syncAnalysisControllerFromFields() {
    _analysisController.text = _composeAnalysisText();
    _markChanged();
  }

  Map<String, dynamic> _parseAnalysisText(String text) {
    final fields = <String, String>{};
    final imageItems = <String>[];
    final lines = text.split('\n');
    final fieldRegExp =
        RegExp(r'^([A-Za-z][A-Za-z0-9 /&()_\-]{1,80})\s*:\s*(.*)$');
    final imageHeaderRegExp =
        RegExp(r'^Image\s*Defect\s*Analysis\s*:', caseSensitive: false);
    final imageItemRegExp = RegExp(r'^\d+\s*[\.|\)]\s*(.*)$');

    String? currentLabel;
    final currentValue = StringBuffer();
    bool inImageSection = false;

    void flushCurrent() {
      if (currentLabel == null) return;
      final value = currentValue.toString().trim();
      fields[currentLabel!] = value;
      currentLabel = null;
      currentValue.clear();
    }

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        if (currentLabel != null && currentValue.isNotEmpty) {
          currentValue.write('\n');
        }
        continue;
      }

      if (imageHeaderRegExp.hasMatch(trimmed)) {
        flushCurrent();
        inImageSection = true;
        continue;
      }

      if (inImageSection) {
        final itemMatch = imageItemRegExp.firstMatch(trimmed);
        if (itemMatch != null) {
          imageItems.add((itemMatch.group(1) ?? '').trim());
          continue;
        }

        final possibleField = fieldRegExp.firstMatch(trimmed);
        if (possibleField != null) {
          inImageSection = false;
          flushCurrent();
          currentLabel = (possibleField.group(1) ?? '').trim();
          currentValue.write((possibleField.group(2) ?? '').trim());
          continue;
        }

        if (imageItems.isEmpty) {
          imageItems.add(trimmed);
        } else {
          final lastIndex = imageItems.length - 1;
          imageItems[lastIndex] = '${imageItems[lastIndex]} $trimmed'.trim();
        }
        continue;
      }

      final fieldMatch = fieldRegExp.firstMatch(trimmed);
      if (fieldMatch != null) {
        flushCurrent();
        currentLabel = (fieldMatch.group(1) ?? '').trim();
        currentValue.write((fieldMatch.group(2) ?? '').trim());
      } else if (currentLabel != null) {
        if (currentValue.isNotEmpty &&
            !currentValue.toString().endsWith('\n')) {
          currentValue.write('\n');
        }
        currentValue.write(trimmed);
      } else {
        fields['Defect Category'] =
            '${fields['Defect Category'] ?? ''} $trimmed'.trim();
      }
    }

    flushCurrent();

    if (fields.isEmpty && text.trim().isNotEmpty) {
      fields['Defect Category'] = text.trim();
    }

    return {
      'fields': fields,
      'imageItems': imageItems,
    };
  }

  String _composeAnalysisText() {
    final lines = <String>[];
    for (final label in _analysisFieldOrder) {
      final value = _analysisFieldControllers[label]?.text.trim() ?? '';
      lines.add('$label: $value');
    }

    lines.add('');
    lines.add('Image Defect Analysis:');
    final imageText = _imageDefectController.text.trim();
    if (imageText.isNotEmpty) {
      lines.addAll(imageText.split('\n'));
    }

    return lines.join('\n').trimRight();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _analysisController.dispose();
    _convoInputController.dispose();
    for (final controller in _analysisFieldControllers.values) {
      controller.dispose();
    }
    _imageDefectController.dispose();
    _reportSubscription?.cancel();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _supabase.from('reports').update({
        'title': _titleController.text,
        'ai_analysis': _analysisController.text,
        'status': _status,
        'severity': _severity,
        'risk_level': _riskLevel,
        'risk_score': _riskScore,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
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

  /// 公司端發送跟進訊息
  Future<void> _sendCompanyMessage() async {
    final text = _convoInputController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSendingMessage = true);
    try {
      // 取得現有 conversation
      final existing = await _supabase
          .from('reports')
          .select('conversation')
          .eq('id', widget.report['id'])
          .single();

      List<dynamic> conv = [];
      final existingConversation = existing['conversation'];
      if (existingConversation is String && existingConversation.isNotEmpty) {
        try {
          final decoded = jsonDecode(existingConversation);
          if (decoded is List) conv = decoded;
        } catch (_) {}
      } else if (existingConversation is List) {
        conv = existingConversation;
      }

      final newMsg = {
        'sender': 'company',
        'text': text,
        'image': null,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      conv.add(newMsg);

      await _supabase.from('reports').update({
        'company_notes': text,
        'conversation': jsonEncode(conv),
        'has_unread_company': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.report['id']);

      if (mounted) {
        setState(() {
          _conversation.add(ConversationMessage(
            sender: 'company',
            text: text,
            timestamp: DateTime.now(),
          ));
          _convoInputController.clear();
          _isSendingMessage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('訊息已發送'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingMessage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('發送失敗: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final riskLevel = _riskLevel;
    final riskScore = _riskScore;
    final riskColor = AppTheme.getRiskColor(riskLevel);
    final createdAt = r['created_at'] != null
        ? DateFormat('yyyy/MM/dd HH:mm')
            .format(AppTheme.toUtcPlus8(DateTime.parse(r['created_at'])))
        : '-';
    final imageUrl = r['image_url'] as String?;
    final imageBase64 = r['image_base64'] as String?;

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
                  _buildImageCard(imageUrl, imageBase64),
                  const SizedBox(height: 24),
                  // 樓層圖（與現場照片分開顯示）
                  _buildFloorPlanCard(),
                  const SizedBox(height: 24),
                  // 基本資訊
                  _buildInfoCard(riskLevel, riskColor, createdAt),
                  const SizedBox(height: 24),
                  // 狀態修改
                  _buildStatusCard(),
                ],
              ),
            ),
            const SizedBox(width: 32),

            // ── 右: AI 分析 + 對話區 ──
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
                    title: 'AI 分析結果（可修改）',
                    icon: Icons.smart_toy,
                    controller: _analysisController,
                    maxLines: 1,
                    highlight: true,
                    child: _buildStructuredAiAnalysisSection(),
                  ),
                  const SizedBox(height: 24),
                  // 對話 / 跟進記錄
                  _buildConversationSection(),
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

  // ═══════════ Conversation section ═══════════

  Widget _buildConversationSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.forum, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                '跟進對話',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_conversation.length} 條訊息',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 對話列表
          Container(
            constraints: const BoxConstraints(maxHeight: 350),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: _conversation.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        '尚無對話記錄\n在下方輸入跟進任務開始對話',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: _conversation.length,
                    itemBuilder: (context, index) {
                      final msg = _conversation[index];
                      final isCompany = msg.sender == 'company';
                      return _buildMessageBubble(msg, isCompany);
                    },
                  ),
          ),
          const SizedBox(height: 12),
          // 訊息輸入區
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _convoInputController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: '輸入跟進任務或回覆...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.blue.shade600, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSendingMessage ? null : _sendCompanyMessage,
                  icon: _isSendingMessage
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, size: 18),
                  label: Text(_isSendingMessage ? '...' : '發送'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ConversationMessage msg, bool isCompany) {
    final time =
        DateFormat('MM/dd HH:mm').format(AppTheme.toUtcPlus8(msg.timestamp));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isCompany ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isCompany) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.teal.shade100,
              child: Icon(Icons.engineering,
                  size: 18, color: Colors.teal.shade700),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCompany ? Colors.blue.shade50 : Colors.teal.shade50,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isCompany ? 12 : 2),
                  bottomRight: Radius.circular(isCompany ? 2 : 12),
                ),
                border: Border.all(
                  color:
                      isCompany ? Colors.blue.shade200 : Colors.teal.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isCompany ? '公司' : '工人',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isCompany
                              ? Colors.blue.shade700
                              : Colors.teal.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 圖片
                  if (msg.image != null && msg.image!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: GestureDetector(
                        onTap: () => _openImageViewer(
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
                                  height: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                )
                              : Image.memory(
                                  base64Decode(msg.image!),
                                  height: 120,
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
                      fontSize: 14,
                      color: isCompany
                          ? Colors.blue.shade900
                          : Colors.teal.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isCompany) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue.shade100,
              child:
                  Icon(Icons.business, size: 18, color: Colors.blue.shade700),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════ Widget builders ═══════════

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

  Widget _buildImageCard(String? imageUrl, String? imageBase64) {
    final Widget imageWidget = imageUrl != null && imageUrl.isNotEmpty
        ? Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          )
        : imageBase64 != null && imageBase64.isNotEmpty
            ? Image.memory(
                Uri.parse('data:image/jpeg;base64,$imageBase64').data != null
                    ? Uri.parse('data:image/jpeg;base64,$imageBase64')
                        .data!
                        .contentAsBytes()
                    : base64Decode(imageBase64),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              )
            : const SizedBox.shrink();

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
          GestureDetector(
            onTap: (imageUrl != null && imageUrl.isNotEmpty) ||
                    (imageBase64 != null && imageBase64.isNotEmpty)
                ? () => _openImageViewer(imageWidget)
                : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      height: 260,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _noImagePlaceholder(),
                    )
                  : imageBase64 != null && imageBase64.isNotEmpty
                      ? Image.memory(
                          Uri.parse('data:image/jpeg;base64,$imageBase64')
                                      .data !=
                                  null
                              ? Uri.parse('data:image/jpeg;base64,$imageBase64')
                                  .data!
                                  .contentAsBytes()
                              : base64Decode(imageBase64),
                          height: 260,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _noImagePlaceholder(),
                        )
                      : _noImagePlaceholder(),
            ),
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

  Widget _buildInfoCard(String riskLevel, Color riskColor, String createdAt) {
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
          Container(
            width: double.infinity,
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
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorPlanCard() {
    final selectedPinImageUrl = _pinImageUrl(_selectedFloorPin);
    final selectedPinImageBase64 = _pinImageBase64(_selectedFloorPin);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.map, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                _floorNumber != null ? '樓層圖（${_floorNumber}F）' : '樓層圖',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _isLoadingFloorPlan
                  ? const Center(child: CircularProgressIndicator())
                  : _buildInteractiveFloorPlan(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.photo_library_outlined,
                  color: AppTheme.primaryColor, size: 18),
              const SizedBox(width: 8),
              const Text('Pin 對應現場照片',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              IconButton(
                tooltip: _showLinkedPhoto ? '縮小照片' : '展開照片',
                onPressed: () {
                  setState(() {
                    _showLinkedPhoto = !_showLinkedPhoto;
                  });
                },
                icon: Icon(_showLinkedPhoto ? Icons.remove : Icons.add),
              ),
            ],
          ),
          if (_showLinkedPhoto)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: selectedPinImageUrl != null &&
                      selectedPinImageUrl.isNotEmpty
                  ? Image.network(
                      selectedPinImageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _noImagePlaceholder(),
                    )
                  : selectedPinImageBase64 != null &&
                          selectedPinImageBase64.isNotEmpty
                      ? Image.memory(
                          base64Decode(selectedPinImageBase64),
                          height: 180,
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

  Widget _buildInteractiveFloorPlan() {
    // Check if we have URL or base64 image
    final hasUrl =
        _floorPlanDisplayUrl != null && _floorPlanDisplayUrl!.isNotEmpty;
    final hasBase64 = _floorPlanBase64 != null && _floorPlanBase64!.isNotEmpty;

    if (!hasUrl && !hasBase64) {
      if (_floorPins.isEmpty) {
        return Container(
          color: Colors.grey.shade100,
          child: const Center(
            child: Text('無樓層圖 / 無定位圖', style: TextStyle(color: Colors.grey)),
          ),
        );
      }

      return _buildPinCanvas(
        background: Container(color: Colors.grey.shade100),
      );
    }

    // Build background with URL or base64, with fallback
    Widget buildBackgroundImage() {
      if (hasUrl) {
        return Image.network(
          _floorPlanDisplayUrl!,
          fit: BoxFit.fill,
          errorBuilder: (_, __, ___) {
            if (hasBase64) {
              return Image.memory(
                base64Decode(_floorPlanBase64!),
                fit: BoxFit.fill,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade100,
                  child: const Center(
                    child:
                        Text('樓層圖載入失敗', style: TextStyle(color: Colors.grey)),
                  ),
                ),
              );
            }
            return Container(
              color: Colors.grey.shade100,
              child: const Center(
                child: Text('樓層圖載入失敗', style: TextStyle(color: Colors.grey)),
              ),
            );
          },
        );
      } else if (hasBase64) {
        return Image.memory(
          base64Decode(_floorPlanBase64!),
          fit: BoxFit.fill,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey.shade100,
            child: const Center(
              child: Text('樓層圖載入失敗', style: TextStyle(color: Colors.grey)),
            ),
          ),
        );
      }
      return Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: Text('無樓層圖', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return _buildPinCanvas(background: buildBackgroundImage());
  }

  Widget _buildPinCanvas({required Widget background}) {
    if (_floorPins.isEmpty) {
      return background;
    }

    final minX = _coordMinX ?? 0.0;
    final maxX = _coordMaxX ?? 1.0;
    final minY = _coordMinY ?? 0.0;
    final maxY = _coordMaxY ?? 1.0;

    final spanX = (maxX - minX).abs() < 0.0001 ? 1.0 : (maxX - minX);
    final spanY = (maxY - minY).abs() < 0.0001 ? 1.0 : (maxY - minY);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned.fill(child: background),
            ..._floorPins.map((pin) {
              final x = (pin['x'] as num?)?.toDouble();
              final y = (pin['y'] as num?)?.toDouble();
              if (x == null || y == null) return const SizedBox.shrink();

              final nx = ((x - minX) / spanX).clamp(0.0, 1.0);
              final ny = ((y - minY) / spanY).clamp(0.0, 1.0);
              final pinId = pin['id']?.toString() ?? '';
              final active = _selectedFloorPin?['id']?.toString() == pinId;

              return Positioned(
                left: (constraints.maxWidth * nx) - 11,
                top: (constraints.maxHeight * (1 - ny)) - 11,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFloorPin = pin;
                      _showLinkedPhoto = true;
                    });
                  },
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: active ? Colors.red : AppTheme.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.location_on,
                        color: Colors.white, size: 12),
                  ),
                ),
              );
            }),
          ],
        );
      },
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
            _updateRiskFromSeverity(value);
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    color: active ? color : AppTheme.textSecondary,
                  ),
                ),
                if (active)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '風險等級已更新',
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
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
    Color? highlightColor,
    String? hintText,
    Widget? child,
  }) {
    final color = highlightColor ?? Colors.deepOrange;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  color: highlight ? color : AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: highlight ? color : null,
                  )),
              if (highlight) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '可編輯',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (child != null)
            child
          else
            TextField(
              controller: controller,
              maxLines: maxLines,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: highlight
                        ? color.withOpacity(0.3)
                        : AppTheme.borderColor,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: highlight
                        ? color.withOpacity(0.3)
                        : AppTheme.borderColor,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: highlight ? color : AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor:
                    highlight ? color.withOpacity(0.03) : Colors.grey.shade50,
                hintText: hintText ?? (highlight ? '在此修改 AI 分析內容...' : null),
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

  Widget _buildStructuredAiAnalysisSection() {
    return Column(
      children: [
        for (final label in _analysisFieldOrder) ...[
          _buildFixedLabelEditableRow(
            label: label,
            controller: _analysisFieldControllers[label]!,
          ),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Image Defect Analysis:',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _imageDefectController,
          minLines: 4,
          maxLines: 10,
          decoration: InputDecoration(
            hintText: '請輸入或修改 Image Defect Analysis 內容...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.deepOrange.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.deepOrange.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
            ),
            filled: true,
            fillColor: Colors.deepOrange.withOpacity(0.03),
          ),
        ),
      ],
    );
  }

  Widget _buildFixedLabelEditableRow({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: '請輸入或修改 $label 內容...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.deepOrange.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.deepOrange.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
            ),
            filled: true,
            fillColor: Colors.deepOrange.withOpacity(0.03),
          ),
        ),
      ],
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
