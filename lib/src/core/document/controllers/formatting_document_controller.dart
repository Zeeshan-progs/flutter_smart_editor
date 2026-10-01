import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:flutter_smart_editor/src/core/document/document.dart';
import '../../../models/enums.dart';
import 'text_document_controller.dart';

/// Controller handling inline styling, formatting toggles, hyperlinks, and block alignment.
class FormattingDocumentController extends TextDocumentController {
  FormattingDocumentController({
    super.document,
    super.undoRedoManager,
  });

  // ─── Formatting Operations ────────────────────────────────────

  void toggleFormat(
      int blockIndex, int start, int end, SmartButtonType format) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    if (start >= end) return;
    saveState();

    final block = document.blocks[blockIndex];
    splitSpanAt(block, start);
    splitSpanAt(block, end);

    bool isActive = false;
    var offset = 0;
    for (final span in block.spans) {
      final spanEnd = offset + span.text.length;
      if (offset >= start && spanEnd <= end && span.text.isNotEmpty) {
        isActive = getFormat(span, format) == true;
        break;
      }
      offset = spanEnd;
    }

    offset = 0;
    for (final span in block.spans) {
      final spanEnd = offset + span.text.length;
      if (offset >= start && spanEnd <= end) {
        setFormat(span, format, !isActive);
      }
      offset = spanEnd;
    }

