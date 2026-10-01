import 'package:flutter/material.dart';
import '../../../core/document/document.dart';
import '../../../models/enums.dart';
import 'base_editor_state.dart';

/// Mixin handling block-level mutations, indentation, list numbering, and keyboard structural events.
mixin BlockEditorMixin on BaseEditorState {
  @protected
  void saveState() {
    docController.undoRedoManager.pushState(docController.document);
  }

  /// Called when Enter is pressed in a block
  @protected
  void onEnter(int blockIndex, int offset) {
    widget.editorSettings.onEnter?.call();

    final block = document.blocks[blockIndex];

    // Special Enter behavior for list items
    if (block is ListItemNode) {
      final isEmpty = block.plainText.trim().isEmpty;
      if (isEmpty && block.depth > 0) {
        // De-indent
        docController.decreaseIndent(blockIndex);
        setState(() {});
        notifyContentChanged();
        return;
      } else if (isEmpty && block.depth == 0) {
        // Exit list → become paragraph
        docController.toggleList(blockIndex, block.listType);
        setState(() {
          syncFocusNodes();
        });
        notifyContentChanged();
        return;
      } else {
        // Insert new list item of same type and depth
        saveState();
        final newItem = ListItemNode(
          listType: block.listType,
          depth: block.depth,
          bulletStyle: block.bulletStyle,
        );
        docController.document.blocks.insert(blockIndex + 1, newItem);
        docController.document.normalize();
        setState(() {
          syncFocusNodes();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (blockIndex + 1 < document.blocks.length) {
            final id = document.blocks[blockIndex + 1].id;
            focusNodes[id]?.requestFocus();
            blockKeys[id]?.currentState?.setCursorPosition(0);
          }
        });
        notifyContentChanged();
        return;
      }
    }

    final newBlockIndex = docController.splitBlock(
      blockIndex,
      offset,
      pendingFormat: pendingInline?.resolveForInsert(
          document.blocks[blockIndex], offset),
    );

    pendingInline = null;

    setState(() {
      syncFocusNodes();
    });

    // Focus the new block after rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (newBlockIndex < document.blocks.length) {
        final id = document.blocks[newBlockIndex].id;
        focusNodes[id]?.requestFocus();
        blockKeys[id]?.currentState?.setCursorPosition(0);
      }
    });

    notifyContentChanged();
  }

  @protected
  void onIncreaseIndent(int blockIndex) {
    docController.increaseIndent(
      blockIndex,
      maxDepth: widget.editorSettings.maxListDepth,
    );
    setState(() {});
    notifyContentChanged();
  }

  @protected
  void onDecreaseIndent(int blockIndex) {
    final id = document.blocks[blockIndex].id;
    final cursorOffset = blockKeys[id]?.currentState?.cursorOffset ?? 0;

    docController.decreaseIndent(blockIndex);

    setState(() {
      syncFocusNodes();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (blockIndex < document.blocks.length) {
        focusNodes[id]?.requestFocus();
        blockKeys[id]?.currentState?.setCursorPosition(cursorOffset);
      }
    });

    notifyContentChanged();
  }

  @protected
  void onHrTap(int blockIndex) {
    final nextIndex = blockIndex + 1;
    if (nextIndex < document.blocks.length) {
      final id = document.blocks[nextIndex].id;
      focusNodes[id]?.requestFocus();
      focusedBlockIndex = nextIndex;
    }
  }

  /// Computes the 1-based ordered counter for a list item at [blockIndex].
  @protected
  int computeOrderedCount(int blockIndex) {
    final blocks = document.blocks;
    final current = blocks[blockIndex];
    if (current is! ListItemNode || current.listType != SmartListType.ordered) {
      return 1;
    }
    final depth = current.depth;
    int count = 1;
    for (int i = blockIndex - 1; i >= 0; i--) {
      final prev = blocks[i];
      if (prev is! ListItemNode) break;
      if (prev.depth == depth && prev.listType == SmartListType.ordered) {
        count++;
      } else if (prev.depth < depth) {
        break;
      }
    }
    return count;
  }

  /// Called when Backspace is pressed at the start of a block
  @protected
  void onBackspaceAtStart(int blockIndex) {
    if (blockIndex <= 0) return;

    final currentBlock = document.blocks[blockIndex];
    final prevBlock = document.blocks[blockIndex - 1];

    // Smart Backspace for Lists
    if (currentBlock is ListItemNode) {
      if (currentBlock.textLength == 0) {
        docController.mergeWithPrevious(blockIndex);
        setState(() {
          syncFocusNodes();
        });
        focusTarget(blockIndex - 1);
        return;
      }

      if (currentBlock.depth > 0) {
        onDecreaseIndent(blockIndex);
        return;
      }

      if (prevBlock is ListItemNode &&
          prevBlock.listType == currentBlock.listType) {
        final cursorOffset = docController.mergeWithPrevious(blockIndex);
        setState(() {
          syncFocusNodes();
        });
        focusTarget(blockIndex - 1, offset: cursorOffset);
        return;
      }

      docController.changeBlockType(blockIndex, BlockType.paragraph);
      rebuild();
      return;
    }

    final cursorOffset = docController.mergeWithPrevious(blockIndex);
    final targetIndex = blockIndex - 1;

    pendingInline = null;

    setState(() {
      syncFocusNodes();
    });

    focusTarget(targetIndex, offset: cursorOffset);
    notifyContentChanged();
  }

  /// Called when Delete is pressed at the end of a block
  @protected
  void onDeleteAtEnd(int blockIndex) {
    if (blockIndex >= document.blocks.length - 1) return;

    final nextBlock = document.blocks[blockIndex + 1];

    if (nextBlock is ListItemNode) {
      if (nextBlock.depth > 0) {
        onDecreaseIndent(blockIndex + 1);
        return;
      } else {
        docController.changeBlockType(blockIndex + 1, BlockType.paragraph);
        rebuild();
        return;
      }
    }

    final cursorOffset = document.blocks[blockIndex].textLength;
    docController.mergeWithPrevious(blockIndex + 1);

    setState(() {
      syncFocusNodes();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (blockIndex < document.blocks.length) {
        final id = document.blocks[blockIndex].id;
        focusNodes[id]?.requestFocus();
        blockKeys[id]?.currentState?.setCursorPosition(cursorOffset);
      }
    });

    notifyContentChanged();
  }
}

/// Backwards-compatibility alias for [BlockEditorMixin].
typedef BlockEditorState = BlockEditorMixin;
