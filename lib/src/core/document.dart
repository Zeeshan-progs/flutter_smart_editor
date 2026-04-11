import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import '../models/enums.dart';

/// Represents an inline text span with formatting attributes.
///
/// Each [TextFormatSpan] holds a piece of text along with its formatting state
/// (bold, italic, underline, strikethrough, font, color, etc.).
///
/// Named `TextFormatSpan` (not `InlineSpan`) to avoid conflict with Flutter's
/// built-in `InlineSpan` class.
class TextFormatSpan {
  String text;
  bool isBold;
  bool isItalic;
  bool isUnderline;
  bool isStrikethrough;
  String? fontFamily;
  double? fontSize;
  Color? foregroundColor;
  Color? backgroundColor;
  String? linkUrl;

  TextFormatSpan({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrikethrough = false,
    this.fontFamily,
    this.fontSize,
    this.foregroundColor,
    this.backgroundColor,
    this.linkUrl,
  });

  /// Creates a deep copy of this span
  TextFormatSpan copyWith({
    String? text,
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    bool? isStrikethrough,
    String? fontFamily,
    double? fontSize,
    Color? foregroundColor,
    Color? backgroundColor,
    String? linkUrl,
    bool clearFontFamily = false,
    bool clearFontSize = false,
    bool clearForegroundColor = false,
    bool clearBackgroundColor = false,
    bool clearLinkUrl = false,
  }) {
    return TextFormatSpan(
      text: text ?? this.text,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      isStrikethrough: isStrikethrough ?? this.isStrikethrough,
      fontFamily: clearFontFamily ? null : (fontFamily ?? this.fontFamily),
      fontSize: clearFontSize ? null : (fontSize ?? this.fontSize),
      foregroundColor: clearForegroundColor
          ? null
          : (foregroundColor ?? this.foregroundColor),
      backgroundColor: clearBackgroundColor
          ? null
          : (backgroundColor ?? this.backgroundColor),
      linkUrl: clearLinkUrl ? null : (linkUrl ?? this.linkUrl),
    );
  }

  /// Returns true if this span has the same formatting as [other]
  bool hasSameFormat(TextFormatSpan other) {
    return isBold == other.isBold &&
        isItalic == other.isItalic &&
        isUnderline == other.isUnderline &&
        isStrikethrough == other.isStrikethrough &&
        fontFamily == other.fontFamily &&
        fontSize == other.fontSize &&
        foregroundColor == other.foregroundColor &&
        backgroundColor == other.backgroundColor &&
        linkUrl == other.linkUrl;
  }

  /// Returns a span with default (no) formatting
  factory TextFormatSpan.plain(String text) => TextFormatSpan(text: text);

  @override
  String toString() =>
      'TextFormatSpan("$text", bold=$isBold, italic=$isItalic, underline=$isUnderline)';
}

/// Abstract base class for block-level nodes in the document.
///
/// Each block represents a distinct visual section like a paragraph,
/// heading, list item, etc. A block contains a list of [TextFormatSpan]s
/// for its text content.
abstract class BlockNode {
  /// Unique identifier for this block, preserved across type changes to maintain focus/state
  final String id;

  /// The inline text spans that make up this block's content
  List<TextFormatSpan> spans;

  /// Text alignment for this block
  SmartTextAlign alignment;

  /// Line height (multiplier) for this block
  double? lineHeight;

  BlockNode({
    String? id,
    List<TextFormatSpan>? spans,
    this.alignment = SmartTextAlign.left,
    this.lineHeight,
  })  : id = id ?? UniqueKey().toString(),
        spans = spans ?? [TextFormatSpan.plain('')];

  /// The HTML tag name for this block (e.g. "p", "h1", "h2")
  String get tag;

  /// The block type enum
  BlockType get blockType;

  /// Returns the total text length of all spans combined
  int get textLength => spans.fold(0, (sum, span) => sum + span.text.length);

  /// Returns the plain text (concatenation of all span texts)
  String get plainText => spans.map((s) => s.text).join();

  /// Creates a deep copy of this block
  BlockNode deepCopy();

  /// Returns the span and local offset for a given global offset in this block.
  /// Returns a record of (spanIndex, localOffset).
  ({int spanIndex, int localOffset}) getSpanAt(int globalOffset) {
    var current = 0;
    for (var i = 0; i < spans.length; i++) {
      final spanLen = spans[i].text.length;
      if (globalOffset <= current + spanLen) {
        return (spanIndex: i, localOffset: globalOffset - current);
      }
      current += spanLen;
    }
    // Clamp to end
    return (
      spanIndex: spans.length - 1,
      localOffset: spans.last.text.length,
    );
  }

