import 'package:flutter/material.dart';
import 'package:bsafe_app/models/report_model.dart';
import 'package:bsafe_app/services/api_service.dart';
import 'package:bsafe_app/services/supabase_service.dart';
import 'package:bsafe_app/services/realtime_service.dart';

class ReportProvider extends ChangeNotifier {
  List<ReportModel> _reports = [];
  Map<String, dynamic> _statistics = {};
  List<Map<String, dynamic>> _trendData = [];
  bool _isLoading = false;
  String? _error;
  ReportModel? _currentReport; // 正在查看的報告（用於實時監聽）

  // Getters
  List<ReportModel> get reports => _reports;
  Map<String, dynamic> get statistics => _statistics;
  List<Map<String, dynamic>> get trendData => _trendData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  ReportModel? get currentReport => _currentReport; // 獲取當前報告
  int get pendingSyncCount => 0;

  final ApiService _api = ApiService.instance;
  final RealtimeService _realtime = RealtimeService.instance;

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
      'in_progress': reports.where((r) => r.status == 'in_progress').length,
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
    Map<String, dynamic>? precomputedAnalysis,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // AI 分析：若已在 UI 端完成，優先使用該結果，避免重跑覆蓋
      Map<String, dynamic> analysis;
      if (precomputedAnalysis != null && precomputedAnalysis.isNotEmpty) {
        analysis = precomputedAnalysis;
      } else if (isOnline && imageBase64 != null) {
        try {
          analysis = await _api.analyzeImageWithAI(imageBase64);
        } catch (e) {
          analysis = ApiService.localAnalysis(severity, category);
        }
      } else {
        analysis = ApiService.localAnalysis(severity, category);
      }

      final analysisText = (analysis['analysis'] ??
              analysis['formatted_report'] ??
              analysis['description'])
          ?.toString();

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
        aiAnalysis: analysisText,
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
        'updated_at': DateTime.now().toUtc().toIso8601String(),
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

  /// 提交工人回覆並更新狀態為「處理中」— 添加到對話
  Future<bool> submitWorkerResponse(
      ReportModel report, String responseText, String? imageBase64) async {
    try {
      if (!SupabaseService.isConfigured || report.id == null) return false;

      final success = await SupabaseService.instance
          .submitWorkerResponse(report.id!, responseText, imageBase64);
      if (!success) return false;

      // 更新本地列表
      final index = _reports.indexWhere((r) => r.id == report.id);
      if (index >= 0) {
        final updatedConv =
            List<ConversationMessage>.from(_reports[index].mergedConversation);
        updatedConv.add(ConversationMessage(
          sender: 'worker',
          text: responseText,
          image: imageBase64,
          timestamp: DateTime.now(),
        ));
        _reports[index] = report.copyWith(
          status: 'in_progress',
          workerResponse: responseText,
          workerResponseImage: imageBase64,
          conversation: updatedConv,
          hasUnreadCompany: false,
          updatedAt: DateTime.now(),
        );
        _statistics = _computeStatistics(_reports);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = '提交回覆失敗: $e';
      notifyListeners();
      return false;
    }
  }

  /// 公司端添加對話訊息
  Future<bool> addCompanyMessage(ReportModel report, String messageText) async {
    try {
      if (!SupabaseService.isConfigured || report.id == null) return false;

      final success = await SupabaseService.instance
          .addCompanyMessage(report.id!, messageText);
      if (!success) return false;

      // 更新本地列表
      final index = _reports.indexWhere((r) => r.id == report.id);
      if (index >= 0) {
        final updatedConv =
            List<ConversationMessage>.from(_reports[index].mergedConversation);
        updatedConv.add(ConversationMessage(
          sender: 'company',
          text: messageText,
          timestamp: DateTime.now(),
        ));
        _reports[index] = _reports[index].copyWith(
          companyNotes: messageText,
          conversation: updatedConv,
          hasUnreadCompany: true,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = '發送訊息失敗: $e';
      notifyListeners();
      return false;
    }
  }

  /// 清除未讀標記（工人端查看報告詳情時調用）
  Future<void> clearUnreadCompany(ReportModel report) async {
    if (report.id == null || !report.hasUnreadCompany) return;
    await SupabaseService.instance.clearUnreadCompany(report.id!);
    final index = _reports.indexWhere((r) => r.id == report.id);
    if (index >= 0) {
      _reports[index] = _reports[index].copyWith(hasUnreadCompany: false);
      notifyListeners();
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

  /// 訂閱特定報告的實時更新
  /// 當對話或報告內容更新時，會自動刷新 UI
  void subscribeToReport(ReportModel report) {
    if (report.id == null) {
      debugPrint('⚠️ 無效的報告 ID，無法訂閱實時更新');
      return;
    }

    _currentReport = report;
    final reportId = report.id!;

    debugPrint('👁️ 開始訂閱報告 #$reportId 的實時更新');

    // 訂閱到 Realtime Service
    _realtime.subscribeToReport(reportId, (updatedReport) {
      // 當收到更新時，更新 _currentReport 並刷新 UI
      _currentReport = updatedReport;

      // 同時更新列表中的報告
      final index = _reports.indexWhere((r) => r.id == reportId);
      if (index >= 0) {
        _reports[index] = updatedReport;
      }

      debugPrint('🔄 報告 #$reportId 已更新（對話/狀態）');
      notifyListeners(); // 觸發 UI 刷新
    });
  }

  /// 取消訂閱當前報告的實時更新
  Future<void> unsubscribeFromCurrentReport() async {
    if (_currentReport?.id == null) return;
    final reportId = _currentReport!.id!;
    await _realtime.unsubscribeFromReport(reportId);
    _currentReport = null;
    debugPrint('✋ 已取消訂閱報告 #$reportId');
  }

  /// 更新當前報告（用於接收實時更新）
  /// 只有當報告的conversation或狀態真的改變時，才觸發UI重建
  void updateCurrentReport(ReportModel updated) {
    // 檢查是否有實際改變
    if (_currentReport != null) {
      bool hasChanged = false;

      // 比較conversation（最重要的字段 - 包含新消息和圖片）
      if (_currentReport!.conversation != updated.conversation) {
        debugPrint('🔄 Conversation 更新');
        hasChanged = true;
      }

      // 比較status
      if (_currentReport!.status != updated.status) {
        debugPrint('🔄 Status 更新');
        hasChanged = true;
      }

      // 比較severity和risk_level
      if (_currentReport!.severity != updated.severity) {
        debugPrint('🔄 Severity 更新');
        hasChanged = true;
      }

      // 比較description
      if (_currentReport!.description != updated.description) {
        debugPrint('🔄 Description 更新');
        hasChanged = true;
      }

      // 如果沒有改變，就不觸發更新
      if (!hasChanged) {
        debugPrint('ℹ️ 報告 #${updated.id} 無實際改變，跳過UI更新');
        return;
      }
    }

    // 有改變或首次設置，才更新
    _currentReport = updated;
    final index = _reports.indexWhere((r) => r.id == updated.id);
    if (index >= 0) {
      _reports[index] = updated;
    }
    notifyListeners();
  }
}
