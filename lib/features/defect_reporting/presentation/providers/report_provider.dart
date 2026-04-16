import 'package:flutter/material.dart';
import 'package:bsafe_app/core/usecases/usecase.dart';
import 'package:bsafe_app/features/defect_reporting/data/datasources/report_remote_datasource.dart';
import 'package:bsafe_app/features/defect_reporting/data/models/report_model.dart';
import 'package:bsafe_app/features/defect_reporting/data/repositories/report_repository_impl.dart';
import 'package:bsafe_app/features/defect_reporting/domain/entities/report.dart';
import 'package:bsafe_app/features/defect_reporting/domain/usecases/create_report.dart';
import 'package:bsafe_app/features/defect_reporting/domain/usecases/get_reports.dart';
import 'package:bsafe_app/features/defect_reporting/domain/usecases/submit_worker_response.dart';
import 'package:bsafe_app/features/defect_reporting/domain/usecases/update_report_status.dart';
import 'package:bsafe_app/features/ai_analysis/data/datasources/ai_remote_datasource.dart';

/// Presentation-layer state manager for the defect-reporting feature.
/// Bridges use-cases with the Flutter widget tree via [ChangeNotifier].
class ReportProvider extends ChangeNotifier {
  // ── Use-cases (injected) ────────────────────────────────
  late final GetReports _getReports;
  late final CreateReport _createReport;
  late final UpdateReportStatus _updateStatus;
  late final SubmitWorkerResponse _submitWorkerResponse;
  final AiRemoteDataSource _ai = AiRemoteDataSource.instance;

  ReportProvider() {
    final repo = ReportRepositoryImpl(ReportRemoteDataSource.instance);
    _getReports = GetReports(repo);
    _createReport = CreateReport(repo);
    _updateStatus = UpdateReportStatus(repo);
    _submitWorkerResponse = SubmitWorkerResponse(repo);
    loadReports();
  }

  // ── State ───────────────────────────────────────────────
  List<Report> _reports = [];
  Map<String, dynamic> _statistics = {};
  List<Map<String, dynamic>> _trendData = [];
  bool _isLoading = false;
  String? _error;
  ReportModel? _currentReport;

  List<ReportModel> get reports => _reports.cast<ReportModel>();
  Map<String, dynamic> get statistics => _statistics;
  List<Map<String, dynamic>> get trendData => _trendData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  ReportModel? get currentReport => _currentReport;
  int get pendingSyncCount => 0;

  // ── Load ────────────────────────────────────────────────

