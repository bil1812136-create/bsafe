import 'package:flutter/material.dart';

extension StringExtension on String {

  String get capitalised =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  bool get isNotBlank => trim().isNotEmpty;
}

extension DateTimeExtension on DateTime {

  String get formatted {
    final y = year.toString().padLeft(4, '0');
    final mo = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    final h = hour.toString().padLeft(2, '0');
    final mi = minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  }

  String get fileStamp {
    final y = year.toString().padLeft(4, '0');
    final mo = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    final h = hour.toString().padLeft(2, '0');
    final mi = minute.toString().padLeft(2, '0');
    return '$y$mo${d}_$h$mi';
  }
}

extension ColorExtension on Color {

  Color withOpacity2(double opacity) => withValues(alpha: opacity);
}

extension BuildContextExtension on BuildContext {

  double get screenWidth => MediaQuery.of(this).size.width;

  double get screenHeight => MediaQuery.of(this).size.height;

  bool get isMobile => screenWidth < 600;
  bool get isTablet => screenWidth >= 600 && screenWidth < 1200;
  bool get isDesktop => screenWidth >= 1200;
}
