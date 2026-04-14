import 'package:flutter/material.dart';
import 'package:flutter_smart_editor/src/core/document/document.dart';
import '../../models/enums.dart';
import '../infra/html_parser.dart';
import '../infra/html_serializer.dart';
import 'undo_redo_manager.dart';

/// Editing operations on the [Document] model.
///
/// This is the internal engine that performs text insertion, deletion,
/// formatting toggles, block splitting/merging, and block type changes.
/// All operations modify the document in place and push undo states.
class DocumentController extends ChangeNotifier {
  Document document;
  final UndoRedoManager undoRedoManager;

  DocumentController({
    Document? document,
    UndoRedoManager? undoRedoManager,
  })  : document = document ?? Document(),
        undoRedoManager = undoRedoManager ?? UndoRedoManager();

  /// Callback for providing user feedback (e.g., SnackBars).
  void Function(String message)? onMessage;

  /// Gets the HTML for a specific selection range within a block.
  String getSelectedHtml(int blockIndex, TextSelection selection) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return '';
    final block = document.blocks[blockIndex];
    if (selection.isCollapsed) return '';

    final start = selection.start;
    final end = selection.end;

    // Create a temporary block to serialize just the selection
    final tempBlock = block.deepCopy();
    _deleteFromSpans(tempBlock, end, tempBlock.textLength - end);
    _deleteFromSpans(tempBlock, 0, start);

