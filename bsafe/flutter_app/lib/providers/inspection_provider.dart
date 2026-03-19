import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:bsafe_app/models/inspection_model.dart';
import 'package:bsafe_app/services/api_service.dart';
import 'package:bsafe_app/services/supabase_service.dart';

class InspectionProvider extends ChangeNotifier {
  // 當前巡檢會話
  InspectionSession? _currentSession;
  InspectionSession? get currentSession => _currentSession;

  // 所有歷史會話
  List<InspectionSession> _sessions = [];
  List<InspectionSession> get sessions => _sessions;

  // 當前選中的 pin
  InspectionPin? _selectedPin;
  InspectionPin? get selectedPin => _selectedPin;

  // 是否處於 pin 放置模式
  bool _isPinMode = false;
  bool get isPinMode => _isPinMode;

  // 載入狀態
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // AI 分析中
  bool _isAnalyzing = false;
  bool get isAnalyzing => _isAnalyzing;

  final ApiService _api = ApiService.instance;
  final Uuid _uuid = const Uuid();

  static const String _sessionsKey = 'inspection_sessions';
  static const String _currentSessionKey = 'current_session_id';
  Future<void>? _initialLoadFuture;
  bool _isCloudSyncing = false;
  bool _pendingCloudSync = false;

  InspectionProvider() {
    _initialLoadFuture = loadSessions();
  }

  Future<void> ensureLoaded() async {
    final future = _initialLoadFuture;
    if (future != null) {
      await future;
      _initialLoadFuture = null;
    }
  }

  // ===== 會話管理 =====

  /// 建立新的巡檢會話
  Future<InspectionSession> createSession(String name,
      {String? floorPlanPath, String? projectId, int floor = 1}) async {
    await ensureLoaded();
    final session = InspectionSession(
      id: _uuid.v4(),
      name: name,
      projectId: projectId,
      floor: floor,
      floorPlanPath: floorPlanPath,
    );

    _currentSession = session;
    _sessions.insert(0, session);
    await _saveSessions();
    notifyListeners();
    return session;
  }

  /// 載入所有會話
  Future<void> loadSessions() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = prefs.getString(_sessionsKey);
      List<InspectionSession> localSessions = [];
      List<InspectionSession> cloudSessions = [];

      if (sessionsJson != null && sessionsJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(sessionsJson);
        localSessions = list
            .map((e) => InspectionSession.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      if (SupabaseService.isConfigured) {
        final rows = await SupabaseService.instance.fetchInspectionSessions();
        cloudSessions = rows
            .map((e) => InspectionSession.fromJson(e))
            .where((session) => session.id.isNotEmpty)
            .toList();
      }

      _sessions = _mergeSessions(localSessions, cloudSessions);

      // 恢復上一個使用的會話
      final currentId = prefs.getString(_currentSessionKey);
      if (currentId != null && _sessions.isNotEmpty) {
        _currentSession = _sessions.firstWhere(
          (s) => s.id == currentId,
          orElse: () => _sessions.first,
        );
      }

      if (_currentSession == null && _sessions.isNotEmpty) {
        _currentSession = _sessions.first;
      }

      await _saveSessions(syncCloud: false);
    } catch (e) {
      debugPrint('載入巡檢會話失敗: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 保存所有會話
  Future<void> _saveSessions({bool syncCloud = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final compactSessions = _sessions.map(_sessionToStorageJson).toList();
      final json = jsonEncode(compactSessions);
      final ok = await prefs.setString(_sessionsKey, json);
      if (!ok) {
        debugPrint('❌ 保存巡檢會話失敗: SharedPreferences setString 回傳 false');
      }

      if (_currentSession != null) {
        await prefs.setString(_currentSessionKey, _currentSession!.id);
      }

      if (syncCloud) {
        _triggerCloudSync();
      }
    } catch (e) {
      debugPrint('保存巡檢會話失敗: $e');
    }
  }

  /// 切換到指定會話
  void switchSession(String sessionId) {
    _currentSession = _sessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => _sessions.first,
    );
    _selectedPin = null;
    _saveSessions();
    notifyListeners();
  }

  /// 刪除會話
  Future<void> deleteSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId);
    if (_currentSession?.id == sessionId) {
      _currentSession = _sessions.isNotEmpty ? _sessions.first : null;
    }
    await _saveSessions();
    await SupabaseService.instance.deleteInspectionSession(sessionId);
    notifyListeners();
  }

  /// 更新當前會話的 floor plan 路徑
  void updateFloorPlan(String path) {
    if (_currentSession == null) return;
    _currentSession = _currentSession!.copyWith(
      floorPlanPath: path,
      updatedAt: DateTime.now(),
    );
    _updateSessionInList();
    _saveSessions();
    notifyListeners();
  }

  // ===== Pin 管理 =====

  /// 切換 pin 放置模式
  void togglePinMode() {
    _isPinMode = !_isPinMode;
    if (_isPinMode) {
      _selectedPin = null;
    }
    notifyListeners();
  }

  /// 關閉 pin 模式
  void disablePinMode() {
    _isPinMode = false;
    notifyListeners();
  }

