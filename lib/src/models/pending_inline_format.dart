import 'package:flutter/painting.dart';

import '../core/document/document.dart';
import 'enums.dart';

/// Pending inline style for the next insertion when the caret has no selection.
///
/// Nullable fields ([foregroundColor], [fontSize], …) support three behaviors:
/// - **inherit** (e.g. [inheritForegroundColor] == true): use the span at the caret.
/// - **explicit value**: use [foregroundColor] / [fontSize] / ….
/// - **explicit clear** ([inheritForegroundColor] == false and value is null): no color / size / font override.
class PendingInlineFormat {
  const PendingInlineFormat({
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.isStrikethrough,
    this.inheritForegroundColor = true,
    this.foregroundColor,
    this.inheritBackgroundColor = true,
    this.backgroundColor,
    this.inheritFontSize = true,
    this.fontSize,
    this.inheritFontFamily = true,
    this.fontFamily,
  });

  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final bool isStrikethrough;

  final bool inheritForegroundColor;
  final Color? foregroundColor;

  final bool inheritBackgroundColor;
  final Color? backgroundColor;

  final bool inheritFontSize;
  final double? fontSize;

  final bool inheritFontFamily;
  final String? fontFamily;

  /// Resolves to a span used for inserting typed text at [offset] in [block].
  TextFormatSpan resolveForInsert(BlockNode block, int offset) {
    final loc = block.getSpanAt(offset);
    final at =
        loc.spanIndex < block.spans.length ? block.spans[loc.spanIndex] : block.spans.last;

    return TextFormatSpan(
      text: '',
      isBold: isBold,
      isItalic: isItalic,
      isUnderline: isUnderline,
      isStrikethrough: isStrikethrough,
      foregroundColor:
          inheritForegroundColor ? at.foregroundColor : foregroundColor,
      backgroundColor:
          inheritBackgroundColor ? at.backgroundColor : backgroundColor,
      fontSize: inheritFontSize ? at.fontSize : fontSize,
      fontFamily: inheritFontFamily ? at.fontFamily : fontFamily,
    );
  }

  /// Merges pending overrides into [formats] (from [DocumentController.getFormatAt]).
  void mergeIntoToolbarMap(Map<SmartButtonType, dynamic> formats) {
    formats[SmartButtonType.bold] = isBold;
    formats[SmartButtonType.italic] = isItalic;
    formats[SmartButtonType.underline] = isUnderline;
    formats[SmartButtonType.strikethrough] = isStrikethrough;

    if (!inheritForegroundColor) {
      formats[SmartButtonType.foregroundColor] = foregroundColor;
    }
    if (!inheritBackgroundColor) {
      formats[SmartButtonType.highlightColor] = backgroundColor;
    }
    if (!inheritFontSize) {
      formats[SmartButtonType.fontSize] = fontSize;
    }
    if (!inheritFontFamily) {
      formats[SmartButtonType.fontName] = fontFamily;
    }
  }
}
