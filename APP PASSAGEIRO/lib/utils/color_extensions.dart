import 'package:flutter/material.dart';

extension ColorWithValues on Color {
  /// Replace deprecated `withOpacity` usage.
  /// If `opacity` is provided it maps to alpha (0-255).
  Color withValues({double? opacity, int? alpha}) {
    if (opacity != null) {
      final int a = (opacity * 255).round().clamp(0, 255);
      return withAlpha(a);
    }
    if (alpha != null) {
      final int a = alpha < 0 ? 0 : (alpha > 255 ? 255 : alpha);
      return withAlpha(a);
    }
    return this;
  }
}

extension ColorWithOpacityCompat on Color {
  /// Backwards-compatible helper when `.withOpacity` is deprecated.
  Color withOpacityCompat({double? opacity, int? alpha}) {
    if (opacity != null) {
      final int a = (opacity * 255).round();
      final int clamped = a < 0 ? 0 : (a > 255 ? 255 : a);
      return withAlpha(clamped);
    }
    if (alpha != null) {
      final int clamped = alpha < 0 ? 0 : (alpha > 255 ? 255 : alpha);
      return withAlpha(clamped);
    }
    return this;
  }
}
