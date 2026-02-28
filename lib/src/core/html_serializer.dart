import '../core/document.dart';
import '../models/enums.dart';

/// Converts a [Document] tree into an HTML string.
///
/// Produces clean, minimal HTML by merging inline formatting tags
/// and only outputting attributes when they differ from defaults.
class SmartHtmlSerializer {
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

    // Build style attribute
    final styleAttr = _buildBlockStyle(block);
    if (styleAttr.isNotEmpty) {
      buffer.write('<$tag style="$styleAttr">');
    } else {
      buffer.write('<$tag>');
    }

    // Serialize inline spans
    for (final span in block.spans) {
      _serializeSpan(span, buffer);
    }

    buffer.write('</$tag>');
  }

  /// Builds the CSS style string for a block
  String _buildBlockStyle(BlockNode block) {
    final styles = <String>[];
    if (block.alignment != SmartTextAlign.left) {
      styles.add('text-align: ${_alignToCSS(block.alignment)}');
    }
    return styles.join('; ');
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

    final openTags = <String>[];
    final closeTags = <String>[];

    // Link wrapping (outermost)
    if (span.linkUrl != null && span.linkUrl!.isNotEmpty) {
      openTags.add('<a href="${_escapeAttr(span.linkUrl!)}">');
      closeTags.insert(0, '</a>');
    }

    // Bold
    if (span.isBold) {
      openTags.add('<b>');
      closeTags.insert(0, '</b>');
    }

    // Italic
    if (span.isItalic) {
      openTags.add('<i>');
      closeTags.insert(0, '</i>');
    }

    // Underline
    if (span.isUnderline) {
      openTags.add('<u>');
      closeTags.insert(0, '</u>');
    }

    // Strikethrough
    if (span.isStrikethrough) {
      openTags.add('<s>');
      closeTags.insert(0, '</s>');
    }

    // Superscript
    if (span.isSuperscript) {
      openTags.add('<sup>');
      closeTags.insert(0, '</sup>');
    }

    // Subscript
    if (span.isSubscript) {
      openTags.add('<sub>');
      closeTags.insert(0, '</sub>');
    }

    // Write opening tags
    for (final tag in openTags) {
      buffer.write(tag);
    }

    // Write text (escaped)
    buffer.write(_escapeHtml(span.text));

    // Write closing tags
    for (final tag in closeTags) {
      buffer.write(tag);
    }
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
