import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityProvider extends ChangeNotifier {
  bool _isOnline = true;
  bool _manualOfflineMode = false;
  late StreamSubscription<ConnectivityResult> _subscription;

  bool get isOnline => _manualOfflineMode ? false : _isOnline;
  bool get isManualOfflineMode => _manualOfflineMode;

  ConnectivityProvider() {
    _initConnectivity();
  }

  void _initConnectivity() {
    Connectivity().checkConnectivity().then((result) {
      _updateConnectionStatus([result]);
    });

    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      _updateConnectionStatus([result]);
    });
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);
    if (wasOnline != _isOnline) {
      notifyListeners();
    }
  }

  void toggleManualOfflineMode() {
    _manualOfflineMode = !_manualOfflineMode;
    notifyListeners();
  }

  void setManualOfflineMode(bool offline) {
    _manualOfflineMode = offline;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
