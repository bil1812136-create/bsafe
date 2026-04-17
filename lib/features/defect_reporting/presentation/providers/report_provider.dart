import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bsafe_app/core/usecases/usecase.dart';
import 'package:bsafe_app/features/defect_reporting/data/datasources/report_remote_datasource.dart';
import 'package:bsafe_app/features/defect_reporting/data/models/report_model.dart';
import 'package:bsafe_app/features/defect_reporting/data/repositories/report_repository_impl.dart';
import 'package:bsafe_app/features/defect_reporting/domain/entities/report.dart';
import 'package:bsafe_app/features/defect_reporting/domain/usecases/create_report.dart';
import 'package:bsafe_app/features/defect_reporting/domain/usecases/get_reports.dart';
import 'package:bsafe_app/features/defect_reporting/domain/usecases/submit_worker_response.dart';
import 'package:bsafe_app/features/defect_reporting/domain/usecases/update_report_status.dart';
import 'package:bsafe_app/features/ai/analysis/data/datasources/ai_remote_datasource.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class ReportState {
  const ReportState({
    this.reports = const [],
    this.statistics = const {},
    this.trendData = const [],
    this.isLoading = false,
    this.error,
    this.currentReport,
  });

  final List<ReportModel> reports;
  final Map<String, dynamic> statistics;
  final List<Map<String, dynamic>> trendData;
  final bool isLoading;
  final String? error;
  final ReportModel? currentReport;

  int get pendingSyncCount => 0;

  ReportState copyWith({
    List<ReportModel>? reports,
    Map<String, dynamic>? statistics,
    List<Map<String, dynamic>>? trendData,
    bool? isLoading,
    Object? error = _sentinel,
    Object? currentReport = _sentinel,
  }) =>
      ReportState(
        reports: reports ?? this.reports,
        statistics: statistics ?? this.statistics,
        trendData: trendData ?? this.trendData,
        isLoading: isLoading ?? this.isLoading,
        error: error == _sentinel ? this.error : error as String?,
        currentReport: currentReport == _sentinel
            ? this.currentReport
            : currentReport as ReportModel?,
      );
}

