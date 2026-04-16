import 'package:flutter/material.dart';

/// Common Dart extensions used across the app.
extension StringExtension on String {
  /// Capitalises the first character of the string.
  String get capitalised =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  /// Returns true if the string is not empty after trimming.
  bool get isNotBlank => trim().isNotEmpty;
}

extension DateTimeExtension on DateTime {
  /// Returns a simple formatted string e.g. "2026-04-16 14:32".
  String get formatted {
    final y = year.toString().padLeft(4, '0');
    final mo = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    final h = hour.toString().padLeft(2, '0');
    final mi = minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  }

  /// Same format used in sortable filenames: "20260416_1432".
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
  /// Returns `withValues(alpha: opacity)` – shorthand for readability.
  Color withOpacity2(double opacity) => withValues(alpha: opacity);
}

extension BuildContextExtension on BuildContext {
  /// Screen width shorthand.
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Screen height shorthand.
  double get screenHeight => MediaQuery.of(this).size.height;

  bool get isMobile => screenWidth < 600;
  bool get isTablet => screenWidth >= 600 && screenWidth < 1200;
  bool get isDesktop => screenWidth >= 1200;
}
