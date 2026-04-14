import 'package:flutter/painting.dart';
import '../document/document.dart';
import '../../models/enums.dart';

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
    final blocks = document.blocks;
    int i = 0;

    while (i < blocks.length) {
      final block = blocks[i];

      if (block is HorizontalRuleNode) {
        buffer.write(_serializeHr(block));
        i++;
        continue;
      }

      if (block is ListItemNode) {
        // Collect the entire contiguous list group
        int end = i;
        while (end < blocks.length - 1 && blocks[end + 1] is ListItemNode) { end++; }
        final group = blocks.sublist(i, end + 1).cast<ListItemNode>();
        buffer.write(_serializeListGroup(group));
        i = end + 1;
        continue;
      }

      _serializeBlock(block, buffer);
      i++;
    }
    final html = buffer.toString();
    // Strip any ZWSP characters used by the mobile backspace bridge
    return html.replaceAll('\u200B', '');
  }

  /// Serializes a [HorizontalRuleNode] as `<hr/>`
  String _serializeHr(HorizontalRuleNode block) {
    final custom = onTagSerialize?.call(
        SmartTagType.horizontalRule, 'hr', {}, {}, '');
    return custom ?? '<hr/>';
  }

  /// Serializes a contiguous group of [ListItemNode]s into nested <ul>/<ol> HTML.
  String _serializeListGroup(List<ListItemNode> items) {
    final buffer = StringBuffer();
    // Stack tracks (listType, depth) of open wrappers
    final openStack = <({SmartListType listType, int depth})>[];

    // Helper to get CSS list-style-type for a bullet style
    String? bulletCss(SmartBulletStyle? style) {
      if (style == null) return null;
      switch (style) {
        case SmartBulletStyle.filledCircle: return 'disc';
        case SmartBulletStyle.hollowCircle: return 'circle';
        case SmartBulletStyle.filledSquare: return 'square';
        case SmartBulletStyle.hollowSquare: return "'\u25a1'";
        case SmartBulletStyle.diamond: return "'\u25c6'";
        case SmartBulletStyle.hollowDiamond: return "'\u25c7'";
        case SmartBulletStyle.arrow: return "'\u2192'";
        case SmartBulletStyle.doubleArrow: return "'\u00bb'";
        case SmartBulletStyle.dash: return "'\u2013'";
        case SmartBulletStyle.star: return "'\u2605'";
        case SmartBulletStyle.hollowStar: return "'\u2606'";
        case SmartBulletStyle.checkmark: return "'\u2713'";
        case SmartBulletStyle.triangle: return "'\u25b6'";
      }
    }

    // Compute ordered counters per (depth, contiguous group)
    // counter[depth] resets each time we go up to a shallower or different type
    final counters = <int, int>{};
    final lastDepthType = <int, SmartListType>{};

    for (int idx = 0; idx < items.length; idx++) {
      final item = items[idx];
      final depth = item.depth;
      final currentDepth = openStack.isEmpty ? -1 : openStack.last.depth;

      if (depth > currentDepth) {
        // Open new wrapper(s) for each depth increment
        while (openStack.isEmpty || openStack.last.depth < depth) {
          final newDepth = openStack.isEmpty ? 0 : openStack.last.depth + 1;
          final newType = (newDepth == depth) ? item.listType : item.listType;
          final wrapTag = newType == SmartListType.bullet ? 'ul' : 'ol';
          final styleAttr = (newType == SmartListType.bullet && item.bulletStyle != null)
              ? ' style="list-style-type: ${bulletCss(item.bulletStyle)}"'
              : '';
          final custom = onTagSerialize?.call(
              newType == SmartListType.bullet
                  ? SmartTagType.unorderedList
                  : SmartTagType.orderedList,
              wrapTag, {}, {}, '');
          if (custom == null) buffer.write('<$wrapTag$styleAttr>');
          openStack.add((listType: newType, depth: newDepth));
          counters[newDepth] = 0;
          lastDepthType[newDepth] = newType;
        }
      } else if (depth < currentDepth) {
        // Close wrapper(s) for each depth decrease
        while (openStack.isNotEmpty && openStack.last.depth > depth) {
          final closed = openStack.removeLast();
          final closeTag = closed.listType == SmartListType.bullet ? 'ul' : 'ol';
          buffer.write('</$closeTag>');
        }
        // If type changed at same depth, close old and open new
        if (openStack.isNotEmpty && openStack.last.listType != item.listType) {
          final closed = openStack.removeLast();
          final closeTag = closed.listType == SmartListType.bullet ? 'ul' : 'ol';
          buffer.write('</$closeTag>');
          final wrapTag = item.listType == SmartListType.bullet ? 'ul' : 'ol';
          buffer.write('<$wrapTag>');
          openStack.add((listType: item.listType, depth: depth));
          counters[depth] = 0;
        }
      } else {
        // Same depth — check type changed
        if (openStack.isNotEmpty && openStack.last.listType != item.listType) {
          final closed = openStack.removeLast();
          buffer.write('</${closed.listType == SmartListType.bullet ? 'ul' : 'ol'}>');
          final wrapTag = item.listType == SmartListType.bullet ? 'ul' : 'ol';
          buffer.write('<$wrapTag>');
          openStack.add((listType: item.listType, depth: depth));
          counters[depth] = 0;
        }
      }

      // Compute counter for ordered list
      if (item.listType == SmartListType.ordered) {
        counters[depth] = (counters[depth] ?? 0) + 1;
      }

      // Serialize <li> content
      final contentBuffer = StringBuffer();
      for (final span in item.spans) {
        _serializeSpan(span, contentBuffer);
      }
      final liContent = contentBuffer.toString();
      final custom = onTagSerialize?.call(
          SmartTagType.listItem, 'li', {}, {}, liContent);
      buffer.write(custom ?? '<li>$liContent</li>');
    }

    // Close all remaining open wrappers
    while (openStack.isNotEmpty) {
      final closed = openStack.removeLast();
      final closeTag = closed.listType == SmartListType.bullet ? 'ul' : 'ol';
      buffer.write('</$closeTag>');
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
