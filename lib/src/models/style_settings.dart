import 'package:flutter/material.dart';

/// Visual appearance settings for the editor widget.
///
/// Controls the overall height, padding, decoration, and colors
/// of the editor and toolbar containers.
class SmartStyleSettings {
  const SmartStyleSettings({
    this.height = 400,
    this.decoration,
    this.editorDecoration,
    this.editorPadding = const EdgeInsets.all(12),
    this.editorBackgroundColor,
    this.toolbarDecoration,
    this.toolbarPadding,
    this.borderRadius,
  });

  /// Total height of the widget (toolbar + editor).
  /// Set to `null` for auto-height.
  final double? height;

  /// Decoration around the entire widget (toolbar + editor).
  /// Defaults to a thin rounded border.
  final BoxDecoration? decoration;

  /// Decoration around just the editor area (excludes toolbar).
  final BoxDecoration? editorDecoration;

  /// Padding inside the editor area.
  final EdgeInsets editorPadding;

  /// Background color of the editor area.
  /// `null` uses the theme's scaffold background.
  final Color? editorBackgroundColor;

  /// Decoration around just the toolbar area.
  final BoxDecoration? toolbarDecoration;

  /// Padding inside the toolbar area.
  final EdgeInsets? toolbarPadding;

  /// Global border radius applied to the entire widget if [decoration]
  /// is not provided.
  final BorderRadius? borderRadius;
}
