import 'package:flutter/material.dart';

/// Selection and cursor appearance settings.
///
/// Controls how the text cursor and selection highlighting look.
class SmartSelectionSettings {
  const SmartSelectionSettings({
    this.selectionColor,
    this.cursorColor,
    this.cursorWidth = 2.0,
    this.cursorRadius,
    this.cursorHeight,
    this.showCursor = true,
    this.selectionHandleColor,
    this.enableInteractiveSelection = true,
  });

  /// Background color of selected text.
  /// Defaults to the theme's selection color.
  final Color? selectionColor;

  /// Color of the text cursor/caret.
  /// Defaults to the theme's primary color.
  final Color? cursorColor;

  /// Width of the cursor in logical pixels.
  final double cursorWidth;

  /// Rounded corners for the cursor.
  final Radius? cursorRadius;

  /// Height of the cursor. `null` uses default.
  final double? cursorHeight;

  /// Whether to show the cursor at all.
  final bool showCursor;

  /// Color of the selection drag handles on mobile.
  /// Defaults to the theme's primary color.
  final Color? selectionHandleColor;

  /// Whether the user can interactively select text.
  final bool enableInteractiveSelection;
}
