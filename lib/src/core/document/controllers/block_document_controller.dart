import 'package:flutter_smart_editor/src/core/document/document.dart';
import '../../../models/enums.dart';
import 'base_document_controller.dart';

/// Controller handling block-level structure, splitting, merging, and type transitions.
class BlockDocumentController extends BaseDocumentController {
  BlockDocumentController({
    super.document,
    super.undoRedoManager,
  });

  // ─── Block Operations ─────────────────────────────────────────

  /// Splits a block at [offset] into two blocks.
  /// Returns the index of the newly created block.
  int splitBlock(int blockIndex, int offset, {TextFormatSpan? pendingFormat}) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) {
      return blockIndex;
    }
    saveState();

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

    notifyChanged();
    return blockIndex + 1;
  }

  /// Merges the block at [blockIndex] into the preceding block.
  /// Returns the cursor offset in the merged block.
  int mergeWithPrevious(int blockIndex) {
    if (blockIndex <= 0 || blockIndex >= document.blocks.length) return 0;

    final previous = document.blocks[blockIndex - 1];
    final current = document.blocks[blockIndex];

    // Don't merge text into non-text blocks like HR
    if (previous is HorizontalRuleNode || current is HorizontalRuleNode) {
      if (current.textLength == 0) {
        // Just delete the empty block
        saveState();
        document.blocks.removeAt(blockIndex);
        notifyChanged();
        return 0;
      }
      return 0;
    }

    saveState();

    final cursorOffset = previous.textLength;

    previous.spans.addAll(current.spans);
    previous.normalizeSpans();
    document.blocks.removeAt(blockIndex);

    notifyChanged();
    return cursorOffset;
  }

  /// Converts the block at [blockIndex] to [newType].
  void changeBlockType(int blockIndex, BlockType newType) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    saveState();

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
      case BlockType.table:
        // Tables cannot be converted to/from other block types
        return;
    }

    document.blocks[blockIndex] = newBlock;
    notifyChanged();
  }

  /// Inserts a [HorizontalRuleNode] after the block at [blockIndex].
  /// Also inserts an empty paragraph after the HR so the cursor can continue.
  void insertHorizontalRule(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    saveState();
    final hr = HorizontalRuleNode();
    final para = ParagraphNode();
    document.blocks.insertAll(blockIndex + 1, [hr, para]);
    notifyChanged();
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

    saveState();

    // 1. Extract the blocks to move
    final movedBlocks = <BlockNode>[];
    for (var i = 0; i < count; i++) {
      movedBlocks.add(document.blocks[fromIndex + i]);
    }

    // 2. Remove from original position
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

    notifyChanged();
  }
}
