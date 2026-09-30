import 'package:flutter/material.dart';
import '../../core/document/document.dart';
import '../../models/search/search_match.dart';

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

  // Search match highlighting
  List<SearchMatch> searchMatches = [];
  int activeSearchMatchIndex = -1;
  bool isDarkMode = false;
  Color? customSearchMatchColor;
  Color? customSearchActiveMatchColor;

  Color get _effectiveMatchColor {
    if (customSearchMatchColor != null) return customSearchMatchColor!;
    return isDarkMode
        ? const Color(0xFF6D4C41).withValues(alpha: 0.75) // warm dark amber
        : const Color(0xFFFFF176).withValues(alpha: 0.70); // soft warm yellow
  }

  Color get _effectiveActiveMatchColor {
    if (customSearchActiveMatchColor != null) {
      return customSearchActiveMatchColor!;
    }
    return isDarkMode
        ? const Color(0xFFFFB74D) // bright amber
        : const Color(0xFFFF9800); // vibrant orange
  }

  Color get _effectiveMatchTextColor {
    return isDarkMode ? const Color(0xFFFFF9C4) : Colors.black87;
  }

  Color get _effectiveActiveMatchTextColor {
    return isDarkMode ? Colors.black : Colors.white;
  }

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

    final zwspOffset = text.startsWith('\u200B') ? 1 : 0;
    if (zwspOffset > 0) {
      children.add(const TextSpan(text: '\u200B'));
      textOffset = 1;
    }

    int? getMatchingIndex(int charOffset) {
      if (charOffset < zwspOffset) return null;
      final plainOffset = charOffset - zwspOffset;
      for (var i = 0; i < searchMatches.length; i++) {
        final m = searchMatches[i];
        if (plainOffset >= m.start && plainOffset < m.end) {
          return m.matchIndex;
        }
      }
      return null;
    }

    int getNextMatchBoundary(int charOffset, int maxOffset) {
      var next = maxOffset;
      for (final m in searchMatches) {
        final mStart = m.start + zwspOffset;
        final mEnd = m.end + zwspOffset;
        if (mStart > charOffset && mStart < next) {
          next = mStart;
        }
        if (mEnd > charOffset && mEnd < next) {
          next = mEnd;
        }
      }
      return next;
    }

    void addSegment(int start, int end, TextStyle baseStyle) {
      if (start >= end) return;
      if (searchMatches.isEmpty) {
        children.add(TextSpan(
          text: text.substring(start, end),
          style: baseStyle,
        ));
        return;
      }

      var sliceStart = start;
      while (sliceStart < end) {
        final nextBoundary = getNextMatchBoundary(sliceStart, end);
        final sliceText = text.substring(sliceStart, nextBoundary);
        final matchIdx = getMatchingIndex(sliceStart);

        TextStyle sliceStyle = baseStyle;
        if (matchIdx != null) {
          final isActive = matchIdx == activeSearchMatchIndex;
          sliceStyle = sliceStyle.copyWith(
            backgroundColor:
                isActive ? _effectiveActiveMatchColor : _effectiveMatchColor,
            color: isActive
                ? _effectiveActiveMatchTextColor
                : _effectiveMatchTextColor,
          );
        }

        children.add(TextSpan(
          text: sliceText,
          style: sliceStyle,
        ));

        sliceStart = nextBoundary;
      }
    }

    for (final span in formatSpans) {
      if (textOffset >= text.length) break;

      final spanLength = span.text.length.clamp(0, text.length - textOffset);
      if (spanLength <= 0) continue;

      final spanEnd = textOffset + spanLength;
      addSegment(textOffset, spanEnd, _buildSpanStyle(span));

      textOffset = spanEnd;
    }

    if (textOffset < text.length) {
      final lastSpan =
          formatSpans.isNotEmpty ? formatSpans.last : TextFormatSpan.plain('');

      addSegment(textOffset, text.length, _buildSpanStyle(lastSpan));
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