  Future<void> loadReports() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _reports = await _getReports(const NoParams());
      _statistics = _computeStatistics(_reports);
      _trendData = _computeTrendData(_reports);
      debugPrint('✅ ReportProvider: loaded ${_reports.length} reports');
    } catch (e) {
      _error = '載入資料失敗: $e';
      debugPrint('❌ ReportProvider.loadReports: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshFromCloud() => loadReports();

  // ── AI analysis ─────────────────────────────────────────

  Future<Map<String, dynamic>?> analyzeImage(String imageBase64) async {
    try {
      return await _ai.analyzeImage(imageBase64);
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

  // ── Create report ───────────────────────────────────────

  Future<Report?> addReport({
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
      Map<String, dynamic> analysis;
      if (precomputedAnalysis != null && precomputedAnalysis.isNotEmpty) {
        analysis = precomputedAnalysis;
      } else if (isOnline && imageBase64 != null) {
        try {
          analysis = await _ai.analyzeImage(imageBase64);
        } catch (_) {
          analysis = AiRemoteDataSource.localFallback(severity, category);
        }
      } else {
        analysis = AiRemoteDataSource.localFallback(severity, category);
      }

      final analysisText = (analysis['analysis'] ??
              analysis['formatted_report'] ??
              analysis['description'])
          ?.toString();

      final report = Report(
        title: title,
        description: description,
        category: category,
        severity: analysis['severity'] as String? ?? severity,
        riskLevel: analysis['risk_level'] as String? ?? 'low',
        riskScore: analysis['risk_score'] as int? ?? 0,
        isUrgent: analysis['is_urgent'] as bool? ?? false,
        imagePath: imagePath,
        imageBase64: imageBase64,
        location: location,
        latitude: latitude,
        longitude: longitude,
        aiAnalysis: analysisText,
        createdAt: DateTime.now(),
        synced: true,
      );

      final saved = await _createReport(
        CreateReportParams(report: report, imageBase64: imageBase64),
      );

      if (saved != null) {
        await loadReports();
        return saved;
      }
      _error = '儲存報告失敗，請檢查網路連線';
      notifyListeners();
      return null;
    } catch (e) {
      _error = '提交報告失敗: $e';
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Update status ───────────────────────────────────────

  Future<bool> updateReportStatus(Report report, String newStatus) async {
    try {
      if (report.id == null) return false;
      final ok = await _updateStatus(
        UpdateReportStatusParams(id: report.id!, newStatus: newStatus),
      );
      if (ok) {
        final index = _reports.indexWhere((r) => r.id == report.id);
        if (index >= 0) {
          _reports[index] =
              report.copyWith(status: newStatus, updatedAt: DateTime.now());
          _statistics = _computeStatistics(_reports);
          notifyListeners();
        }
      }
      return ok;
    } catch (e) {
      _error = '更新狀態失敗: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Worker response ─────────────────────────────────────

  Future<bool> submitWorkerResponse(
      Report report, String text, String? imageBase64) async {
    try {
      if (report.id == null) return false;
      final ok = await _submitWorkerResponse(
        SubmitWorkerResponseParams(
          reportId: report.id!,
          text: text,
          imageBase64: imageBase64,
        ),
      );
      if (ok) {
        final index = _reports.indexWhere((r) => r.id == report.id);
        if (index >= 0) {
          final updatedConv =
              List<ConversationMessage>.from(_reports[index].mergedConversation)
                ..add(ConversationMessage(
                  sender: 'worker',
                  text: text,
                  image: imageBase64,
                  timestamp: DateTime.now(),
                ));
          _reports[index] = report.copyWith(
            status: 'in_progress',
            workerResponse: text,
            workerResponseImage: imageBase64,
            conversation: updatedConv,
            hasUnreadCompany: false,
            updatedAt: DateTime.now(),
          );
          _statistics = _computeStatistics(_reports);
          notifyListeners();
        }
      }
      return ok;
    } catch (e) {
      _error = '提交回覆失敗: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Company message ─────────────────────────────────────

  Future<bool> addCompanyMessage(Report report, String message) async {
    try {
      if (report.id == null) return false;
      final repo = ReportRepositoryImpl(ReportRemoteDataSource.instance);
      final ok = await repo.addCompanyMessage(report.id!, message);
      if (ok) {
        final index = _reports.indexWhere((r) => r.id == report.id);
        if (index >= 0) {
          final updatedConv =
              List<ConversationMessage>.from(_reports[index].mergedConversation)
                ..add(ConversationMessage(
                  sender: 'company',
                  text: message,
                  timestamp: DateTime.now(),
                ));
          _reports[index] = _reports[index].copyWith(
            companyNotes: message,
            conversation: updatedConv,
            hasUnreadCompany: true,
            updatedAt: DateTime.now(),
          );
          notifyListeners();
        }
      }
      return ok;
    } catch (e) {
      _error = '發送訊息失敗: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Clear unread ────────────────────────────────────────

  Future<void> clearUnreadCompany(Report report) async {
    if (report.id == null || !report.hasUnreadCompany) return;
    final repo = ReportRepositoryImpl(ReportRemoteDataSource.instance);
    await repo.clearUnreadCompany(report.id!);
    final index = _reports.indexWhere((r) => r.id == report.id);
    if (index >= 0) {
      _reports[index] = _reports[index].copyWith(hasUnreadCompany: false);
      notifyListeners();
    }
  }

  Future<int> syncAllToCloud() async => 0;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Real-time subscription stubs ────────────────────────

  void subscribeToReport(ReportModel report) {
    if (report.id == null) return;
    _currentReport = report;
    // Full realtime wiring is done via RealtimeService (notification feature).
    // The datasource poll interval keeps data fresh for now.
    notifyListeners();
  }

  Future<void> unsubscribeFromCurrentReport() async {
    _currentReport = null;
    notifyListeners();
  }

  // ── Statistics helpers ──────────────────────────────────

  Map<String, dynamic> _computeStatistics(List<Report> reports) => {
        'total': reports.length,
        'highRisk': reports.where((r) => r.riskLevel == 'high').length,
        'mediumRisk': reports.where((r) => r.riskLevel == 'medium').length,
        'lowRisk': reports.where((r) => r.riskLevel == 'low').length,
        'urgent': reports.where((r) => r.isUrgent).length,
        'pending': reports.where((r) => r.status == 'pending').length,
        'in_progress': reports.where((r) => r.status == 'in_progress').length,
        'resolved': reports.where((r) => r.status == 'resolved').length,
      };

  List<Map<String, dynamic>> _computeTrendData(List<Report> reports) {
    final result = <Map<String, dynamic>>[];
    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final day = reports
          .where((r) => r.createdAt.toIso8601String().startsWith(dateStr))
          .toList();
      result.add({
        'date': '${date.month}/${date.day}',
        'total': day.length,
        'high': day.where((r) => r.riskLevel == 'high').length,
        'medium': day.where((r) => r.riskLevel == 'medium').length,
        'low': day.where((r) => r.riskLevel == 'low').length,
      });
    }
    return result;
  }
}