  /// Merges adjacent spans that have the same formatting
  void normalizeSpans() {
    if (spans.length <= 1) return;

    final merged = <TextFormatSpan>[spans.first];
    for (var i = 1; i < spans.length; i++) {
      final current = spans[i];
      final last = merged.last;
      if (last.hasSameFormat(current)) {
        last.text += current.text;
      } else {
        merged.add(current);
      }
    }
    // Remove empty spans, but keep at least one
    merged.removeWhere((s) => s.text.isEmpty);
    if (merged.isEmpty) {
      merged.add(TextFormatSpan.plain(''));
    }
    spans = merged;
  }

  @override
  String toString() => '$runtimeType(tag=$tag, spans=$spans)';
}

/// A paragraph block (`<p>`)
class ParagraphNode extends BlockNode {
  ParagraphNode({
    super.id,
    super.spans,
    super.alignment,
    super.lineHeight,
  });

  @override
  String get tag => 'p';

  @override
  BlockType get blockType => BlockType.paragraph;

  @override
  BlockNode deepCopy() => ParagraphNode(
        id: id,
        spans: spans.map((s) => s.copyWith()).toList(),
        alignment: alignment,
        lineHeight: lineHeight,
      );
}

/// A heading block (`<h1>` through `<h6>`)
class HeadingNode extends BlockNode {
  final int level;

  HeadingNode({
    required this.level,
    super.id,
    super.spans,
    super.alignment,
    super.lineHeight,
  }) : assert(level >= 1 && level <= 6);

  @override
  String get tag => 'h$level';

  @override
  BlockType get blockType {
    switch (level) {
      case 1:
        return BlockType.heading1;
      case 2:
        return BlockType.heading2;
      case 3:
        return BlockType.heading3;
      case 4:
        return BlockType.heading4;
      case 5:
        return BlockType.heading5;
      case 6:
        return BlockType.heading6;
      default:
        return BlockType.heading1;
    }
  }

  @override
  BlockNode deepCopy() => HeadingNode(
        level: level,
        id: id,
        spans: spans.map((s) => s.copyWith()).toList(),
        alignment: alignment,
        lineHeight: lineHeight,
      );
}

/// A list item block (`<li>`) inside an ordered or unordered list.
class ListItemNode extends BlockNode {
  /// Whether this is a bullet (unordered) or ordered list item
  final SmartListType listType;

  /// Nesting depth (0 = top level, 1 = one level in, etc.)
  final int depth;

  /// Custom bullet shape for unordered lists.
  /// If null, the per-depth default shape is used.
  final SmartBulletStyle? bulletStyle;

  ListItemNode({
    required this.listType,
    this.depth = 0,
    this.bulletStyle,
    super.id,
    super.spans,
    super.alignment,
    super.lineHeight,
  });

  @override
  String get tag => 'li';

  @override
  BlockType get blockType =>
      listType == SmartListType.bullet ? BlockType.bulletList : BlockType.orderedList;

  @override
  BlockNode deepCopy() => ListItemNode(
        listType: listType,
        depth: depth,
        bulletStyle: bulletStyle,
        id: id,
        spans: spans.map((s) => s.copyWith()).toList(),
        alignment: alignment,
        lineHeight: lineHeight,
      );

  ListItemNode copyWithDepth(int newDepth) => ListItemNode(
        listType: listType,
        depth: newDepth,
        bulletStyle: bulletStyle,
        id: id,
        spans: spans.map((s) => s.copyWith()).toList(),
        alignment: alignment,
        lineHeight: lineHeight,
      );

  ListItemNode copyWithBulletStyle(SmartBulletStyle? style) => ListItemNode(
        listType: listType,
        depth: depth,
        bulletStyle: style,
        id: id,
        spans: spans.map((s) => s.copyWith()).toList(),
        alignment: alignment,
        lineHeight: lineHeight,
      );
}

/// A horizontal rule block (`<hr>`).
class HorizontalRuleNode extends BlockNode {
  HorizontalRuleNode({super.id})
      : super(spans: [TextFormatSpan.plain('')]);

  @override
  String get tag => 'hr';

  @override
  BlockType get blockType => BlockType.horizontalRule;

  @override
  BlockNode deepCopy() => HorizontalRuleNode(id: id);
}

/// The root document model.
///
/// Contains an ordered list of [BlockNode]s that represent the full content
/// of the editor. This model is the single source of truth and is used by
/// both the rendering layer and the serialization layer.
class Document {
  List<BlockNode> blocks;

  Document({List<BlockNode>? blocks}) : blocks = blocks ?? [ParagraphNode()];

  /// Creates a deep copy of the entire document
  Document deepCopy() {
    return Document(
      blocks: blocks.map((b) => b.deepCopy()).toList(),
    );
  }

  /// Returns the total text length across all blocks
  int get totalLength => blocks.fold(0, (sum, b) => sum + b.textLength);

  /// Returns all plain text with newlines between blocks
  String get plainText => blocks.map((b) => b.plainText).join('\n');

  /// Normalizes all blocks (merges adjacent spans with same formatting)
  void normalize() {
    for (final block in blocks) {
      block.normalizeSpans();
    }
  }

  @override
  String toString() => 'Document(blocks=${blocks.length})';
}
