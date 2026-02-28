import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../core/document.dart';
import '../models/enums.dart';

/// Parses an HTML string into a [Document] tree.
///
/// Supports the following HTML elements:
/// - Block: `<p>`, `<h1>`–`<h6>`, `<div>`, `<br>`
/// - Inline: `<b>`, `<strong>`, `<i>`, `<em>`, `<u>`, `<ins>`,
///   `<s>`, `<strike>`, `<del>`, `<sup>`, `<sub>`, `<span>`, `<a>`
///
/// Unsupported tags are treated as plain text containers.
class SmartHtmlParser {
  /// Parses an HTML string into a [Document].
  ///
  /// If the input is empty or null, returns a document with a single
  /// empty paragraph.
  Document parse(String? html) {
    if (html == null || html.trim().isEmpty) {
      return Document();
    }

    // Wrap in a body if not already wrapped
    final fragment = html_parser.parseFragment(html);
    final blocks = <BlockNode>[];

    for (final node in fragment.nodes) {
      _processNode(node, blocks);
    }

    if (blocks.isEmpty) {
      blocks.add(ParagraphNode());
    }

    // Normalize all blocks
    for (final block in blocks) {
      block.normalizeSpans();
    }

    return Document(blocks: blocks);
  }

  /// Process a single DOM node, adding blocks to the list
  void _processNode(dom.Node node, List<BlockNode> blocks) {
    if (node is dom.Text) {
      final text = node.text;
      if (text.trim().isNotEmpty) {
        // Bare text outside of any block — wrap in a paragraph
        final spans = [TextFormatSpan.plain(text)];
        blocks.add(ParagraphNode(spans: spans));
      }
      return;
    }

    if (node is! dom.Element) return;

    final element = node;
    final tag = element.localName?.toLowerCase() ?? '';

    // Handle block-level elements
    if (_isBlockTag(tag)) {
      final block = _createBlock(tag, element);
      blocks.add(block);
    } else if (tag == 'br') {
      // A standalone <br> creates an empty paragraph
      blocks.add(ParagraphNode());
    } else {
      // Inline element at top level — wrap in paragraph
      final spans = <TextFormatSpan>[];
      _extractInlineSpans(element, spans, _InlineFormat());
      if (spans.isNotEmpty) {
        blocks.add(ParagraphNode(spans: spans));
      }
    }
  }

  /// Returns true if the tag is a block-level element
  bool _isBlockTag(String tag) {
    return const {
      'p',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'div',
    }.contains(tag);
  }

  /// Creates a [BlockNode] from a block-level DOM element
  BlockNode _createBlock(String tag, dom.Element element) {
    final spans = <TextFormatSpan>[];
    _extractInlineSpans(element, spans, _InlineFormat());

    if (spans.isEmpty) {
      spans.add(TextFormatSpan.plain(''));
    }

    final alignment = _parseAlignment(element);

    if (tag == 'p' || tag == 'div') {
      return ParagraphNode(spans: spans, alignment: alignment);
    }

    // Headings
    final headingLevel = int.tryParse(tag.substring(1));
    if (headingLevel != null && headingLevel >= 1 && headingLevel <= 6) {
      return HeadingNode(
        level: headingLevel,
        spans: spans,
        alignment: alignment,
      );
    }

    return ParagraphNode(spans: spans, alignment: alignment);
  }

  /// Parses the text-align style from an element
  SmartTextAlign _parseAlignment(dom.Element element) {
    final style = element.attributes['style'] ?? '';
    if (style.contains('text-align')) {
      if (style.contains('center')) return SmartTextAlign.center;
      if (style.contains('right')) return SmartTextAlign.right;
      if (style.contains('justify')) return SmartTextAlign.justify;
    }
    return SmartTextAlign.left;
  }

  /// Recursively extracts inline spans from an element's children
  void _extractInlineSpans(
    dom.Node node,
    List<TextFormatSpan> spans,
    _InlineFormat parentFormat,
  ) {
    if (node is dom.Text) {
      final text = node.text;
      if (text.isNotEmpty) {
        spans.add(TextFormatSpan(
          text: text,
          isBold: parentFormat.isBold,
          isItalic: parentFormat.isItalic,
          isUnderline: parentFormat.isUnderline,
          isStrikethrough: parentFormat.isStrikethrough,
          isSuperscript: parentFormat.isSuperscript,
          isSubscript: parentFormat.isSubscript,
          linkUrl: parentFormat.linkUrl,
        ));
      }
      return;
    }

    if (node is! dom.Element) return;

    final element = node;
    final tag = element.localName?.toLowerCase() ?? '';
    final childFormat = parentFormat.copyWith();

    // Apply formatting based on tag
    switch (tag) {
      case 'b':
      case 'strong':
        childFormat.isBold = true;
        break;
      case 'i':
      case 'em':
        childFormat.isItalic = true;
        break;
      case 'u':
      case 'ins':
        childFormat.isUnderline = true;
        break;
      case 's':
      case 'strike':
      case 'del':
        childFormat.isStrikethrough = true;
        break;
      case 'sup':
        childFormat.isSuperscript = true;
        break;
      case 'sub':
        childFormat.isSubscript = true;
        break;
      case 'a':
        childFormat.linkUrl = element.attributes['href'];
        break;
      case 'br':
        spans.add(TextFormatSpan.plain('\n'));
        return;
    }

    // Recurse into children
    for (final child in element.nodes) {
      _extractInlineSpans(child, spans, childFormat);
    }
  }
}

/// Tracks the current inline format state during recursive parsing
class _InlineFormat {
  bool isBold;
  bool isItalic;
  bool isUnderline;
  bool isStrikethrough;
  bool isSuperscript;
  bool isSubscript;
  String? linkUrl;

  _InlineFormat({
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrikethrough = false,
    this.isSuperscript = false,
    this.isSubscript = false,
    this.linkUrl,
  });

  _InlineFormat copyWith() => _InlineFormat(
        isBold: isBold,
        isItalic: isItalic,
        isUnderline: isUnderline,
        isStrikethrough: isStrikethrough,
        isSuperscript: isSuperscript,
        isSubscript: isSubscript,
        linkUrl: linkUrl,
      );
}
