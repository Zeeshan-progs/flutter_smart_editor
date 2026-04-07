import 'package:flutter/painting.dart';
import '../core/document.dart';
import '../core/undo_redo_manager.dart';
import '../models/enums.dart';

/// Editing operations on the [Document] model.
///
/// This is the internal engine that performs text insertion, deletion,
/// formatting toggles, block splitting/merging, and block type changes.
/// All operations modify the document in place and push undo states.
class DocumentController {
  Document document;
  final UndoRedoManager undoRedoManager;
  final VoidCallback? onDocumentChanged;

  DocumentController({
    Document? document,
    UndoRedoManager? undoRedoManager,
    this.onDocumentChanged,
  })  : document = document ?? Document(),
        undoRedoManager = undoRedoManager ?? UndoRedoManager();

  /// Saves the current state before making a change
  void _saveState() {
    undoRedoManager.pushState(document);
  }

  /// Notifies listeners that the document changed
  void _notifyChanged() {
    document.normalize();
    onDocumentChanged?.call();
  }

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
    _saveState();

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

      _splitSpanAt(block, offset);

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

    _notifyChanged();
  }

  /// Deletes text from a block at the given range [start, start + length).
  void deleteText(int blockIndex, int start, int length) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    if (length <= 0) return;
    _saveState();

    final block = document.blocks[blockIndex];
    _deleteFromSpans(block, start, length);

    _notifyChanged();
  }

  /// Inserts a parsed Document (e.g. from pasted HTML) at the given location.
  void insertParsedDocument(int blockIndex, int offset, Document parsedDoc) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    if (parsedDoc.blocks.isEmpty) return;

    _saveState();

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

      _notifyChanged();
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

    _notifyChanged();
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
    _saveState();

    // Step 1: Delete
    if (deleteLength > 0) {
      _deleteFromSpans(block, deleteStart, deleteLength);
    }

    // Step 2: Insert
    if (insertedText.isNotEmpty) {
      if (pendingFormat != null) {
        _insertFormattedIntoSpans(
            block, deleteStart, insertedText, pendingFormat);
      } else {
        _insertIntoSpans(block, deleteStart, insertedText);
      }
    }

    _notifyChanged();
  }

  void _deleteFromSpans(BlockNode block, int offset, int length) {
    var remaining = length;
    var deleteStart = offset;

    while (remaining > 0 && block.spans.isNotEmpty) {
      final loc = block.getSpanAt(deleteStart);
      if (loc.spanIndex >= block.spans.length) break;

      final span = block.spans[loc.spanIndex];
      final availableToDelete = span.text.length - loc.localOffset;
      final toDelete =
          remaining < availableToDelete ? remaining : availableToDelete;

      span.text = span.text.substring(0, loc.localOffset) +
          span.text.substring(loc.localOffset + toDelete);

      remaining -= toDelete;

      if (span.text.isEmpty && block.spans.length > 1) {
        block.spans.removeAt(loc.spanIndex);
      }
    }
  }

  void _insertIntoSpans(BlockNode block, int offset, String text) {
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

  void _insertFormattedIntoSpans(
    BlockNode block,
    int offset,
    String text,
    TextFormatSpan format,
  ) {
    _splitSpanAt(block, offset);

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

  // ─── Formatting Operations ────────────────────────────────────

  void toggleFormat(int blockIndex, int start, int end, String format) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    if (start >= end) return;
    _saveState();

    final block = document.blocks[blockIndex];
    _splitSpanAt(block, start);
    _splitSpanAt(block, end);

    bool isActive = false;
    var offset = 0;
    for (final span in block.spans) {
      final spanEnd = offset + span.text.length;
      if (offset >= start && spanEnd <= end && span.text.isNotEmpty) {
        isActive = _getFormat(span, format) == true;
        break;
      }
      offset = spanEnd;
    }

    offset = 0;
    for (final span in block.spans) {
      final spanEnd = offset + span.text.length;
      if (offset >= start && spanEnd <= end) {
        _setFormat(span, format, !isActive);
      }
      offset = spanEnd;
    }

    _notifyChanged();
  }

  void applyFormat(
      int blockIndex, int start, int end, String format, dynamic value) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    if (start >= end) return;
    _saveState();

    final block = document.blocks[blockIndex];
    _splitSpanAt(block, start);
    _splitSpanAt(block, end);

    var offset = 0;
    for (final span in block.spans) {
      final spanEnd = offset + span.text.length;
      if (offset >= start && spanEnd <= end) {
        _setFormat(span, format, value);
      }
      offset = spanEnd;
    }
    _notifyChanged();
  }

  Map<String, dynamic> getFormatAt(int blockIndex, int offset) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) {
      return _defaultFormat();
    }

    final block = document.blocks[blockIndex];
    if (block.spans.isEmpty) return _defaultFormat();

    final loc = block.getSpanAt(offset);
    if (loc.spanIndex >= block.spans.length) return _defaultFormat();

    final span = block.spans[loc.spanIndex];

    return {
      'bold': span.isBold,
      'italic': span.isItalic,
      'underline': span.isUnderline,
      'strikethrough': span.isStrikethrough,
      'fontFamily': span.fontFamily,
      'fontSize': span.fontSize,
      'foregroundColor': span.foregroundColor,
      'backgroundColor': span.backgroundColor,
      'alignment': block.alignment,
    };
  }

  Map<String, dynamic> _defaultFormat() => {
        'bold': false,
        'italic': false,
        'underline': false,
        'strikethrough': false,
        'superscript': false,
        'subscript': false,
        'fontFamily': null,
        'fontSize': null,
        'foregroundColor': null,
        'backgroundColor': null,
        'alignment': SmartTextAlign.left,
      };

  dynamic _getFormat(TextFormatSpan span, String format) {
    switch (format) {
      case 'bold':
        return span.isBold;
      case 'italic':
        return span.isItalic;
      case 'underline':
        return span.isUnderline;
      case 'strikethrough':
        return span.isStrikethrough;
      case 'fontFamily':
        return span.fontFamily;
      case 'fontSize':
        return span.fontSize;
      case 'foregroundColor':
        return span.foregroundColor;
      case 'backgroundColor':
        return span.backgroundColor;
      default:
        return null;
    }
  }

  void _setFormat(TextFormatSpan span, String format, dynamic value) {
    switch (format) {
      case 'bold':
        span.isBold = value as bool;
        break;
      case 'italic':
        span.isItalic = value as bool;
        break;
      case 'underline':
        span.isUnderline = value as bool;
        break;
      case 'strikethrough':
        span.isStrikethrough = value as bool;
        break;
      case 'fontFamily':
        span.fontFamily = value as String?;
        break;
      case 'fontSize':
        span.fontSize = value as double?;
        break;
      case 'foregroundColor':
        span.foregroundColor = value;
        break;
      case 'backgroundColor':
        span.backgroundColor = value;
        break;
    }
  }

  void _splitSpanAt(BlockNode block, int globalOffset) {
    if (globalOffset <= 0 || globalOffset >= block.textLength) return;

    final loc = block.getSpanAt(globalOffset);
    final span = block.spans[loc.spanIndex];

    if (loc.localOffset == 0 || loc.localOffset == span.text.length) return;

    final left = span.copyWith(text: span.text.substring(0, loc.localOffset));
    final right = span.copyWith(text: span.text.substring(loc.localOffset));

    block.spans[loc.spanIndex] = left;
    block.spans.insert(loc.spanIndex + 1, right);
  }

  // ─── Block Operations ─────────────────────────────────────────

  int splitBlock(int blockIndex, int offset, {TextFormatSpan? pendingFormat}) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) {
      return blockIndex;
    }
    _saveState();

    final block = document.blocks[blockIndex];
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
        leftSpans.add(span.copyWith(text: span.text.substring(0, splitPoint)));
        rightSpans.add(span.copyWith(text: span.text.substring(splitPoint)));
      }
      currentOffset = spanEnd;
    }

    if (leftSpans.isEmpty) leftSpans.add(TextFormatSpan.plain(''));
    if (rightSpans.isEmpty) {
      if (pendingFormat != null) {
        rightSpans.add(pendingFormat.copyWith(text: ''));
      } else if (leftSpans.isNotEmpty) {
        rightSpans.add(leftSpans.last.copyWith(text: ''));
      } else {
        rightSpans.add(TextFormatSpan.plain(''));
      }
    }

    block.spans = leftSpans;
    final newBlock = ParagraphNode(
      spans: rightSpans,
      alignment: block.alignment,
    );
    document.blocks.insert(blockIndex + 1, newBlock);

    _notifyChanged();
    return blockIndex + 1;
  }

  int mergeWithPrevious(int blockIndex) {
    if (blockIndex <= 0 || blockIndex >= document.blocks.length) return 0;
    _saveState();

    final previous = document.blocks[blockIndex - 1];
    final current = document.blocks[blockIndex];
    final cursorOffset = previous.textLength;

    previous.spans.addAll(current.spans);
    previous.normalizeSpans();
    document.blocks.removeAt(blockIndex);

    _notifyChanged();
    return cursorOffset;
  }

  void changeBlockType(int blockIndex, BlockType newType) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    _saveState();

    final oldBlock = document.blocks[blockIndex];
    final spans = oldBlock.spans;
    final alignment = oldBlock.alignment;
    final id = oldBlock.id;

    BlockNode newBlock;
    switch (newType) {
      case BlockType.paragraph:
        newBlock = ParagraphNode(id: id, spans: spans, alignment: alignment);
        break;
      case BlockType.heading1:
        newBlock =
            HeadingNode(id: id, level: 1, spans: spans, alignment: alignment);
        break;
      case BlockType.heading2:
        newBlock =
            HeadingNode(id: id, level: 2, spans: spans, alignment: alignment);
        break;
      case BlockType.heading3:
        newBlock =
            HeadingNode(id: id, level: 3, spans: spans, alignment: alignment);
        break;
      case BlockType.heading4:
        newBlock =
            HeadingNode(id: id, level: 4, spans: spans, alignment: alignment);
        break;
      case BlockType.heading5:
        newBlock =
            HeadingNode(id: id, level: 5, spans: spans, alignment: alignment);
        break;
      case BlockType.heading6:
        newBlock =
            HeadingNode(id: id, level: 6, spans: spans, alignment: alignment);
        break;
    }

    document.blocks[blockIndex] = newBlock;
    _notifyChanged();
  }

  void setLineHeight(int blockIndex, double? lineHeight) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    _saveState();
    document.blocks[blockIndex].lineHeight = lineHeight;
    _notifyChanged();
  }

  void setAlignment(int blockIndex, SmartTextAlign alignment) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    _saveState();
    document.blocks[blockIndex].alignment = alignment;
    _notifyChanged();
  }

  void clearFormat(int blockIndex, int offset, int length) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    if (length <= 0) return;
    _saveState();
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
    _notifyChanged();
  }

  void setDocument(Document newDoc) {
    _saveState();
    document = newDoc;
    _notifyChanged();
  }

  void clear() {
    _saveState();
    document = Document();
    _notifyChanged();
  }

  void undo() {
    if (undoRedoManager.canUndo) {
      final doc = undoRedoManager.undo(document);
      if (doc != null) {
        document = doc;
        onDocumentChanged?.call();
      }
    }
  }

  void redo() {
    if (undoRedoManager.canRedo) {
      final doc = undoRedoManager.redo(document);
      if (doc != null) {
        document = doc;
        onDocumentChanged?.call();
      }
    }
  }
}
