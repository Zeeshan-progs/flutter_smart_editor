import 'package:flutter/material.dart';
import 'package:flutter_smart_editor/src/core/document/document.dart';
import '../../infra/html_parser.dart';
import 'block_document_controller.dart';

/// Controller handling text insertion, deletion, span manipulation, and HTML pasting.
class TextDocumentController extends BlockDocumentController {
  TextDocumentController({
    super.document,
    super.undoRedoManager,
  });

  // ─── Text Operations ──────────────────────────────────────────

  /// Inserts text into a block at the given offset.
  /// If formatting parameters are provided, it creates a new span.
  /// Otherwise, it inherits formatting from the existing span at that position.
  void insertText(
    int blockIndex,
    int offset,
    String text, {
    bool isBold = false,
    bool isItalic = false,
    bool isUnderline = false,
    bool isStrikethrough = false,
    String? fontFamily,
    double? fontSize,
    Color? foregroundColor,
    Color? backgroundColor,
    bool usePendingFormat = false,
  }) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    saveState();

    final block = document.blocks[blockIndex];

    if (usePendingFormat) {
      // Create a new span with the requested formatting
      final newSpan = TextFormatSpan(
        text: text,
        isBold: isBold,
        isItalic: isItalic,
        isUnderline: isUnderline,
        isStrikethrough: isStrikethrough,
        fontFamily: fontFamily,
        fontSize: fontSize,
        foregroundColor: foregroundColor,
        backgroundColor: backgroundColor,
      );

      splitSpanAt(block, offset);

      var currentOffset = 0;
      var insertIndex = 0;
      for (var i = 0; i < block.spans.length; i++) {
        if (currentOffset >= offset) {
          insertIndex = i;
          break;
        }
        currentOffset += block.spans[i].text.length;
        insertIndex = i + 1;
      }
      block.spans.insert(insertIndex, newSpan);
    } else {
      // Inherit formatting
      final loc = block.getSpanAt(offset);
      final span = block.spans[loc.spanIndex];
      span.text = span.text.substring(0, loc.localOffset) +
          text +
          span.text.substring(loc.localOffset);
    }

