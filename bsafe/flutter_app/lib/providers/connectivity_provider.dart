import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityProvider extends ChangeNotifier {
  bool _isOnline = true;
  bool _manualOfflineMode = false; // 手動離線模式
  late StreamSubscription<ConnectivityResult> _subscription;

  bool get isOnline => _manualOfflineMode ? false : _isOnline;
  bool get isManualOfflineMode => _manualOfflineMode;

  ConnectivityProvider() {
    _initConnectivity();
  }

  void _initConnectivity() {
    // Check initial connectivity
    Connectivity().checkConnectivity().then((result) {
      _updateConnectionStatus([result]);
    });

    // Listen for connectivity changes
    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      _updateConnectionStatus([result]);
    });
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.isNotEmpty && 
                !results.contains(ConnectivityResult.none);
    
    if (wasOnline != _isOnline) {
      notifyListeners();
    }
  }

  // 切換手動離線模式
  void toggleManualOfflineMode() {
    _manualOfflineMode = !_manualOfflineMode;
    notifyListeners();
  }

  // 設置手動離線模式
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
