import 'package:flutter/material.dart';
import 'package:bsafe_app/models/report_model.dart';
import 'package:bsafe_app/services/database_service.dart';
import 'package:bsafe_app/services/api_service.dart';

class ReportProvider extends ChangeNotifier {
  List<ReportModel> _reports = [];
  Map<String, dynamic> _statistics = {};
  List<Map<String, dynamic>> _trendData = [];
  bool _isLoading = false;
  String? _error;
  int _pendingSyncCount = 0;

  // Getters
  List<ReportModel> get reports => _reports;
  Map<String, dynamic> get statistics => _statistics;
  List<Map<String, dynamic>> get trendData => _trendData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get pendingSyncCount => _pendingSyncCount;

  final DatabaseService _db = DatabaseService.instance;
  final ApiService _api = ApiService.instance;

  ReportProvider() {
    loadReports();
  }

  // Load all reports from local database
  Future<void> loadReports() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _reports = await _db.getAllReports();
      _statistics = await _db.getStatistics();
      _trendData = await _db.getTrendData();
      
      final syncQueue = await _db.getPendingSyncQueue();
      _pendingSyncCount = syncQueue.length;
    } catch (e) {
      _error = '載入資料失敗: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Analyze image with AI (POE API)
  Future<Map<String, dynamic>?> analyzeImage(String imageBase64) async {
    try {
      final analysis = await _api.analyzeImageWithAI(imageBase64);
      return analysis;
    } catch (e) {
      print('AI analysis failed: $e');
      // Return fallback local analysis
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

  // Add a new report
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
      // Perform AI analysis or local analysis
      Map<String, dynamic> analysis;
      
      if (isOnline && imageBase64 != null) {
        try {
          analysis = await _api.analyzeImageWithAI(imageBase64);
        } catch (e) {
          // Fallback to local analysis
          analysis = ApiService.localAnalysis(severity, category);
        }
      } else {
        analysis = ApiService.localAnalysis(severity, category);
      }

      // Create report with analysis results
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
        synced: false,
      );

      // Save to local database
      final id = await _db.insertReport(report);
      final savedReport = report.copyWith(id: id);

      // Try to sync if online
      if (isOnline) {
        try {
          await _api.submitReport(savedReport);
          await _db.markReportAsSynced(id);
        } catch (e) {
          // Will sync later
          _pendingSyncCount++;
        }
      } else {
        _pendingSyncCount++;
      }

      // Reload reports
      await loadReports();
      
      return savedReport;
    } catch (e) {
      _error = '提交報告失敗: $e';
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update report
  Future<bool> updateReport(ReportModel report) async {
    try {
      await _db.updateReport(report);
      await loadReports();
      return true;
    } catch (e) {
      _error = '更新報告失敗: $e';
      notifyListeners();
      return false;
    }
  }

  // Delete report
  Future<bool> deleteReport(int id) async {
    try {
      await _db.deleteReport(id);
      await loadReports();
      return true;
    } catch (e) {
      _error = '刪除報告失敗: $e';
      notifyListeners();
      return false;
    }
  }

  // Sync pending reports
  Future<void> syncPendingReports() async {
    if (_pendingSyncCount == 0) return;

    _isLoading = true;
    notifyListeners();

    try {
      final unsyncedReports = await _db.getUnsyncedReports();
      
      for (final report in unsyncedReports) {
        try {
          await _api.submitReport(report);
          if (report.id != null) {
            await _db.markReportAsSynced(report.id!);
          }
        } catch (e) {
          // Continue with other reports
          print('Failed to sync report ${report.id}: $e');
        }
      }

      await _db.clearSyncQueue();
      await loadReports();
    } catch (e) {
      _error = '同步失敗: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
