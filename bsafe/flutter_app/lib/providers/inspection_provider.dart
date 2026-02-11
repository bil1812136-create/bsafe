import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:bsafe_app/models/inspection_model.dart';
import 'package:bsafe_app/services/api_service.dart';

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

  InspectionProvider() {
    loadSessions();
  }

  // ===== 會話管理 =====

  /// 建立新的巡檢會話
  Future<InspectionSession> createSession(String name, {String? floorPlanPath}) async {
    final session = InspectionSession(
      id: _uuid.v4(),
      name: name,
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

      if (sessionsJson != null && sessionsJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(sessionsJson);
        _sessions = list
            .map((e) => InspectionSession.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      // 恢復上一個使用的會話
      final currentId = prefs.getString(_currentSessionKey);
      if (currentId != null && _sessions.isNotEmpty) {
        _currentSession = _sessions.firstWhere(
          (s) => s.id == currentId,
          orElse: () => _sessions.first,
        );
      }
    } catch (e) {
      debugPrint('載入巡檢會話失敗: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 保存所有會話
  Future<void> _saveSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_sessions.map((s) => s.toJson()).toList());
      await prefs.setString(_sessionsKey, json);

      if (_currentSession != null) {
        await prefs.setString(_currentSessionKey, _currentSession!.id);
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

  // ===== 內部方法 =====

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
