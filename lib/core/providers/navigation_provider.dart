import 'package:flutter_riverpod/flutter_riverpod.dart';

class NavigationState {
  const NavigationState({
    this.currentIndex = 0,
    this.historyFilterRisk = 'all',
    this.historyFilterStatus = 'all',
  });

  final int currentIndex;
  final String historyFilterRisk;
  final String historyFilterStatus;

  NavigationState copyWith({
    int? currentIndex,
    String? historyFilterRisk,
    String? historyFilterStatus,
  }) =>
      NavigationState(
        currentIndex: currentIndex ?? this.currentIndex,
        historyFilterRisk: historyFilterRisk ?? this.historyFilterRisk,
        historyFilterStatus: historyFilterStatus ?? this.historyFilterStatus,
      );
}

class NavigationNotifier extends Notifier<NavigationState> {
  @override
  NavigationState build() => const NavigationState();

  void setIndex(int index) => state = state.copyWith(currentIndex: index);

  void setHistoryFilters({String? risk, String? status}) =>
      state = state.copyWith(
        historyFilterRisk: risk ?? state.historyFilterRisk,
        historyFilterStatus: status ?? state.historyFilterStatus,
      );

  void clearHistoryFilters() => state = state.copyWith(
        historyFilterRisk: 'all',
        historyFilterStatus: 'all',
      );

  void goToHome() => setIndex(0);
  void goToReport() => setIndex(1);

  void goToHistory({String? filterRisk, String? filterStatus}) {
    setHistoryFilters(risk: filterRisk, status: filterStatus);
    setIndex(2);
  }

  void goToLocation() => setIndex(4);

  void goToHistoryByStatus(String status) {
    setHistoryFilters(status: status);
    setIndex(2);
  }
}

final navigationNotifierProvider =
    NotifierProvider<NavigationNotifier, NavigationState>(
        NavigationNotifier.new);
