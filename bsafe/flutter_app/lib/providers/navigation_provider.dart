import 'package:flutter/material.dart';

class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void setIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  void goToHome() => setIndex(0);
  void goToReport() => setIndex(1);
  void goToHistory() => setIndex(2);
  void goToAnalysis() => setIndex(3);
  void goToLocation() => setIndex(4);
}