  /// 在指定位置添加 pin
  InspectionPin addPin(double x, double y) {
    if (_currentSession == null) {
      createSession('巡檢 ${DateTime.now().toString().substring(0, 16)}');
    }

    final pin = InspectionPin(
      id: _uuid.v4(),
      x: x,
      y: y,
    );

    final updatedPins = List<InspectionPin>.from(_currentSession!.pins)
      ..add(pin);

    _currentSession = _currentSession!.copyWith(
      pins: updatedPins,
      updatedAt: DateTime.now(),
    );
    _selectedPin = pin;
    _isPinMode = false;
    _updateSessionInList();
    _saveSessions();
    notifyListeners();
    return pin;
  }

  /// 更新 pin（例如添加照片+AI分析）
  void updatePin(InspectionPin updatedPin) {
    if (_currentSession == null) return;

    final pins = List<InspectionPin>.from(_currentSession!.pins);
    final index = pins.indexWhere((p) => p.id == updatedPin.id);
    if (index >= 0) {
      pins[index] = updatedPin;
      _currentSession = _currentSession!.copyWith(
        pins: pins,
        updatedAt: DateTime.now(),
      );
      if (_selectedPin?.id == updatedPin.id) {
        _selectedPin = updatedPin;
      }
      _updateSessionInList();
      _saveSessions();
      notifyListeners();
    }
  }

  /// 刪除 pin
  void removePin(String pinId) {
    if (_currentSession == null) return;

    final pins = List<InspectionPin>.from(_currentSession!.pins)
      ..removeWhere((p) => p.id == pinId);

    _currentSession = _currentSession!.copyWith(
      pins: pins,
      updatedAt: DateTime.now(),
    );
    if (_selectedPin?.id == pinId) {
      _selectedPin = null;
    }
    _updateSessionInList();
    _saveSessions();
    notifyListeners();
  }

  /// 選擇 pin
  void selectPin(InspectionPin? pin) {
    _selectedPin = pin;
    notifyListeners();
  }

  /// 取消選擇
  void deselectPin() {
    _selectedPin = null;
    notifyListeners();
  }

  // ===== AI 分析 =====