    notifyChanged();
  }

  /// Deletes text from a block at the given range [start, start + length).
  void deleteText(int blockIndex, int start, int length) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    if (length <= 0) return;
    saveState();

    final block = document.blocks[blockIndex];
    deleteFromSpans(block, start, length);

    notifyChanged();
  }

  /// Inserts a parsed Document (e.g. from pasted HTML) at the given location.
  void insertParsedDocument(int blockIndex, int offset, Document parsedDoc) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    if (parsedDoc.blocks.isEmpty) return;

    saveState();

    final block = document.blocks[blockIndex];

    if (parsedDoc.blocks.length == 1 &&
        parsedDoc.blocks.first is ParagraphNode) {
      // Inline paste
      List<TextFormatSpan> newSpans = parsedDoc.blocks.first.spans.toList();

      // Split the block spans at offset manually
      final leftSpans = <TextFormatSpan>[];
      final rightSpans = <TextFormatSpan>[];
      var currentOffset = 0;

      for (final span in block.spans) {
        final spanEnd = currentOffset + span.text.length;
        if (spanEnd <= offset) {
          leftSpans.add(span.copyWith());
        } else if (currentOffset >= offset) {
          rightSpans.add(span.copyWith());
        } else {
          final splitPoint = offset - currentOffset;
          leftSpans
              .add(span.copyWith(text: span.text.substring(0, splitPoint)));
          rightSpans.add(span.copyWith(text: span.text.substring(splitPoint)));
        }
        currentOffset = spanEnd;
      }

      block.spans = [...leftSpans, ...newSpans, ...rightSpans];

      // Clean up empty spans
      block.spans.removeWhere((s) => s.text.isEmpty);
      if (block.spans.isEmpty) block.spans.add(TextFormatSpan.plain(''));

      notifyChanged();
      return;
    }

    // Complex paste: multiple blocks
    splitBlock(blockIndex, offset);

    final leftBlock = document.blocks[blockIndex];
    final rightBlock = document.blocks[blockIndex + 1];

    final pastedBlocks = parsedDoc.blocks.toList();

    if (pastedBlocks.first is ParagraphNode && leftBlock is ParagraphNode) {
      final firstPasted = pastedBlocks.removeAt(0);
      leftBlock.spans.addAll(firstPasted.spans);
      leftBlock.spans.removeWhere((s) => s.text.isEmpty);
      if (leftBlock.spans.isEmpty) {
        leftBlock.spans.add(TextFormatSpan.plain(''));
      }
    }

    if (pastedBlocks.isNotEmpty &&
        pastedBlocks.last is ParagraphNode &&
        rightBlock is ParagraphNode) {
      final lastPasted = pastedBlocks.removeLast();
      rightBlock.spans.insertAll(0, lastPasted.spans);
      rightBlock.spans.removeWhere((s) => s.text.isEmpty);
      if (rightBlock.spans.isEmpty) {
        rightBlock.spans.add(TextFormatSpan.plain(''));
      }
    }

    if (pastedBlocks.isNotEmpty) {
      document.blocks.insertAll(blockIndex + 1, pastedBlocks);
    }

    notifyChanged();
  }

  /// Smart text update that preserves formatting.
  void updateBlockText(
    int blockIndex,
    String oldText,
    String newText, {
    TextFormatSpan? pendingFormat,
  }) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    if (oldText == newText) return;

    // Find the common prefix and suffix
    int commonPrefix = 0;
    final minLen =
        oldText.length < newText.length ? oldText.length : newText.length;

    while (commonPrefix < minLen &&
        oldText[commonPrefix] == newText[commonPrefix]) {
      commonPrefix++;
    }

    int commonSuffix = 0;
    while (commonSuffix < minLen - commonPrefix &&
        oldText[oldText.length - 1 - commonSuffix] ==
            newText[newText.length - 1 - commonSuffix]) {
      commonSuffix++;
    }

    final deleteStart = commonPrefix;
    final deleteLength = oldText.length - commonPrefix - commonSuffix;
    final insertedText = newText.substring(
      commonPrefix,
      newText.length - commonSuffix,
    );

    final block = document.blocks[blockIndex];
    saveState();

    // Step 1: Delete
    if (deleteLength > 0) {
      deleteFromSpans(block, deleteStart, deleteLength);
    }

    // Step 2: Insert
    if (insertedText.isNotEmpty) {
      if (pendingFormat != null) {
        insertFormattedIntoSpans(
            block, deleteStart, insertedText, pendingFormat);
      } else {
        insertIntoSpans(block, deleteStart, insertedText);
      }
    }

    notifyChanged();
  }

  /// Parses HTML and inserts it at the given location.
  void pasteHtml(int blockIndex, int offset, String html,
      {required SmartHtmlParser parser}) {
    if (html.isEmpty) return;
    final parsedDoc = parser.parse(html);
    insertParsedDocument(blockIndex, offset, parsedDoc);
  }

  // ─── Span Manipulation Helpers ─────────────────────────────────

  @protected
  void deleteFromSpans(BlockNode block, int offset, int length) {
    if (length <= 0) return;
    final delStart = offset;
    final delEnd = offset + length;
    var current = 0;

    for (var i = 0; i < block.spans.length; i++) {
      final span = block.spans[i];
      final origLen = span.text.length;
      final spanEnd = current + origLen;

      if (spanEnd > delStart && current < delEnd) {
        final localStart = (delStart - current).clamp(0, origLen);
        final localEnd = (delEnd - current).clamp(0, origLen);
        if (localEnd > localStart) {
          span.text = span.text.substring(0, localStart) +
              span.text.substring(localEnd);
          if (span.text.isEmpty) {
            block.spans.removeAt(i);
            i--;
          }
        }
      }
      current = spanEnd;
    }

    if (block.spans.isEmpty) {
      block.spans.add(TextFormatSpan.plain(''));
    }
  }

  @protected
  void insertIntoSpans(BlockNode block, int offset, String text) {
    if (block.spans.isEmpty) {
      block.spans.add(TextFormatSpan(text: text));
      return;
    }

    final loc = block.getSpanAt(offset);
    final span = block.spans[loc.spanIndex];

    span.text = span.text.substring(0, loc.localOffset) +
        text +
        span.text.substring(loc.localOffset);
  }

  @protected
  void insertFormattedIntoSpans(
    BlockNode block,
    int offset,
    String text,
    TextFormatSpan format,
  ) {
    splitSpanAt(block, offset);

    var currentOffset = 0;
    var insertIndex = 0;
    for (var i = 0; i < block.spans.length; i++) {
      if (currentOffset >= offset) {
        insertIndex = i;
        break;
      }
      currentOffset += block.spans[i].text.length;
      insertIndex = i + 1;
    }

    final newSpan = format.copyWith(text: text);
    block.spans.insert(insertIndex, newSpan);
  }

  @protected
  void splitSpanAt(BlockNode block, int globalOffset) {
    if (globalOffset <= 0 || globalOffset >= block.textLength) return;

    final loc = block.getSpanAt(globalOffset);
    final span = block.spans[loc.spanIndex];

    if (loc.localOffset == 0 || loc.localOffset == span.text.length) return;

    final left = span.copyWith(text: span.text.substring(0, loc.localOffset));
    final right = span.copyWith(text: span.text.substring(loc.localOffset));

    block.spans[loc.spanIndex] = left;
    block.spans.insert(loc.spanIndex + 1, right);
  }
}