    notifyChanged();
  }

  void applyFormat(int blockIndex, int start, int end, SmartButtonType format,
      dynamic value) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    if (start >= end) return;
    saveState();

    final block = document.blocks[blockIndex];
    splitSpanAt(block, start);
    splitSpanAt(block, end);

    var offset = 0;
    for (final span in block.spans) {
      final spanEnd = offset + span.text.length;
      if (offset >= start && spanEnd <= end) {
        setFormat(span, format, value);
      }
      offset = spanEnd;
    }
    notifyChanged();
  }

  /// Clears formatting from a text range within a block.
  void clearFormat(int blockIndex, int offset, int length) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    if (length <= 0) return;
    saveState();
    final block = document.blocks[blockIndex];
    final oldSpans = block.spans;
    final newSpans = <TextFormatSpan>[];

    var currentOffset = 0;
    for (final span in oldSpans) {
      final spanEnd = currentOffset + span.text.length;
      if (spanEnd <= offset || currentOffset >= offset + length) {
        newSpans.add(span);
      } else {
        if (currentOffset < offset) {
          newSpans.add(span.copyWith(
              text: span.text.substring(0, offset - currentOffset)));
        }
        final startInside = currentOffset < offset ? offset - currentOffset : 0;
        final endInside = spanEnd > offset + length
            ? span.text.length - (spanEnd - (offset + length))
            : span.text.length;
        if (endInside > startInside) {
          newSpans.add(TextFormatSpan.plain(
              span.text.substring(startInside, endInside)));
        }
        if (spanEnd > offset + length) {
          final rightStart = span.text.length - (spanEnd - (offset + length));
          newSpans.add(span.copyWith(text: span.text.substring(rightStart)));
        }
      }
      currentOffset = spanEnd;
    }
    block.spans = newSpans;
    notifyChanged();
  }

  /// Applies or removes a hyperlink over a range of text in [blockIndex].
  void applyLink(int blockIndex, int start, int end, String? url) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    if (start >= end) return;
    saveState();

    final block = document.blocks[blockIndex];
    splitSpanAt(block, start);
    splitSpanAt(block, end);

    var offset = 0;
    for (final span in block.spans) {
      final spanEnd = offset + span.text.length;
      if (offset >= start && spanEnd <= end) {
        span.linkUrl = url;
      }
      offset = spanEnd;
    }
    notifyChanged();
  }

  /// Inserts a new hyperlinked text run at [offset] in [blockIndex].
  void insertLink(int blockIndex, int offset, String text, String url) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    if (text.isEmpty) return;
    saveState();

    final block = document.blocks[blockIndex];
    final linkSpan = TextFormatSpan(text: text, linkUrl: url);
    insertFormattedIntoSpans(block, offset, text, linkSpan);
    notifyChanged();
  }

  /// Atomically applies or replaces a hyperlink for a block, appending an unlinked space if needed.
  /// Returns the target cursor offset (immediately after the inserted space).
  int setLink({
    required int blockIndex,
    required int start,
    required int end,
    required String text,
    required String url,
  }) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return 0;
    if (text.isEmpty) return 0;

    saveState();
    final block = document.blocks[blockIndex];
    final currentBlockText = block.plainText;
    final safeStart = start.clamp(0, currentBlockText.length);
    final safeEnd = end.clamp(safeStart, currentBlockText.length);

    int linkEnd;
    final selectedText = (safeStart < safeEnd)
        ? currentBlockText.substring(safeStart, safeEnd)
        : '';

    if (safeStart < safeEnd && text == selectedText) {
      splitSpanAt(block, safeStart);
      splitSpanAt(block, safeEnd);

      var offset = 0;
      for (final span in block.spans) {
        final spanEnd = offset + span.text.length;
        if (offset >= safeStart && spanEnd <= safeEnd) {
          span.linkUrl = url;
        }
        offset = spanEnd;
      }
      linkEnd = safeEnd;
    } else {
      if (safeEnd > safeStart) {
        deleteFromSpans(block, safeStart, safeEnd - safeStart);
      }
      final linkSpan = TextFormatSpan(text: text, linkUrl: url);
      insertFormattedIntoSpans(block, safeStart, text, linkSpan);
      linkEnd = safeStart + text.length;
    }

    final textAfterLink = block.plainText;
    final hasSpaceAfter =
        linkEnd < textAfterLink.length && textAfterLink[linkEnd] == ' ';

    if (!hasSpaceAfter) {
      insertFormattedIntoSpans(
        block,
        linkEnd,
        ' ',
        TextFormatSpan.plain(' '),
      );
    }

    block.normalizeSpans();
    notifyChanged();

    return linkEnd + 1;
  }

  /// Returns the link text and url at [offset] in [blockIndex], if any.
  Map<String, String?> getLinkInfoAt(int blockIndex, int offset) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) {
      return {'text': null, 'url': null};
    }
    final block = document.blocks[blockIndex];
    if (block.spans.isEmpty) return {'text': null, 'url': null};

    final loc = block.getSpanAt(offset);
    if (loc.spanIndex >= block.spans.length) return {'text': null, 'url': null};

    final span = block.spans[loc.spanIndex];
    if (span.linkUrl != null && span.linkUrl!.isNotEmpty) {
      return {'text': span.text, 'url': span.linkUrl};
    }
    return {'text': null, 'url': null};
  }

  /// Returns the link text and url at [offset] in [blockIndex], if any.
  Map<String, String?> getLinkAt(int blockIndex, int offset) =>
      getLinkInfoAt(blockIndex, offset);

  Map<SmartButtonType, dynamic> getFormatAt(int blockIndex, int offset) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) {
      return defaultFormat();
    }

    final block = document.blocks[blockIndex];
    if (block.spans.isEmpty) return defaultFormat();

    final loc = block.getSpanAt(offset);
    if (loc.spanIndex >= block.spans.length) return defaultFormat();

    final span = block.spans[loc.spanIndex];

    return {
      SmartButtonType.bold: span.isBold,
      SmartButtonType.italic: span.isItalic,
      SmartButtonType.underline: span.isUnderline,
      SmartButtonType.strikethrough: span.isStrikethrough,
      SmartButtonType.fontName: span.fontFamily,
      SmartButtonType.fontSize: span.fontSize,
      SmartButtonType.foregroundColor: span.foregroundColor,
      SmartButtonType.highlightColor: span.backgroundColor,
      SmartButtonType.alignLeft: block.alignment == SmartTextAlign.left,
      SmartButtonType.alignCenter: block.alignment == SmartTextAlign.center,
      SmartButtonType.alignRight: block.alignment == SmartTextAlign.right,
      SmartButtonType.alignJustify: block.alignment == SmartTextAlign.justify,
      SmartButtonType.blockType: block.blockType,
      SmartButtonType.insertLink:
          span.linkUrl != null && span.linkUrl!.isNotEmpty,
    };
  }

  void setAlignment(int blockIndex, SmartTextAlign alignment) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    saveState();
    document.blocks[blockIndex].alignment = alignment;
    notifyChanged();
  }

  void setLineHeight(int blockIndex, double? lineHeight) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    saveState();
    document.blocks[blockIndex].lineHeight = lineHeight;
    notifyChanged();
  }

  // ─── Format Helpers ───────────────────────────────────────────

  @protected
  Map<SmartButtonType, dynamic> defaultFormat() => {
        SmartButtonType.bold: false,
        SmartButtonType.italic: false,
        SmartButtonType.underline: false,
        SmartButtonType.strikethrough: false,
        SmartButtonType.fontName: null,
        SmartButtonType.fontSize: null,
        SmartButtonType.foregroundColor: null,
        SmartButtonType.highlightColor: null,
        SmartButtonType.alignLeft: true,
        SmartButtonType.insertLink: false,
      };

  @protected
  dynamic getFormat(TextFormatSpan span, SmartButtonType format) {
    switch (format) {
      case SmartButtonType.bold:
        return span.isBold;
      case SmartButtonType.italic:
        return span.isItalic;
      case SmartButtonType.underline:
        return span.isUnderline;
      case SmartButtonType.strikethrough:
        return span.isStrikethrough;
      case SmartButtonType.fontName:
        return span.fontFamily;
      case SmartButtonType.fontSize:
        return span.fontSize;
      case SmartButtonType.foregroundColor:
        return span.foregroundColor;
      case SmartButtonType.highlightColor:
        return span.backgroundColor;
      case SmartButtonType.insertLink:
        return span.linkUrl;
      default:
        return null;
    }
  }

  @protected
  void setFormat(TextFormatSpan span, SmartButtonType format, dynamic value) {
    switch (format) {
      case SmartButtonType.bold:
        span.isBold = value as bool;
        break;
      case SmartButtonType.italic:
        span.isItalic = value as bool;
        break;
      case SmartButtonType.underline:
        span.isUnderline = value as bool;
        break;
      case SmartButtonType.strikethrough:
        span.isStrikethrough = value as bool;
        break;
      case SmartButtonType.fontName:
        span.fontFamily = value as String?;
        break;
      case SmartButtonType.fontSize:
        span.fontSize = value as double?;
        break;
      case SmartButtonType.foregroundColor:
        span.foregroundColor = value;
        break;
      case SmartButtonType.highlightColor:
        span.backgroundColor = value;
        break;
      case SmartButtonType.insertLink:
        span.linkUrl = value as String?;
        break;
      case SmartButtonType.clearFormatting:
        span.isBold = false;
        span.isItalic = false;
        span.isUnderline = false;
        span.isStrikethrough = false;
        span.fontFamily = null;
        span.fontSize = null;
        span.foregroundColor = null;
        span.backgroundColor = null;
        span.linkUrl = null;
        break;
      default:
        break;
    }
  }
}