  /// 對指定 pin 進行 AI 分析
  Future<InspectionPin> analyzePin(
    InspectionPin pin, {
    required String imageBase64,
    String? imagePath,
  }) async {
    _isAnalyzing = true;
    notifyListeners();

    try {
      Map<String, dynamic> analysis;

      try {
        analysis = await _api.analyzeImageWithAI(imageBase64);
      } catch (e) {
        // 使用本地分析作為後備
        analysis = ApiService.localAnalysis('moderate', 'structural');
      }

      final updatedPin = pin.copyWith(
        imagePath: imagePath,
        imageBase64: imageBase64,
        aiResult: analysis,
        category: analysis['category'] as String?,
        severity: analysis['severity'] as String?,
        riskScore: analysis['risk_score'] as int? ?? 50,
        riskLevel: analysis['risk_level'] as String? ?? 'medium',
        description: analysis['analysis'] as String?,
        recommendations: (analysis['recommendations'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        status: 'analyzed',
      );

      updatePin(updatedPin);
      return updatedPin;
    } catch (e) {
      debugPrint('AI 分析失敗: $e');
      // 返回帶有基本分析的 pin
      final fallbackPin = pin.copyWith(
        imagePath: imagePath,
        imageBase64: imageBase64,
        riskScore: 50,
        riskLevel: 'medium',
        description: 'AI 分析服務暫時不可用，使用本地評估',
        recommendations: ['建議安排專業人員檢查'],
        status: 'analyzed',
      );
      updatePin(fallbackPin);
      return fallbackPin;
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  /// 分析單一 defect（帶聊天上下文）
  Future<Defect> analyzeDefect(
    Defect defect, {
    required String imageBase64,
    String? imagePath,
    String? chatContext,
  }) async {
    _isAnalyzing = true;
    notifyListeners();

    try {
      Map<String, dynamic> analysis;

      try {
        analysis = await _api.analyzeImageWithAI(
          imageBase64,
          additionalContext: chatContext,
        );
      } catch (e) {
        analysis = ApiService.localAnalysis('moderate', 'structural');
      }

      final chatMessages = List<ChatMessage>.from(defect.chatMessages);
      // Add AI response as chat message
      chatMessages.add(ChatMessage(
        id: _uuid.v4(),
        role: 'ai',
        content: analysis['analysis'] as String? ?? '分析完成。',
      ));

      return defect.copyWith(
        imagePath: imagePath ?? defect.imagePath,
        imageBase64: imageBase64,
        aiResult: analysis,
        category: analysis['category'] as String?,
        severity: analysis['severity'] as String?,
        riskScore: analysis['risk_score'] as int? ?? 50,
        riskLevel: analysis['risk_level'] as String? ?? 'medium',
        description: analysis['analysis'] as String?,
        recommendations: (analysis['recommendations'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        status: 'analyzed',
        chatMessages: chatMessages,
      );
    } catch (e) {
      debugPrint('AI 缺陷分析失敗: $e');
      return defect.copyWith(
        imagePath: imagePath ?? defect.imagePath,
        imageBase64: imageBase64,
        riskScore: 50,
        riskLevel: 'medium',
        description: 'AI 分析服務暫時不可用，使用本地評估',
        recommendations: ['建議安排專業人員檢查'],
        status: 'analyzed',
      );
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  // ===== 內部方法 =====

  Map<String, dynamic> _sessionToStorageJson(InspectionSession session) {
    final data = session.toJson();
    final rawPins = (data['pins'] as List<dynamic>? ?? []);
    data['pins'] = rawPins.map((pin) {
      final pinMap = Map<String, dynamic>.from(pin as Map<String, dynamic>);
      pinMap['imageBase64'] = null;
      pinMap['aiResult'] = _compactAiResult(pinMap['aiResult']);

      final rawDefects = (pinMap['defects'] as List<dynamic>? ?? []);
      pinMap['defects'] = rawDefects.map((defect) {
        final defectMap =
            Map<String, dynamic>.from(defect as Map<String, dynamic>);
        defectMap['imageBase64'] = null;
        defectMap['aiResult'] = _compactAiResult(defectMap['aiResult']);

        final rawChats = (defectMap['chatMessages'] as List<dynamic>? ?? []);
        final trimmedChats = rawChats
            .take(rawChats.length > 20 ? 20 : rawChats.length)
            .map((msg) {
          final msgMap = Map<String, dynamic>.from(msg as Map<String, dynamic>);
          msgMap['content'] =
              _truncateText(msgMap['content']?.toString() ?? '', 500);
          return msgMap;
        }).toList();
        defectMap['chatMessages'] = trimmedChats;
        defectMap['description'] =
            _truncateText(defectMap['description']?.toString() ?? '', 1200);
        return defectMap;
      }).toList();

      pinMap['description'] =
          _truncateText(pinMap['description']?.toString() ?? '', 1200);
      return pinMap;
    }).toList();
    return data;
  }

  Map<String, dynamic>? _compactAiResult(dynamic value) {
    if (value is! Map<String, dynamic>) return null;
    return {
      'category': value['category'],
      'severity': value['severity'],
      'risk_level': value['risk_level'],
      'risk_score': value['risk_score'],
      'is_urgent': value['is_urgent'],
      'analysis': _truncateText(value['analysis']?.toString() ?? '', 1500),
    };
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength);
  }

  DateTime _effectiveUpdatedAt(InspectionSession session) {
    return session.updatedAt ?? session.createdAt;
  }

  List<InspectionSession> _mergeSessions(
    List<InspectionSession> local,
    List<InspectionSession> cloud,
  ) {
    final byId = <String, InspectionSession>{};
    for (final session in [...local, ...cloud]) {
      if (session.id.isEmpty) continue;
      final existing = byId[session.id];
      if (existing == null ||
          _effectiveUpdatedAt(session).isAfter(_effectiveUpdatedAt(existing))) {
        byId[session.id] = session;
      }
    }

    final merged = byId.values.toList()
      ..sort(
          (a, b) => _effectiveUpdatedAt(b).compareTo(_effectiveUpdatedAt(a)));
    return merged;
  }

  void _triggerCloudSync() {
    if (!SupabaseService.isConfigured) return;
    if (_isCloudSyncing) {
      _pendingCloudSync = true;
      return;
    }
    _syncSessionsToCloud();
  }

  Future<void> _syncSessionsToCloud() async {
    if (!SupabaseService.isConfigured) return;
    _isCloudSyncing = true;
    try {
      do {
        _pendingCloudSync = false;
        final compactSessions =
            _sessions.map(_sessionToStorageJson).toList(growable: false);

        for (final session in compactSessions) {
          await SupabaseService.instance.upsertInspectionSession(session);
        }
      } while (_pendingCloudSync);
    } catch (e) {
      debugPrint('同步巡檢會話到 Supabase 失敗: $e');
    } finally {
      _isCloudSyncing = false;
    }
  }

  /// 更新 sessions 列表中的當前 session
  void _updateSessionInList() {
    if (_currentSession == null) return;

    final index = _sessions.indexWhere((s) => s.id == _currentSession!.id);
    if (index >= 0) {
      _sessions[index] = _currentSession!;
    }
  }

  /// 完成巡檢會話
  Future<void> completeSession() async {
    if (_currentSession == null) return;

    _currentSession = _currentSession!.copyWith(
      status: 'completed',
      updatedAt: DateTime.now(),
    );
    _updateSessionInList();
    await _saveSessions();
    notifyListeners();
  }

  /// 標記為已導出
  Future<void> markExported() async {
    if (_currentSession == null) return;

    _currentSession = _currentSession!.copyWith(
      status: 'exported',
      updatedAt: DateTime.now(),
    );
    _updateSessionInList();
    await _saveSessions();
    notifyListeners();
  }

  /// 當前會話的 pins 列表 (快捷存取)
  List<InspectionPin> get currentPins => _currentSession?.pins ?? [];
}
