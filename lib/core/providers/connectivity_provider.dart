import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityState {
  const ConnectivityState({
    this.isOnline = true,
    this.isManualOfflineMode = false,
  });

  final bool isOnline;
  final bool isManualOfflineMode;

  /// Effective online status respecting manual override.
  bool get effectivelyOnline => !isManualOfflineMode && isOnline;

  ConnectivityState copyWith({bool? isOnline, bool? isManualOfflineMode}) =>
      ConnectivityState(
        isOnline: isOnline ?? this.isOnline,
        isManualOfflineMode: isManualOfflineMode ?? this.isManualOfflineMode,
      );
}

class ConnectivityNotifier extends Notifier<ConnectivityState> {
  @override
  ConnectivityState build() {
    final connectivity = Connectivity();

    connectivity.checkConnectivity().then((result) {
      state = state.copyWith(isOnline: result != ConnectivityResult.none);
    });

    final sub = connectivity.onConnectivityChanged.listen((result) {
      state = state.copyWith(isOnline: result != ConnectivityResult.none);
    });

    ref.onDispose(sub.cancel);

    return const ConnectivityState();
  }

  void toggleManualOfflineMode() =>
      state = state.copyWith(isManualOfflineMode: !state.isManualOfflineMode);

  void setManualOfflineMode(bool offline) =>
      state = state.copyWith(isManualOfflineMode: offline);
}

final connectivityNotifierProvider =
    NotifierProvider<ConnectivityNotifier, ConnectivityState>(
        ConnectivityNotifier.new);
