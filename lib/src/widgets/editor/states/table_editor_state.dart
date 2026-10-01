import 'package:flutter/material.dart';
import '../../../core/document/document.dart';
import '../../../models/enums.dart';
import '../../../models/pending_inline_format.dart';
import '../keyboard_done_overlay.dart';
import 'base_editor_state.dart';

/// Mixin managing table cell selection, cell focus, cell editing, and cell-level formatting.
mixin TableEditorMixin on BaseEditorState {
  /// Table cell focus tracking.
  int focusedCellRow = -1;
  int focusedCellCol = -1;

  /// Info about the currently focused table cell, or null if not inside a table.
  ({int blockIndex, int row, int col})? get focusedTableInfo {
    if (focusedBlockIndex < 0 || focusedBlockIndex >= document.blocks.length) {
      return null;
    }
    if (document.blocks[focusedBlockIndex] is! TableNode) return null;
    if (focusedCellRow < 0 || focusedCellCol < 0) return null;
    return (
      blockIndex: focusedBlockIndex,
      row: focusedCellRow,
      col: focusedCellCol,
    );
  }

  @override
  void setPendingInlineFormat(PendingInlineFormat format) {
    setState(() {
      pendingInline = format;
      final info = focusedTableInfo;
      if (info != null) {
        pendingFormatBlockIndex = info.blockIndex;
        pendingFormatCellRow = info.row;
        pendingFormatCellCol = info.col;

        final tableId = document.blocks[info.blockIndex].id;
        final rawOffset =
            tableBlockKeys[tableId]?.currentState?.cursorOffset ?? 1;
        pendingFormatOffset = (rawOffset - 1).clamp(0, 1 << 30);
      } else {
        super.setPendingInlineFormat(format);
      }
    });
  }

  @override
  void requestEditorFocus() {
    final info = focusedTableInfo;
    if (info != null) {
      final tableId = document.blocks[info.blockIndex].id;
      tableBlockKeys[tableId]
          ?.currentState
          ?.requestFocusOnCell(info.row, info.col);
      return;
    }
    super.requestEditorFocus();
  }

  @override
  void setCursorPosition(int blockIndex, int docOffset, {int? row, int? col}) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;

    if (row != null && col != null) {
      toolbarRangeSelection = null;
      toolbarRangeBlockIndex = null;
      pendingInline = null;
      hideLinkTooltip();

      focusedBlockIndex = blockIndex;
      focusedCellRow = row;
      focusedCellCol = col;
      final block = document.blocks[blockIndex];
      if (block is TableNode) {
        final tableId = block.id;
        final tableState = tableBlockKeys[tableId]?.currentState;
        tableState?.requestFocusOnCell(row, col);
        final cellKey = tableState?.getCellKey(row, col);
        cellKey?.currentState?.setCursorPosition(docOffset + 1);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          cellKey?.currentState?.setCursorPosition(docOffset + 1);
          final formats =
              docController.getCellFormatAt(blockIndex, row, col, docOffset);
          formats[SmartButtonType.insertLink] = false;
          widget.editorSettings.onChangeSelection?.call(formats);
          widget.onFormatStateChanged?.call(blockIndex, formats);
          checkCellLinkTooltip(blockIndex, row, col, docOffset);
        });
      }
      docController.refresh();
      return;
    }

    super.setCursorPosition(blockIndex, docOffset);
  }

  @override
  void setSelection(int blockIndex, int startOffset, int endOffset,
      {int? row, int? col}) {
    if (row != null && col != null) {
      if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
      final block = document.blocks[blockIndex];
      if (block is TableNode) {
        final normStart = startOffset.clamp(0, 1 << 30);
        final normEnd = endOffset.clamp(0, 1 << 30);
        final minOffset = normStart < normEnd ? normStart : normEnd;
        final maxOffset = normStart < normEnd ? normEnd : normStart;

        toolbarRangeSelection =
            TextSelection(baseOffset: minOffset, extentOffset: maxOffset);
        toolbarRangeBlockIndex = blockIndex;
        pendingInline = null;

        focusedBlockIndex = blockIndex;
        focusedCellRow = row;
        focusedCellCol = col;

        final tableId = block.id;
        final tableState = tableBlockKeys[tableId]?.currentState;
        tableState?.requestFocusOnCell(row, col);
        final cellKey = tableState?.getCellKey(row, col);
        cellKey?.currentState?.setSelection(normStart + 1, normEnd + 1);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          cellKey?.currentState?.setSelection(normStart + 1, normEnd + 1);
          final formats =
              docController.getCellFormatAt(blockIndex, row, col, minOffset);
          widget.editorSettings.onChangeSelection?.call(formats);
          widget.onFormatStateChanged?.call(blockIndex, formats);
          checkCellLinkTooltip(blockIndex, row, col, minOffset, maxOffset);
        });
        docController.refresh();
        return;
      }
    }

    super.setSelection(blockIndex, startOffset, endOffset);
  }

  @override
  int? get cursorOffset {
    final info = focusedTableInfo;
    if (info != null) {
      final tableId = document.blocks[info.blockIndex].id;
      final raw = tableBlockKeys[tableId]?.currentState?.cursorOffset;
      if (raw == null) return null;
      return (raw - 1).clamp(0, 1 << 30);
    }
    return super.cursorOffset;
  }

  @override
  TextSelection? get selection {
    final info = focusedTableInfo;
    if (info != null) {
      final tableId = document.blocks[info.blockIndex].id;
      final raw = tableBlockKeys[tableId]?.currentState?.selection;
      if (raw == null || !raw.isValid) return null;
      return BaseEditorState.normalizeTextSelection(raw);
    }
    return super.selection;
  }

  @override
  TextSelection? get selectionForToolbar {
    final info = focusedTableInfo;
    if (info != null) {
      final tableId = document.blocks[info.blockIndex].id;
      final raw = tableBlockKeys[tableId]?.currentState?.selection;
      TextSelection? live;
      if (raw != null && raw.isValid) {
        live = BaseEditorState.normalizeTextSelection(raw);
      }
      if (live != null && live.isValid && !live.isCollapsed) {
        return live;
      }
      if (toolbarRangeSelection != null &&
          toolbarRangeBlockIndex == focusedBlockIndex) {
        final len = (document.blocks[focusedBlockIndex] as TableNode)
            .getCell(info.row, info.col)
            .plainText
            .length;
        final r = toolbarRangeSelection!;
        if (r.isValid && r.start >= 0 && r.end <= len && r.start < r.end) {
          return r;
        }
      }
      return live;
    }
    return super.selectionForToolbar;
  }

  @override
  Map<SmartButtonType, dynamic> getToolbarFormatState() {
    final info = focusedTableInfo;
    if (info != null) {
      final tableId = document.blocks[info.blockIndex].id;
      final raw = tableBlockKeys[tableId]?.currentState?.selection;
      TextSelection? sel;
      if (raw != null && raw.isValid) {
        sel = BaseEditorState.normalizeTextSelection(raw);
      }
      int offset = sel?.baseOffset ?? 0;
      if (sel != null &&
          !sel.isCollapsed &&
          sel.start < document.blocks[focusedBlockIndex].textLength) {
        offset = sel.start + 1;
      }
      return getMergedFormats(focusedBlockIndex, offset);
    }
    return super.getToolbarFormatState();
  }

  @override
  Map<SmartButtonType, dynamic> getMergedFormats(int blockIndex, int offset) {
    final block = document.blocks[blockIndex];
    if (block is TableNode && focusedCellRow >= 0 && focusedCellCol >= 0) {
      final formats = docController.getCellFormatAt(
          blockIndex, focusedCellRow, focusedCellCol, offset);
      if (pendingInline != null) {
        pendingInline!.mergeIntoToolbarMap(formats);
      }
      return formats;
    }
    return super.getMergedFormats(blockIndex, offset);
  }

  @override
  void rebuild() {
    super.rebuild();

    // After rebuild, report updated formatting to the toolbar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final blockIndex = focusedBlockIndex;
      if (blockIndex < document.blocks.length) {
        final info = focusedTableInfo;
        Map<SmartButtonType, dynamic> formats;
        if (info != null) {
          final tableId = document.blocks[info.blockIndex].id;
          final raw = tableBlockKeys[tableId]?.currentState?.selection;
          final sel = raw != null && raw.isValid
              ? BaseEditorState.normalizeTextSelection(raw)
              : null;
          int offset = sel?.baseOffset ?? 0;
          if (sel != null && !sel.isCollapsed) {
            final cellLen = (document.blocks[info.blockIndex] as TableNode)
                .getCell(info.row, info.col)
                .plainText
                .length;
            if (sel.start < cellLen) {
              offset = sel.start + 1;
            }
          }
          formats = docController.getCellFormatAt(
              info.blockIndex, info.row, info.col, offset);
        } else {
          final raw = blockKeys[document.blocks[blockIndex].id]
              ?.currentState
              ?.selection;
          final sel = raw != null && raw.isValid
              ? BaseEditorState.normalizeTextSelection(raw)
              : null;
          int offset = sel?.baseOffset ?? 0;

          if (sel != null &&
              !sel.isCollapsed &&
              sel.start < document.blocks[blockIndex].textLength) {
            offset = sel.start + 1;
          }

          formats = getMergedFormats(blockIndex, offset);
        }
        widget.onFormatStateChanged?.call(blockIndex, formats);
      }
    });
  }

  // ─── Table Cell Callbacks ─────────────────────────────────────

  @protected
  void onCellFocusChanged(int blockIndex, int row, int col, bool hasFocus) {
    if (hasFocus) {
      focusedBlockIndex = blockIndex;
      focusedCellRow = row;
      focusedCellCol = col;
      widget.editorSettings.onFocus?.call();
      KeyboardDoneOverlay.show(context);

      // Report cell format state to toolbar
      final formats = docController.getCellFormatAt(blockIndex, row, col, 0);
      widget.editorSettings.onChangeSelection?.call(formats);
      widget.onFormatStateChanged?.call(blockIndex, formats);
      checkCellLinkTooltip(blockIndex, row, col, 0);
    } else {
      widget.editorSettings.onBlur?.call();
      hideLinkTooltip();
      Future.delayed(const Duration(milliseconds: 50), () {
        if (!mounted) return;
        final anyFocused = focusNodes.values.any((node) => node.hasFocus);
        if (!anyFocused) {
          KeyboardDoneOverlay.hide();
        }
      });
    }
  }

  @protected
  void onCellSelectionChanged(
      int blockIndex, int row, int col, int base, int extent) {
    focusedBlockIndex = blockIndex;
    focusedCellRow = row;
    focusedCellCol = col;

    final tableId = document.blocks[blockIndex].id;
    final isCellFocused =
        tableBlockKeys[tableId]?.currentState?.isCellFocused(row, col) ?? false;

    final int normBase = (base - 1).clamp(0, 1 << 30);
    final int normExtent = (extent - 1).clamp(0, 1 << 30);
    final int minOffset = normBase < normExtent ? normBase : normExtent;
    final int maxOffset = normBase < normExtent ? normExtent : normBase;

    if (normBase != normExtent) {
      toolbarRangeSelection =
          TextSelection(baseOffset: minOffset, extentOffset: maxOffset);
      toolbarRangeBlockIndex = blockIndex;
      checkCellLinkTooltip(blockIndex, row, col, minOffset, maxOffset);
    } else if (isCellFocused) {
      toolbarRangeSelection = null;
      toolbarRangeBlockIndex = null;
      checkCellLinkTooltip(blockIndex, row, col, minOffset);
    } else {
      hideLinkTooltip();
    }

    int probeOffset = minOffset;

    final formats =
        docController.getCellFormatAt(blockIndex, row, col, probeOffset);
    widget.editorSettings.onChangeSelection?.call(formats);
    widget.onFormatStateChanged?.call(blockIndex, formats);
    docController.refresh();
  }

  @protected
  void onCellTextChanged(int blockIndex, int row, int col, String newText) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! TableNode) return;
    hideLinkTooltip();

    isTyping = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) isTyping = false;
    });

    final cell = block.getCell(row, col);
    final oldText = cell.plainText;

    final insertAt = BaseEditorState.insertOffsetInOldText(oldText, newText);
    TextFormatSpan? pendingSpan;
    if (pendingInline != null &&
        pendingFormatBlockIndex == blockIndex &&
        pendingFormatCellRow == row &&
        pendingFormatCellCol == col) {
      pendingSpan = pendingInline!.resolveForInsert(cell.block, insertAt);
    }

    docController.updateCellText(
      blockIndex,
      row,
      col,
      oldText,
      newText,
      pendingFormat: pendingSpan,
    );
    notifyContentChanged();
  }

  @protected
  void onCellPaste(int blockIndex, int row, int col) {
    hideLinkTooltip();
    // Delegate to the same paste flow as block paste
    onPaste(blockIndex);
  }
}

/// Backwards-compatibility alias for [TableEditorMixin].
typedef TableEditorState = TableEditorMixin;