    final tempDoc = Document(blocks: [tempBlock]);
    return SmartHtmlSerializer().serialize(tempDoc);
  }

  /// Gets the plain text for a specific selection range within a block.
  String getSelectedPlainText(int blockIndex, TextSelection selection) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return '';
    final block = document.blocks[blockIndex];
    if (selection.isCollapsed) return '';
    return block.plainText.substring(selection.start, selection.end);
  }

  /// Saves the current state before making a change
  void _saveState() {
    undoRedoManager.pushState(document);
  }

  /// Notifies listeners that the document changed
  void _notifyChanged() {
    document.normalize();
    notifyListeners();
  }

  /// Restoration method for undo/redo
  void _restoreState(Document state) {
    document = state;
    _notifyChanged();
  }

  // ─── History Operations ───────────────────────────────────────

  bool get canUndo => undoRedoManager.canUndo;
  bool get canRedo => undoRedoManager.canRedo;

  void undo() {
    final state = undoRedoManager.undo(document);
    if (state != null) {
      _restoreState(state);
    }
  }

  void redo() {
    final state = undoRedoManager.redo(document);
    if (state != null) {
      _restoreState(state);
    }
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

  void toggleFormat(
      int blockIndex, int start, int end, SmartButtonType format) {
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

  void applyFormat(int blockIndex, int start, int end, SmartButtonType format,
      dynamic value) {
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

  Map<SmartButtonType, dynamic> getFormatAt(int blockIndex, int offset) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) {
      return _defaultFormat();
    }

    final block = document.blocks[blockIndex];
    if (block.spans.isEmpty) return _defaultFormat();

    final loc = block.getSpanAt(offset);
    if (loc.spanIndex >= block.spans.length) return _defaultFormat();

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
    };
  }

  Map<SmartButtonType, dynamic> _defaultFormat() => {
        SmartButtonType.bold: false,
        SmartButtonType.italic: false,
        SmartButtonType.underline: false,
        SmartButtonType.strikethrough: false,
        SmartButtonType.fontName: null,
        SmartButtonType.fontSize: null,
        SmartButtonType.foregroundColor: null,
        SmartButtonType.highlightColor: null,
        SmartButtonType.alignLeft: true,
      };

  dynamic _getFormat(TextFormatSpan span, SmartButtonType format) {
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
      default:
        return null;
    }
  }

  void _setFormat(TextFormatSpan span, SmartButtonType format, dynamic value) {
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
      case SmartButtonType.clearFormatting:
        span.isBold = false;
        span.isItalic = false;
        span.isUnderline = false;
        span.isStrikethrough = false;
        span.fontFamily = null;
        span.fontSize = null;
        span.foregroundColor = null;
        span.backgroundColor = null;
        break;
      default:
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

    final previous = document.blocks[blockIndex - 1];
    final current = document.blocks[blockIndex];

    // Don't merge text into non-text blocks like HR
    if (previous is HorizontalRuleNode || current is HorizontalRuleNode) {
      if (current.textLength == 0) {
        // Just delete the empty block
        _saveState();
        document.blocks.removeAt(blockIndex);
        _notifyChanged();
        return 0;
      }
      return 0;
    }

    _saveState();

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
      case BlockType.bulletList:
        newBlock = ListItemNode(
            id: id,
            listType: SmartListType.bullet,
            spans: spans,
            alignment: alignment);
        break;
      case BlockType.orderedList:
        newBlock = ListItemNode(
            id: id,
            listType: SmartListType.ordered,
            spans: spans,
            alignment: alignment);
        break;
      case BlockType.horizontalRule:
        newBlock = HorizontalRuleNode(id: id);
        break;
    }

    document.blocks[blockIndex] = newBlock;
    _notifyChanged();
  }

  // ─── List Operations ──────────────────────────────────────────

  /// Toggles a list type on the block at [blockIndex].
  /// - If already a list of the same type → reverts to paragraph.
  /// - If a list of the other type → switches type, preserving depth.
  /// - Otherwise → converts to a list item at depth 0.
  void toggleList(int blockIndex, SmartListType listType) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    _saveState();

    final block = document.blocks[blockIndex];

    if (block is ListItemNode) {
      if (block.listType == listType) {
        // Same type: exit list
        document.blocks[blockIndex] = ParagraphNode(
            id: block.id, spans: block.spans, alignment: block.alignment);
      } else {
        // Different type: switch type, keep depth
        document.blocks[blockIndex] = ListItemNode(
          id: block.id,
          listType: listType,
          depth: block.depth,
          bulletStyle: block.bulletStyle,
          spans: block.spans,
          alignment: block.alignment,
        );
      }
    } else {
      // Convert to list item at depth 0
      document.blocks[blockIndex] = ListItemNode(
        id: block.id,
        listType: listType,
        depth: 0,
        spans: block.spans,
        alignment: block.alignment,
      );
    }

    _notifyChanged();
  }

  /// Increases the nesting depth of the list item at [blockIndex].
  /// No-op if already at [maxDepth] or block is not a [ListItemNode].
  void increaseIndent(int blockIndex, {int maxDepth = 3}) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! ListItemNode) return;
    if (block.depth >= maxDepth - 1) return;
    _saveState();
    document.blocks[blockIndex] = block.copyWithDepth(block.depth + 1);
    _notifyChanged();
  }

  /// Decreases the nesting depth of the list item at [blockIndex].
  /// If depth is already 0, converts the item to a [ParagraphNode].
  void decreaseIndent(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! ListItemNode) return;
    _saveState();
    if (block.depth <= 0) {
      document.blocks[blockIndex] = ParagraphNode(
          id: block.id, spans: block.spans, alignment: block.alignment);
    } else {
      document.blocks[blockIndex] = block.copyWithDepth(block.depth - 1);
    }
    _notifyChanged();
  }

  /// Applies a custom [SmartBulletStyle] to all list items in the same
  /// contiguous group as [blockIndex].
  void setBulletStyle(int blockIndex, SmartBulletStyle style) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! ListItemNode || block.listType != SmartListType.bullet) {
      return;
    }
    _saveState();

    // Find start of this contiguous group at depth 0
    int start = blockIndex;
    while (start > 0 && document.blocks[start - 1] is ListItemNode) {
      start--;
    }
    int end = blockIndex;
    while (end < document.blocks.length - 1 &&
        document.blocks[end + 1] is ListItemNode) {
      end++;
    }

    for (var i = start; i <= end; i++) {
      final b = document.blocks[i];
      if (b is ListItemNode && b.listType == SmartListType.bullet) {
        document.blocks[i] = b.copyWithBulletStyle(style);
      }
    }
    _notifyChanged();
  }

  /// Inserts a [HorizontalRuleNode] after the block at [blockIndex].
  /// Also inserts an empty paragraph after the HR so the cursor can continue.
  void insertHorizontalRule(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    _saveState();
    final hr = HorizontalRuleNode();
    final para = ParagraphNode();
    document.blocks.insertAll(blockIndex + 1, [hr, para]);
    _notifyChanged();
  }

  /// Moves the block at [fromIndex] to [toIndex] (for drag-and-drop).
  void moveBlock(int fromIndex, int toIndex) {
    moveBlockRange(fromIndex, 1, toIndex);
  }

  /// Moves a range of blocks starting at [fromIndex] to [toIndex].
  void moveBlockRange(int fromIndex, int count, int toIndex) {
    if (fromIndex < 0 || toIndex < 0 || count <= 0) return;
    if (fromIndex + count > document.blocks.length) return;

    if (fromIndex == toIndex) return;

    _saveState();

    // 1. Extract the blocks to move
    final movedBlocks = <BlockNode>[];
    for (var i = 0; i < count; i++) {
      movedBlocks.add(document.blocks[fromIndex + i]);
    }

    // 2. Remove from original position
    // We remove them in reverse to avoid index issues if we were doing it one by one,
    // but here we can just use removeRange.
    document.blocks.removeRange(fromIndex, fromIndex + count);

    // 3. Adjust target index if we removed items from BEFORE it
    int insertAt = toIndex;
    if (fromIndex < toIndex) {
      insertAt -= count;
    }

    // 4. Boundary check for insertion
    if (insertAt < 0) insertAt = 0;
    if (insertAt > document.blocks.length) insertAt = document.blocks.length;

    // 5. Insert at new position
    document.blocks.insertAll(insertAt, movedBlocks);

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

  // ─── Clipboard Operations ─────────────────────────────────────

  /// Serializes the selected range within a block to HTML.
  String getSelectedHtml(int blockIndex, TextSelection selection) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return '';
    if (selection.isCollapsed) return '';

    final block = document.blocks[blockIndex];
    final start = selection.start;
    final end = selection.end;

    // Create a temporary block with only the selected spans
    final selectedSpans = <TextFormatSpan>[];
    var offset = 0;

    for (var span in block.spans) {
      final spanLen = span.text.length;
      final spanStart = offset;
      final spanEnd = offset + spanLen;

      final intersectStart = spanStart > start ? spanStart : start;
      final intersectEnd = spanEnd < end ? spanEnd : end;

      if (intersectStart < intersectEnd) {
        selectedSpans.add(span.copyWith(
          text: span.text.substring(
            intersectStart - spanStart,
            intersectEnd - spanStart,
          ),
        ));
      }
      offset = spanEnd;
    }

    if (selectedSpans.isEmpty) return '';

    // Serialize as a fragment
    final tempDoc = Document(blocks: [ParagraphNode(spans: selectedSpans)]);
    final serializer = SmartHtmlSerializer();
    return serializer.serialize(tempDoc);
  }

  /// Parses HTML and inserts it at the given location.
  void pasteHtml(int blockIndex, int offset, String html,
      {required SmartHtmlParser parser}) {
    if (html.isEmpty) return;
    final parsedDoc = parser.parse(html);
    insertParsedDocument(blockIndex, offset, parsedDoc);
  }
}
