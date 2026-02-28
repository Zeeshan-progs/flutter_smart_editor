import 'package:flutter/material.dart';

/// Scroll behavior settings for the editor.
///
/// Controls how the editor handles scrolling, auto-height adjustment,
/// and visibility when focused.
class SmartScrollSettings {
  const SmartScrollSettings({
    this.autoAdjustHeight = true,
    this.ensureVisible = false,
    this.scrollPhysics,
    this.maxHeight,
    this.minHeight = 100,
  });

  /// Automatically adjusts editor height to fit content,
  /// eliminating internal scrollbars.
  final bool autoAdjustHeight;

  /// If `true`, scrolls the editor into view when it gains focus.
  /// Only works when the editor is inside a scrollable parent
  /// like `SingleChildScrollView` or `ListView`.
  final bool ensureVisible;

  /// Custom scroll physics for the editor's internal scroll view
  final ScrollPhysics? scrollPhysics;

  /// Maximum height of the editor area before it starts scrolling internally.
  /// `null` = no maximum (grows indefinitely when `autoAdjustHeight` is true).
  final double? maxHeight;

  /// Minimum height of the editor area.
  final double minHeight;
}
