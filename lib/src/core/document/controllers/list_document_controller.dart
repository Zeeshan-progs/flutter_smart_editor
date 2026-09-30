import 'package:flutter_smart_editor/src/core/document/document.dart';
import '../../../models/enums.dart';
import 'formatting_document_controller.dart';

/// Controller handling bullet, ordered lists, indentations, and bullet styling.
class ListDocumentController extends FormattingDocumentController {
  ListDocumentController({
    super.document,
    super.undoRedoManager,
  });

  // ─── List Operations ──────────────────────────────────────────

  /// Toggles a list type on the block at [blockIndex].
  /// - If already a list of the same type → reverts to paragraph.
  /// - If a list of the other type → switches type, preserving depth.
  /// - Otherwise → converts to a list item at depth 0.
  void toggleList(int blockIndex, SmartListType listType) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    saveState();

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

    notifyChanged();
  }

  /// Increases the nesting depth of the list item at [blockIndex].
  /// No-op if already at [maxDepth] or block is not a [ListItemNode].
  void increaseIndent(int blockIndex, {int maxDepth = 3}) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! ListItemNode) return;
    if (block.depth >= maxDepth - 1) return;
    saveState();
    document.blocks[blockIndex] = block.copyWithDepth(block.depth + 1);
    notifyChanged();
  }

  /// Decreases the nesting depth of the list item at [blockIndex].
  /// If depth is already 0, converts the item to a [ParagraphNode].
  void decreaseIndent(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! ListItemNode) return;
    saveState();
    if (block.depth <= 0) {
      document.blocks[blockIndex] = ParagraphNode(
          id: block.id, spans: block.spans, alignment: block.alignment);
    } else {
      document.blocks[blockIndex] = block.copyWithDepth(block.depth - 1);
    }
    notifyChanged();
  }

  /// Applies a custom [SmartBulletStyle] to all list items in the same
  /// contiguous group as [blockIndex].
  void setBulletStyle(int blockIndex, SmartBulletStyle style) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! ListItemNode || block.listType != SmartListType.bullet) {
      return;
    }
    saveState();

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
    notifyChanged();
  }
}