const _sentinel = Object();

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class ReportNotifier extends Notifier<ReportState> {
  late final GetReports _getReports;
  late final CreateReport _createReport;
  late final UpdateReportStatus _updateStatus;
  late final SubmitWorkerResponse _submitWorkerResponse;
  final AiRemoteDataSource _ai = AiRemoteDataSource.instance;

  @override
  ReportState build() {
    final repo = ReportRepositoryImpl(ReportRemoteDataSource.instance);
    _getReports = GetReports(repo);
    _createReport = CreateReport(repo);
    _updateStatus = UpdateReportStatus(repo);
    _submitWorkerResponse = SubmitWorkerResponse(repo);
    Future.microtask(loadReports);
    return const ReportState(isLoading: true);
  }

  Future<void> loadReports() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final reports = await _getReports(const NoParams());
      final typedReports = reports.cast<ReportModel>();
      state = state.copyWith(
        isLoading: false,
        reports: typedReports,
        statistics: _computeStatistics(typedReports),
        trendData: _computeTrendData(typedReports),
      );
      debugPrint('✅ ReportNotifier: loaded ${typedReports.length} reports');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '載入資料失敗: $e');
      debugPrint('❌ ReportNotifier.loadReports: $e');
    }
  }

  Future<void> refreshFromCloud() => loadReports();

  Future<Map<String, dynamic>?> analyzeImage(String imageBase64,
      {String? yoloContext}) async {
    try {
      return await _ai.analyzeImage(imageBase64,
          additionalContext: yoloContext);
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
    state = state.copyWith(isLoading: true, error: null);
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
      state = state.copyWith(isLoading: false, error: '儲存報告失敗，請檢查網路連線');
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '提交報告失敗: $e');
      return null;
    }
  }

  Future<bool> updateReportStatus(Report report, String newStatus) async {
    try {
      if (report.id == null) return false;
      final ok = await _updateStatus(
        UpdateReportStatusParams(id: report.id!, newStatus: newStatus),
      );
      if (ok) {
        final updated = List<ReportModel>.from(state.reports);
        final index = updated.indexWhere((r) => r.id == report.id);
        if (index >= 0) {
          updated[index] = report.copyWith(
              status: newStatus, updatedAt: DateTime.now()) as ReportModel;
          state = state.copyWith(
            reports: updated,
            statistics: _computeStatistics(updated),
          );
        }
      }
      return ok;
    } catch (e) {
      state = state.copyWith(error: '更新狀態失敗: $e');
      return false;
    }
  }

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
        final updated = List<ReportModel>.from(state.reports);
        final index = updated.indexWhere((r) => r.id == report.id);
        if (index >= 0) {
          final updatedConv =
              List<ConversationMessage>.from(updated[index].mergedConversation)
                ..add(ConversationMessage(
                  sender: 'worker',
                  text: text,
                  image: imageBase64,
                  timestamp: DateTime.now(),
                ));
          updated[index] = report.copyWith(
            status: 'in_progress',
            workerResponse: text,
            workerResponseImage: imageBase64,
            conversation: updatedConv,
            hasUnreadCompany: false,
            updatedAt: DateTime.now(),
          ) as ReportModel;
          state = state.copyWith(
            reports: updated,
            statistics: _computeStatistics(updated),
          );
        }
      }
      return ok;
    } catch (e) {
      state = state.copyWith(error: '提交回覆失敗: $e');
      return false;
    }
  }

  Future<bool> addCompanyMessage(Report report, String message) async {
    try {
      if (report.id == null) return false;
      final repo = ReportRepositoryImpl(ReportRemoteDataSource.instance);
      final ok = await repo.addCompanyMessage(report.id!, message);
      if (ok) {
        final updated = List<ReportModel>.from(state.reports);
        final index = updated.indexWhere((r) => r.id == report.id);
        if (index >= 0) {
          final updatedConv =
              List<ConversationMessage>.from(updated[index].mergedConversation)
                ..add(ConversationMessage(
                  sender: 'company',
                  text: message,
                  timestamp: DateTime.now(),
                ));
          updated[index] = updated[index].copyWith(
            companyNotes: message,
            conversation: updatedConv,
            hasUnreadCompany: true,
            updatedAt: DateTime.now(),
          ) as ReportModel;
          state = state.copyWith(reports: updated);
        }
      }
      return ok;
    } catch (e) {
      state = state.copyWith(error: '發送訊息失敗: $e');
      return false;
    }
  }

  Future<void> clearUnreadCompany(Report report) async {
    if (report.id == null || !(report as ReportModel).hasUnreadCompany) return;
    final repo = ReportRepositoryImpl(ReportRemoteDataSource.instance);
    await repo.clearUnreadCompany(report.id!);
    final updated = List<ReportModel>.from(state.reports);
    final index = updated.indexWhere((r) => r.id == report.id);
    if (index >= 0) {
      updated[index] =
          updated[index].copyWith(hasUnreadCompany: false) as ReportModel;
      state = state.copyWith(reports: updated);
    }
  }

  Future<int> syncAllToCloud() async => 0;

  void clearError() => state = state.copyWith(error: null);

  void subscribeToReport(ReportModel report) =>
      state = state.copyWith(currentReport: report);

  Future<void> unsubscribeFromCurrentReport() async =>
      state = state.copyWith(currentReport: null);

  // ── Private helpers ──────────────────────────────────────────────────────

  Map<String, dynamic> _computeStatistics(List<ReportModel> reports) => {
        'total': reports.length,
        'highRisk': reports.where((r) => r.riskLevel == 'high').length,
        'mediumRisk': reports.where((r) => r.riskLevel == 'medium').length,
        'lowRisk': reports.where((r) => r.riskLevel == 'low').length,
        'urgent': reports.where((r) => r.isUrgent).length,
        'pending': reports.where((r) => r.status == 'pending').length,
        'in_progress': reports.where((r) => r.status == 'in_progress').length,
        'resolved': reports.where((r) => r.status == 'resolved').length,
      };

  List<Map<String, dynamic>> _computeTrendData(List<ReportModel> reports) {
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

final reportNotifierProvider =
    NotifierProvider<ReportNotifier, ReportState>(ReportNotifier.new);
