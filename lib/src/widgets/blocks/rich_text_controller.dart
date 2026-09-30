import 'package:flutter/material.dart';
import '../../core/document/document.dart';

/// A custom [TextEditingController] that renders [TextFormatSpan]s as Flutter [TextSpan]s.
///
/// This controller translates the internal document formatting model into
/// the visual representation used by a standard [TextField].
class SmartTextEditingController extends TextEditingController {
  SmartTextEditingController({super.text});

  void refresh() => notifyListeners();

  List<TextFormatSpan> formatSpans = [];
  double baseFontSize = 16.0;
  FontWeight baseFontWeight = FontWeight.normal;
  Color defaultColor = Colors.black;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (formatSpans.isEmpty || text.isEmpty) {
      return TextSpan(
        text: text,
        style: style?.copyWith(
          fontSize: baseFontSize,
          fontWeight: baseFontWeight,
          color: defaultColor,
        ),
      );
    }

    final children = <TextSpan>[];
    var textOffset = 0;

    if (text.startsWith('\u200B')) {
      children.add(const TextSpan(text: '\u200B'));
      textOffset = 1;
    }

    for (final span in formatSpans) {
      if (textOffset >= text.length) break;

      final spanLength = span.text.length.clamp(0, text.length - textOffset);
      if (spanLength <= 0) continue;

      final spanText = text.substring(textOffset, textOffset + spanLength);

      children.add(TextSpan(
        text: spanText,
        style: _buildSpanStyle(span),
      ));

      textOffset += spanLength;
    }

    if (textOffset < text.length) {
      final lastSpan =
          formatSpans.isNotEmpty ? formatSpans.last : TextFormatSpan.plain('');

      children.add(TextSpan(
        text: text.substring(textOffset),
        style: _buildSpanStyle(lastSpan),
      ));
    }

    return TextSpan(
      style: style,
      children: children,
    );
  }

  TextStyle _buildSpanStyle(TextFormatSpan span) {
    final hasLink = span.linkUrl != null && span.linkUrl!.isNotEmpty;
    final decorations = <TextDecoration>[];
    if (span.isUnderline || hasLink) decorations.add(TextDecoration.underline);
    if (span.isStrikethrough) decorations.add(TextDecoration.lineThrough);

    const linkColor = Color(0xFF1E88E5);
    final effectiveColor =
        span.foregroundColor ?? (hasLink ? linkColor : defaultColor);

    return TextStyle(
      fontWeight: span.isBold || baseFontWeight == FontWeight.bold
          ? FontWeight.bold
          : FontWeight.normal,
      fontStyle: span.isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: decorations.isEmpty
          ? TextDecoration.none
          : TextDecoration.combine(decorations),
      fontSize: span.fontSize ?? baseFontSize,
      color: effectiveColor,
      backgroundColor: span.backgroundColor,
      fontFamily: span.fontFamily,
    );
  }
}
