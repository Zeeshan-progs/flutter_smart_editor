import 'package:flutter/material.dart';
import '../../../models/search/search_index.dart';
import '../smart_editor_widget.dart';

/// Mixin managing Find & Replace live search match scrolling, highlighting focus, and state updates.
mixin SearchEditorMixin on BaseEditorState {
  @override
  void initState() {
    super.initState();
    widget.controller?.searchStateNotifier.addListener(onSearchStateChanged);
    widget.controller?.attachEditor(this as SmartEditorWidgetState);
  }

  @override
  void didUpdateWidget(SmartEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.searchStateNotifier
          .removeListener(onSearchStateChanged);
      widget.controller?.searchStateNotifier.addListener(onSearchStateChanged);
      widget.controller?.attachEditor(this as SmartEditorWidgetState);
    }
  }

  @override
  void dispose() {
    widget.controller?.searchStateNotifier
        .removeListener(onSearchStateChanged);
    super.dispose();
  }

  @protected
  void onSearchStateChanged() {
    safeSetState(() {});
  }

  /// Scrolls to make the block or table containing [match] visible.
  void scrollToMatch(SearchMatch match) {
    if (!mounted) return;
    if (match.blockIndex < 0 || match.blockIndex >= document.blocks.length) {
      return;
    }
    final block = document.blocks[match.blockIndex];

    BuildContext? targetContext;
    if (match.isTableCell && match.row != null && match.col != null) {
      final tableState = tableBlockKeys[block.id]?.currentState;
      targetContext =
          tableState?.getCellKey(match.row!, match.col!)?.currentContext ??
              tableBlockKeys[block.id]?.currentContext;
    } else {
      targetContext = blockKeys[block.id]?.currentContext;
    }

    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  /// Sets text selection to highlight/focus the exact match in the target block or table cell.
  void selectMatch(SearchMatch match, {bool requestFocus = false}) {
    if (!mounted) return;
    if (match.blockIndex < 0 || match.blockIndex >= document.blocks.length) {
      return;
    }
    final block = document.blocks[match.blockIndex];

    // +1 offset accounts for the ZWSP character at index 0 of BlockWidget
    final start = match.start + 1;
    final end = match.end + 1;

    if (match.isTableCell && match.row != null && match.col != null) {
      final tableState = tableBlockKeys[block.id]?.currentState;
      if (tableState != null) {
        if (requestFocus) {
          tableState.focusCell(match.row!, match.col!);
        }
        final cellState =
            tableState.getCellKey(match.row!, match.col!)?.currentState;
        cellState?.setSelection(start, end);
      }
    } else {
      if (requestFocus) {
        focusNodes[block.id]?.requestFocus();
      }
      blockKeys[block.id]?.currentState?.setSelection(start, end);
    }
  }
}

/// Backwards-compatibility alias for [SearchEditorMixin].
typedef SearchEditorState = SearchEditorMixin;
