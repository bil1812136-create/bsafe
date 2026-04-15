import 'package:flutter/material.dart';

class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;
  String _historyFilterRisk = 'all'; // 'all', 'high', 'medium', 'low'
  String _historyFilterStatus =
      'all'; // 'all', 'pending', 'in_progress', 'resolved'

  int get currentIndex => _currentIndex;
  String get historyFilterRisk => _historyFilterRisk;
  String get historyFilterStatus => _historyFilterStatus;

  void setIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  void setHistoryFilters({String? risk, String? status}) {
    if (risk != null) _historyFilterRisk = risk;
    if (status != null) _historyFilterStatus = status;
    notifyListeners();
  }

  void clearHistoryFilters() {
    _historyFilterRisk = 'all';
    _historyFilterStatus = 'all';
    notifyListeners();
  }

  void goToHome() => setIndex(0);
  void goToReport() => setIndex(1);

  void goToHistory({String? filterRisk, String? filterStatus}) {
    setHistoryFilters(risk: filterRisk, status: filterStatus);
    setIndex(2);
  }

  void goToAnalysis() => setIndex(3);
  void goToLocation() => setIndex(4);

  // Navigate with status filter (compact version)
  void goToHistoryByStatus(String status) {
    setHistoryFilters(status: status);
    setIndex(2);
  }
}
