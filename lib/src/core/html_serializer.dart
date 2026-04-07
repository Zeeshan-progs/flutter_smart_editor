import 'package:flutter/painting.dart';
import '../core/document.dart';
import '../models/enums.dart';

/// Converts a [Document] tree into an HTML string.
///
/// Produces clean, minimal HTML by merging inline formatting tags
/// and only outputting attributes when they differ from defaults.
class SmartHtmlSerializer {
  SmartHtmlSerializer({this.onTagSerialize});

  /// Custom tag serialization callback.
  String? Function(
      SmartTagType type,
      String tag,
      Map<String, String> attributes,
      Map<String, String> styles,
      String content)? onTagSerialize;

  /// Serializes a [Document] into an HTML string.
  String serialize(Document document) {
    final buffer = StringBuffer();
    for (final block in document.blocks) {
      _serializeBlock(block, buffer);
    }
    return buffer.toString();
  }

  /// Serializes a single block node into the buffer
  void _serializeBlock(BlockNode block, StringBuffer buffer) {
    final tag = block.tag;
    final attributes = <String, String>{};
    final styles = _buildBlockStyle(block);

    // Serialize inline spans first to get the content
    final contentBuffer = StringBuffer();
    for (final span in block.spans) {
      _serializeSpan(span, contentBuffer);
    }

    // Wrap the block tag
    buffer.write(_wrapTag(
      SmartTagType.block,
      tag,
      attributes,
      styles,
      contentBuffer.toString(),
    ));
  }

  /// Helper to wrap content in a tag, allowing for external interception.
  String _wrapTag(
    SmartTagType type,
    String tag,
    Map<String, String> attributes,
    Map<String, String> styles,
    String content,
  ) {
    // Check for custom interceptor
    final custom = onTagSerialize?.call(type, tag, attributes, styles, content);
    if (custom != null) return custom;

    // Default serialization: Merge styles into attributes if not handled by callback
    if (styles.isNotEmpty) {
      final styleString = styles.entries.map((e) => '${e.key}: ${e.value}').join('; ');
      attributes['style'] = styleString;
    }

    final attrString = attributes.entries
        .map((e) => ' ${e.key}="${_escapeAttr(e.value)}"')
        .join('');
    return '<$tag$attrString>$content</$tag>';
  }

  /// Builds the CSS style map for a block
  Map<String, String> _buildBlockStyle(BlockNode block) {
    final styles = <String, String>{};
    if (block.alignment != SmartTextAlign.left) {
      styles['text-align'] = _alignToCSS(block.alignment);
    }
    return styles;
  }

  /// Converts a [SmartTextAlign] to a CSS value
  String _alignToCSS(SmartTextAlign align) {
    switch (align) {
      case SmartTextAlign.left:
        return 'left';
      case SmartTextAlign.center:
        return 'center';
      case SmartTextAlign.right:
        return 'right';
      case SmartTextAlign.justify:
        return 'justify';
    }
  }

  /// Serializes a single inline span, wrapping text in formatting tags
  void _serializeSpan(TextFormatSpan span, StringBuffer buffer) {
    if (span.text.isEmpty) return;

    String content = _escapeHtml(span.text);

    // 1. Generic Span (Colors, Fonts) - Innermost
    final inlineStyles = <String, String>{};
    if (span.foregroundColor != null) {
      inlineStyles['color'] = '#${_colorToHex(span.foregroundColor!)}';
    }
    if (span.backgroundColor != null) {
      inlineStyles['background-color'] = '#${_colorToHex(span.backgroundColor!)}';
    }
    if (span.fontSize != null) {
      inlineStyles['font-size'] = '${span.fontSize}px';
    }
    if (span.fontFamily != null) {
      inlineStyles['font-family'] = span.fontFamily!;
    }

    if (inlineStyles.isNotEmpty) {
      content = _wrapTag(
        SmartTagType.span,
        'span',
        {},
        inlineStyles,
        content,
      );
    }

    // 2. Strikethrough
    if (span.isStrikethrough) {
      content = _wrapTag(SmartTagType.strikethrough, 's', {}, {}, content);
    }

    // 3. Underline
    if (span.isUnderline) {
      content = _wrapTag(SmartTagType.underline, 'u', {}, {}, content);
    }

    // 4. Italic
    if (span.isItalic) {
      content = _wrapTag(SmartTagType.italic, 'i', {}, {}, content);
    }

    // 5. Bold
    if (span.isBold) {
      content = _wrapTag(SmartTagType.bold, 'b', {}, {}, content);
    }

    // 6. Link wrapping (outermost)
    if (span.linkUrl != null && span.linkUrl!.isNotEmpty) {
      content = _wrapTag(
        SmartTagType.link,
        'a',
        {'href': span.linkUrl!},
        {},
        content,
      );
    }

    buffer.write(content);
  }

  /// Converts a Color to a hex string (RRGGBB)
  String _colorToHex(Color color) {
    // ignore: deprecated_member_use
    return color.value.toRadixString(16).padLeft(8, '0').substring(2);
  }

  /// Escapes special HTML characters in text
  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  /// Escapes special characters in attribute values
  String _escapeAttr(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}
