import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import '../../models/enums.dart';

// Import node models from their new specialized location
import '../../models/nodes/node_index.dart';

export '../../models/nodes/node_index.dart';

/// Represents an inline text span with formatting attributes.
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

  factory TextFormatSpan.plain(String text) => TextFormatSpan(text: text);

  @override
  String toString() =>
      'TextFormatSpan("$text", bold=$isBold, italic=$isItalic, underline=$isUnderline)';
}

/// Abstract base class for block-level nodes in the document.
abstract class BlockNode {
  final String id;
  List<TextFormatSpan> spans;
  SmartTextAlign alignment;
  double? lineHeight;

  BlockNode({
    String? id,
    List<TextFormatSpan>? spans,
    this.alignment = SmartTextAlign.left,
    this.lineHeight,
  })  : id = id ?? UniqueKey().toString(),
        spans = spans ?? [TextFormatSpan.plain('')];

  String get tag;
  BlockType get blockType;

  int get textLength => spans.fold(0, (sum, span) => sum + span.text.length);
  String get plainText => spans.map((s) => s.text).join();
  BlockNode deepCopy();

  ({int spanIndex, int localOffset}) getSpanAt(int globalOffset) {
    var current = 0;
    for (var i = 0; i < spans.length; i++) {
      final spanLen = spans[i].text.length;
      if (globalOffset <= current + spanLen) {
        return (spanIndex: i, localOffset: globalOffset - current);
      }
      current += spanLen;
    }
    return (
      spanIndex: spans.length - 1,
      localOffset: spans.last.text.length,
    );
  }

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
    merged.removeWhere((s) => s.text.isEmpty);
    if (merged.isEmpty) {
      merged.add(TextFormatSpan.plain(''));
    }
    spans = merged;
  }

  @override
  String toString() => '$runtimeType(tag=$tag, spans=$spans)';
}

/// The root document model.
class Document {
  List<BlockNode> blocks;

  Document({List<BlockNode>? blocks}) : blocks = blocks ?? [ParagraphNode()];

  Document deepCopy() {
    return Document(
      blocks: blocks.map((b) => b.deepCopy()).toList(),
    );
  }

  int get totalLength => blocks.fold(0, (sum, b) => sum + b.textLength);
  String get plainText => blocks.map((b) => b.plainText).join('\n');

  void normalize() {
    for (final block in blocks) {
      block.normalizeSpans();
    }
  }

  @override
  String toString() => 'Document(blocks=${blocks.length})';
}
