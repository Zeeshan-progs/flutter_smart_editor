import 'package:flutter/foundation.dart';
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

  /// Inserts plain text into a block at the given offset, inheriting
  /// the existing span's formatting at that position.
  void insertText(int blockIndex, int offset, String text) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    _saveState();

    final block = document.blocks[blockIndex];
    final loc = block.getSpanAt(offset);
    final span = block.spans[loc.spanIndex];

    span.text = span.text.substring(0, loc.localOffset) +
        text +
        span.text.substring(loc.localOffset);

    _notifyChanged();
  }

  /// Inserts text with specific formatting at the given offset.
  /// Used for "pending format" — when user toggles Bold at cursor,
  /// then types, the new text should be bold.
  void insertFormattedText(
    int blockIndex,
    int offset,
    String text, {
    bool isBold = false,
    bool isItalic = false,
    bool isUnderline = false,
    bool isStrikethrough = false,
  }) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    _saveState();

    final block = document.blocks[blockIndex];

    // Create a new span with the requested formatting
    final newSpan = TextFormatSpan(
      text: text,
      isBold: isBold,
      isItalic: isItalic,
      isUnderline: isUnderline,
      isStrikethrough: isStrikethrough,
    );

    // Split the span at the offset and insert the new formatted span
    _splitSpanAt(block, offset);

    // Find which span index to insert at
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

    _notifyChanged();
  }

  /// Deletes text from a block at the given range [start, start + length).
  void deleteText(int blockIndex, int start, int length) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    if (length <= 0) return;
    _saveState();

    final block = document.blocks[blockIndex];
    var remaining = length;
    var deleteStart = start;

    while (remaining > 0 && block.spans.isNotEmpty) {
      final loc = block.getSpanAt(deleteStart);
      final span = block.spans[loc.spanIndex];
      final availableToDelete = span.text.length - loc.localOffset;
      final toDelete =
          remaining < availableToDelete ? remaining : availableToDelete;

      span.text = span.text.substring(0, loc.localOffset) +
          span.text.substring(loc.localOffset + toDelete);

      remaining -= toDelete;

      // Remove empty spans (but keep at least one)
      if (span.text.isEmpty && block.spans.length > 1) {
        block.spans.removeAt(loc.spanIndex);
      }
    }

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

    // Complex paste: multiple blocks, or a single heading block
    // 1. Split current block at the offset
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
  ///
  /// Compares [oldText] with [newText], determines the minimal diff
  /// (insertions/deletions), and updates spans accordingly without
  /// destroying existing formatting.
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

    // Save state for undo (but debounce — don't save on every keystroke)
    // Only save if this is the first change or after a pause
    _saveState();

    // Step 1: Delete the removed characters
    if (deleteLength > 0) {
      _deleteFromSpans(block, deleteStart, deleteLength);
    }

    // Step 2: Insert the new characters
    if (insertedText.isNotEmpty) {
      if (pendingFormat != null) {
        // Insert with specific formatting (pending format from toolbar)
        _insertFormattedIntoSpans(
          block,
          deleteStart,
          insertedText,
          pendingFormat,
        );
      } else {
        // Inherit formatting from the position
        _insertIntoSpans(block, deleteStart, insertedText);
      }
    }

    _notifyChanged();
  }

  /// Internal: Deletes [length] characters starting at [offset] from block spans
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

      // Remove empty spans (but keep at least one)
      if (span.text.isEmpty && block.spans.length > 1) {
        block.spans.removeAt(loc.spanIndex);
      }
    }
  }

  /// Internal: Inserts [text] at [offset] inheriting the span's format at that position
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

  /// Internal: Inserts [text] at [offset] with specific [format]
  void _insertFormattedIntoSpans(
    BlockNode block,
    int offset,
    String text,
    TextFormatSpan format,
  ) {
    // Split at the offset
    _splitSpanAt(block, offset);

    // Find the insert position
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

    // Create new span with the pending format
    final newSpan = format.copyWith(text: text);
    block.spans.insert(insertIndex, newSpan);
  }

  /// Replaces the entire content of a block with new text,
  /// preserving the formatting of the first span.
  /// @deprecated Use [updateBlockText] instead for format-preserving updates.
  void replaceBlockText(int blockIndex, String newText) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    _saveState();

    final block = document.blocks[blockIndex];
    final format =
        block.spans.isNotEmpty ? block.spans.first : TextFormatSpan.plain('');
    block.spans = [format.copyWith(text: newText)];

    _notifyChanged();
  }

  // ─── Formatting Operations ────────────────────────────────────

  /// Toggles a formatting property on a text range within a block.
  ///
  /// [format] is one of: 'bold', 'italic', 'underline', 'strikethrough'
  void toggleFormat(int blockIndex, int start, int end, String format) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    if (start >= end) return;
    _saveState();

    final block = document.blocks[blockIndex];

    // First, split spans at the boundaries
    _splitSpanAt(block, start);
    _splitSpanAt(block, end);

    // Determine if the format is currently active across the entire range
    final isActive = _isFormatActive(block, start, end, format);

    // Apply or remove the format across the range
    var offset = 0;
    for (final span in block.spans) {
      final spanEnd = offset + span.text.length;

      // Check if this span overlaps with [start, end)
      if (offset >= start && spanEnd <= end) {
        _setFormat(span, format, !isActive);
      }

      offset = spanEnd;
    }

    _notifyChanged();
  }

  /// Returns the formatting state at a specific offset in a block
  Map<String, bool> getFormatAt(int blockIndex, int offset) {
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
    };
  }

  Map<String, bool> _defaultFormat() => {
        'bold': false,
        'italic': false,
        'underline': false,
        'strikethrough': false,
      };

  /// Checks if a format is active across the entire [start, end) range
  bool _isFormatActive(BlockNode block, int start, int end, String format) {
    var offset = 0;
    for (final span in block.spans) {
      final spanEnd = offset + span.text.length;

      if (offset >= start && spanEnd <= end && span.text.isNotEmpty) {
        if (!_getFormat(span, format)) return false;
      }

      offset = spanEnd;
    }
    return true;
  }

  /// Gets a format value from a span
  bool _getFormat(TextFormatSpan span, String format) {
    switch (format) {
      case 'bold':
        return span.isBold;
      case 'italic':
        return span.isItalic;
      case 'underline':
        return span.isUnderline;
      case 'strikethrough':
        return span.isStrikethrough;
      default:
        return false;
    }
  }

  /// Sets a format value on a span
  void _setFormat(TextFormatSpan span, String format, bool value) {
    switch (format) {
      case 'bold':
        span.isBold = value;
        break;
      case 'italic':
        span.isItalic = value;
        break;
      case 'underline':
        span.isUnderline = value;
        break;
      case 'strikethrough':
        span.isStrikethrough = value;
        break;
    }
  }

  /// Splits the span at the given global offset, creating two spans
  /// with the same formatting.
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

  /// Splits a block at the given offset into two blocks.
  /// Used when the user presses Enter.
  ///
  /// Returns the index of the new (second) block.
  int splitBlock(int blockIndex, int offset) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) {
      return blockIndex;
    }
    _saveState();

    final block = document.blocks[blockIndex];

    // Collect spans for each half
    final leftSpans = <TextFormatSpan>[];
    final rightSpans = <TextFormatSpan>[];
    var currentOffset = 0;

    for (final span in block.spans) {
      final spanEnd = currentOffset + span.text.length;

      if (spanEnd <= offset) {
        // Entirely in the left half
        leftSpans.add(span.copyWith());
      } else if (currentOffset >= offset) {
        // Entirely in the right half
        rightSpans.add(span.copyWith());
      } else {
        // Split this span
        final splitPoint = offset - currentOffset;
        leftSpans.add(span.copyWith(text: span.text.substring(0, splitPoint)));
        rightSpans.add(span.copyWith(text: span.text.substring(splitPoint)));
      }

      currentOffset = spanEnd;
    }

    // Ensure both halves have at least one span
    if (leftSpans.isEmpty) leftSpans.add(TextFormatSpan.plain(''));
    if (rightSpans.isEmpty) rightSpans.add(TextFormatSpan.plain(''));

    // Update the current block with left spans
    block.spans = leftSpans;

    // Create a new paragraph for the right half (Enter always creates <p>)
    final newBlock = ParagraphNode(spans: rightSpans);
    document.blocks.insert(blockIndex + 1, newBlock);

    _notifyChanged();
    return blockIndex + 1;
  }

  /// Merges a block with its predecessor.
  /// Used when the user presses Backspace at the start of a block.
  ///
  /// Returns the cursor offset in the merged block (end of the previous block's text).
  int mergeWithPrevious(int blockIndex) {
    if (blockIndex <= 0 || blockIndex >= document.blocks.length) return 0;
    _saveState();

    final previous = document.blocks[blockIndex - 1];
    final current = document.blocks[blockIndex];
    final cursorOffset = previous.textLength;

    // Append current block's spans to the previous block
    previous.spans.addAll(current.spans);
    previous.normalizeSpans();

    // Remove the current block
    document.blocks.removeAt(blockIndex);

    _notifyChanged();
    return cursorOffset;
  }

  /// Changes the block type (e.g., paragraph ↔ heading)
  void changeBlockType(int blockIndex, BlockType newType) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    _saveState();

    final oldBlock = document.blocks[blockIndex];
    final spans = oldBlock.spans;
    final alignment = oldBlock.alignment;

    BlockNode newBlock;
    switch (newType) {
      case BlockType.paragraph:
        newBlock = ParagraphNode(spans: spans, alignment: alignment);
        break;
      case BlockType.heading1:
        newBlock = HeadingNode(level: 1, spans: spans, alignment: alignment);
        break;
      case BlockType.heading2:
        newBlock = HeadingNode(level: 2, spans: spans, alignment: alignment);
        break;
      case BlockType.heading3:
        newBlock = HeadingNode(level: 3, spans: spans, alignment: alignment);
        break;
      case BlockType.heading4:
        newBlock = HeadingNode(level: 4, spans: spans, alignment: alignment);
        break;
      case BlockType.heading5:
        newBlock = HeadingNode(level: 5, spans: spans, alignment: alignment);
        break;
      case BlockType.heading6:
        newBlock = HeadingNode(level: 6, spans: spans, alignment: alignment);
        break;
    }
    document.blocks[blockIndex] = newBlock;

    _notifyChanged();
  }

  // ─── Undo / Redo ──────────────────────────────────────────────

  /// Undoes the last change
  bool undo() {
    final previous = undoRedoManager.undo(document);
    if (previous == null) return false;
    document = previous;
    _notifyChanged();
    return true;
  }

  /// Redoes the last undone change
  bool redo() {
    final next = undoRedoManager.redo(document);
    if (next == null) return false;
    document = next;
    _notifyChanged();
    return true;
  }

  // ─── Document Operations ──────────────────────────────────────

  /// Replaces the entire document with a new one
  void setDocument(Document newDocument) {
    _saveState();
    document = newDocument;
    _notifyChanged();
  }

  /// Clears all content, resetting to a single empty paragraph
  void clear() {
    _saveState();
    document = Document();
    _notifyChanged();
  }
}
