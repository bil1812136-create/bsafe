import 'package:flutter/material.dart';
import 'package:bsafe_app/models/report_model.dart';
import 'package:bsafe_app/services/api_service.dart';
import 'package:bsafe_app/services/supabase_service.dart';

class ReportProvider extends ChangeNotifier {
  List<ReportModel> _reports = [];
  Map<String, dynamic> _statistics = {};
  List<Map<String, dynamic>> _trendData = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<ReportModel> get reports => _reports;
  Map<String, dynamic> get statistics => _statistics;
  List<Map<String, dynamic>> get trendData => _trendData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get pendingSyncCount => 0;

  final ApiService _api = ApiService.instance;

  ReportProvider() {
    loadReports();
  }

  /// 從 Supabase 載入所有報告
  Future<void> loadReports() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('☁️ 從 Supabase 載入報告...');
      final cloudData = await SupabaseService.instance.fetchAllReports();
      _reports = cloudData
          .map((data) => SupabaseService.mapToReportModel(data))
          .toList();
      _statistics = _computeStatistics(_reports);
      _trendData = _computeTrendData(_reports);
      debugPrint('✅ 載入 ${_reports.length} 筆報告');
    } catch (e) {
      _error = '載入資料失敗: $e';
      debugPrint('❌ 載入報告失敗: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> _computeStatistics(List<ReportModel> reports) {
    return {
      'total': reports.length,
      'highRisk': reports.where((r) => r.riskLevel == 'high').length,
      'mediumRisk': reports.where((r) => r.riskLevel == 'medium').length,
      'lowRisk': reports.where((r) => r.riskLevel == 'low').length,
      'urgent': reports.where((r) => r.isUrgent).length,
      'pending': reports.where((r) => r.status == 'pending').length,
      'resolved': reports.where((r) => r.status == 'resolved').length,
    };
  }

  List<Map<String, dynamic>> _computeTrendData(List<ReportModel> reports) {
    final List<Map<String, dynamic>> result = [];
    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final dayReports = reports
          .where((r) => r.createdAt.toIso8601String().startsWith(dateStr))
          .toList();
      result.add({
        'date': '${date.month}/${date.day}',
        'total': dayReports.length,
        'high': dayReports.where((r) => r.riskLevel == 'high').length,
        'medium': dayReports.where((r) => r.riskLevel == 'medium').length,
        'low': dayReports.where((r) => r.riskLevel == 'low').length,
      });
    }
    return result;
  }

  // Analyze image with AI (POE API)
  Future<Map<String, dynamic>?> analyzeImage(String imageBase64) async {
    try {
      return await _api.analyzeImageWithAI(imageBase64);
    } catch (e) {
      debugPrint('AI analysis failed: $e');
      return {
        'damage_detected': true,
        'category': 'structural',
        'severity': 'moderate',
        'risk_level': 'medium',
        'risk_score': 50,
        'is_urgent': false,
        'title': '建築安全問題',
        'analysis': 'AI 分析服務暫時不可用，使用本地評估',
        'recommendations': ['建議安排專業人員檢查'],
      };
    }
  }

  /// 新增報告 — 直接儲存到 Supabase，不寫入本地
  Future<ReportModel?> addReport({
    required String title,
    required String description,
    required String category,
    required String severity,
    String? imagePath,
    String? imageBase64,
    String? location,
    double? latitude,
    double? longitude,
    bool isOnline = true,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // AI 分析
      Map<String, dynamic> analysis;
      if (isOnline && imageBase64 != null) {
        try {
          analysis = await _api.analyzeImageWithAI(imageBase64);
        } catch (e) {
          analysis = ApiService.localAnalysis(severity, category);
        }
      } else {
        analysis = ApiService.localAnalysis(severity, category);
      }

      final report = ReportModel(
        title: title,
        description: description,
        category: category,
        severity: analysis['severity'] ?? severity,
        riskLevel: analysis['risk_level'] ?? 'low',
        riskScore: analysis['risk_score'] ?? 0,
        isUrgent: analysis['is_urgent'] ?? false,
        imagePath: imagePath,
        imageBase64: imageBase64,
        location: location,
        latitude: latitude,
        longitude: longitude,
        aiAnalysis: analysis['analysis'],
        synced: true,
      );

      // 直接儲存到 Supabase
      final saved = await SupabaseService.instance.createReport(
        report,
        imageBase64: imageBase64,
      );

      if (saved != null) {
        debugPrint('✅ 報告已儲存到 Supabase: id=${saved.id}');
        await loadReports();
        return saved;
      } else {
        _error = '儲存報告失敗，請檢查網路連線';
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = '提交報告失敗: $e';
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 更新報告狀態到 Supabase
  Future<bool> updateReportStatus(ReportModel report, String newStatus) async {
    try {
      if (!SupabaseService.isConfigured || report.id == null) return false;

      await SupabaseService.instance.client.from('reports').update({
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', report.id!);

      debugPrint('☁️ 狀態已更新: $newStatus');

      // 更新本地列表（不需要重新載入整份）
      final index = _reports.indexWhere((r) => r.id == report.id);
      if (index >= 0) {
        _reports[index] =
            report.copyWith(status: newStatus, updatedAt: DateTime.now());
        _statistics = _computeStatistics(_reports);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = '更新狀態失敗: $e';
      notifyListeners();
      return false;
    }
  }

  /// 從 Supabase 重新刷新（含 company_notes 最新值）
  Future<void> refreshFromCloud() async {
    await loadReports();
  }

  /// 刪除報告（從 Supabase）
  Future<bool> deleteReport(int id) async {
    try {
      await SupabaseService.instance.client
          .from('reports')
          .delete()
          .eq('id', id);
      _reports.removeWhere((r) => r.id == id);
      _statistics = _computeStatistics(_reports);
      notifyListeners();
      return true;
    } catch (e) {
      _error = '刪除報告失敗: $e';
      notifyListeners();
      return false;
    }
  }

  /// 保持向後兼容（歷史記錄頁面的同步按鈕）
  Future<int> syncAllToCloud() async {
    await loadReports();
    return _reports.length;
  }

  // Get reports filtered by risk level
  List<ReportModel> getReportsByRiskLevel(String level) {
    return _reports.where((r) => r.riskLevel == level).toList();
  }

  // Get urgent reports
  List<ReportModel> get urgentReports {
    return _reports.where((r) => r.isUrgent).toList();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
