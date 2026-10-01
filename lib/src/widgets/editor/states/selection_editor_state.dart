import 'package:flutter/material.dart';
import '../../../models/enums.dart';
import '../../../models/pending_inline_format.dart';
import '../keyboard_done_overlay.dart';
import 'base_editor_state.dart';

/// Mixin managing cursor position, selections, pending inline formats, and format probes.
mixin SelectionEditorMixin on BaseEditorState {
  /// Called when focus changes on a block
  @protected
  void onFocusChanged(int blockIndex, bool hasFocus) {
    if (hasFocus) {
      focusedBlockIndex = blockIndex;
      widget.editorSettings.onFocus?.call();

      KeyboardDoneOverlay.show(context);

      // Clear pending format when changing blocks
      if (blockIndex != pendingFormatBlockIndex) {
        pendingInline = null;
        pendingFormatOffset = null;
        pendingFormatBlockIndex = null;
      }

      final cursorOffsetVal = blockKeys[document.blocks[blockIndex].id]
              ?.currentState
              ?.cursorOffset ??
          0;
      final docOffset = (cursorOffsetVal - 1).clamp(0, 1 << 30);
      final formats = getMergedFormats(blockIndex, docOffset);
      widget.editorSettings.onChangeSelection?.call(formats);
      widget.onFormatStateChanged?.call(blockIndex, formats);
      checkLinkTooltip(blockIndex, docOffset);
    } else {
      widget.editorSettings.onBlur?.call();
      hideLinkTooltip();

      // Delay hiding slightly to prevent flickering when moving between blocks
      Future.delayed(const Duration(milliseconds: 50), () {
        final anyFocused = focusNodes.values.any((node) => node.hasFocus);
        if (!anyFocused) {
          KeyboardDoneOverlay.hide();
        }
      });
    }
  }

  @protected
  void onSelectionChanged(int blockIndex, int baseOffset, int extentOffset) {
    focusedBlockIndex = blockIndex;
    final blockId = document.blocks[blockIndex].id;
    final hasFocus = focusNodes[blockId]?.hasFocus ?? false;

    // Normalize raw offsets from BlockWidget (subtract 1 for ZWSP)
    final normBase = (baseOffset - 1).clamp(0, 1 << 30);
    final normExtent = (extentOffset - 1).clamp(0, 1 << 30);
    final int minOffset = normBase < normExtent ? normBase : normExtent;
    final int maxOffset = normBase < normExtent ? normExtent : normBase;

    if (minOffset != maxOffset) {
      toolbarRangeSelection = TextSelection(
        baseOffset: minOffset,
        extentOffset: maxOffset,
      );
      toolbarRangeBlockIndex = blockIndex;
      checkLinkTooltip(blockIndex, minOffset, maxOffset);
    } else if (hasFocus) {
      // Only clear remembered selection when a collapsed cursor event arrives
      // while the block still HAS focus. If focus was lost (blur), preserve range!
      toolbarRangeSelection = null;
      toolbarRangeBlockIndex = null;
      checkLinkTooltip(blockIndex, minOffset);
    } else {
      hideLinkTooltip();
    }

    // Clear pending format when cursor moves significantly and we are not just typing
    bool movedManually = !isTyping &&
        (minOffset != pendingFormatOffset ||
            blockIndex != pendingFormatBlockIndex);

    if (movedManually) {
      pendingInline = null;
      pendingFormatOffset = null;
      pendingFormatBlockIndex = null;
    }

    // Probe format at the start of the actual characters in selection
    int probeOffset = minOffset;

    final formats = getMergedFormats(blockIndex, probeOffset);
    widget.editorSettings.onChangeSelection?.call(formats);
    widget.onFormatStateChanged?.call(blockIndex, formats);

    // Notify listeners so the public controller updates the toolbar
    docController.refresh();
  }

  /// Sets pending inline style for the next insertion (caret, no selection).
  @override
  void setPendingInlineFormat(PendingInlineFormat format) {
    setState(() {
      pendingInline = format;
      pendingFormatCellRow = null;
      pendingFormatCellCol = null;

      final id = document.blocks[focusedBlockIndex].id;
      final rawOffset = blockKeys[id]?.currentState?.cursorOffset ?? 1;
      pendingFormatOffset = (rawOffset - 1).clamp(0, 1 << 30);
      pendingFormatBlockIndex = focusedBlockIndex;
    });
  }

  /// Full toolbar format map at the current caret (merges document + pending).
  @override
  Map<SmartButtonType, dynamic> getToolbarFormatState() {
    if (focusedBlockIndex < 0 ||
        focusedBlockIndex >= document.blocks.length) {
      return {};
    }
    TextSelection? sel;
    final id = document.blocks[focusedBlockIndex].id;
    final raw = blockKeys[id]?.currentState?.selection;
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

  /// Returns the cursor offset in the focused block
  @override
  int? get cursorOffset {
    if (focusedBlockIndex >= document.blocks.length) return null;
    final raw = blockKeys[document.blocks[focusedBlockIndex].id]
        ?.currentState
        ?.cursorOffset;
    if (raw == null) return null;
    return (raw - 1).clamp(0, 1 << 30);
  }

  /// Returns the live selection in the focused block (may be collapsed after unfocus).
  @override
  TextSelection? get selection {
    if (focusedBlockIndex >= document.blocks.length) return null;
    final raw = blockKeys[document.blocks[focusedBlockIndex].id]
        ?.currentState
        ?.selection;
    if (raw == null || !raw.isValid) return null;
    return BaseEditorState.normalizeTextSelection(raw);
  }

  /// Selection used by the toolbar: live range, else last range before focus was lost.
  @override
  TextSelection? get selectionForToolbar {
    if (focusedBlockIndex < 0 ||
        focusedBlockIndex >= document.blocks.length) {
      return null;
    }
    TextSelection? live;
    final raw = blockKeys[document.blocks[focusedBlockIndex].id]
        ?.currentState
        ?.selection;
    if (raw != null && raw.isValid) {
      live = BaseEditorState.normalizeTextSelection(raw);
    }

    if (live != null && live.isValid && !live.isCollapsed) {
      return live;
    }
    if (toolbarRangeSelection != null &&
        toolbarRangeBlockIndex == focusedBlockIndex) {
      final len = document.blocks[focusedBlockIndex].plainText.length;
      final r = toolbarRangeSelection!;
      if (r.isValid && r.start >= 0 && r.end <= len && r.start < r.end) {
        return r;
      }
    }
    return live;
  }

  /// Sets cursor position in the specified block using 0-based document offset.
  @override
  void setCursorPosition(int blockIndex, int docOffset, {int? row, int? col}) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;

    toolbarRangeSelection = null;
    toolbarRangeBlockIndex = null;
    pendingInline = null;

    focusedBlockIndex = blockIndex;
    final id = document.blocks[blockIndex].id;
    focusNodes[id]?.requestFocus();
    final blockState = blockKeys[id]?.currentState;
    blockState?.setCursorPosition(docOffset + 1);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      blockState?.setCursorPosition(docOffset + 1);
      final formats = getMergedFormats(blockIndex, docOffset);
      formats[SmartButtonType.insertLink] = false;
      widget.editorSettings.onChangeSelection?.call(formats);
      widget.onFormatStateChanged?.call(blockIndex, formats);
      checkLinkTooltip(blockIndex, docOffset);
    });

    docController.refresh();
  }

  /// Sets text selection in the specified block using 0-based document offsets.
  @override
  void setSelection(int blockIndex, int startOffset, int endOffset,
      {int? row, int? col}) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;

    final normStart = startOffset.clamp(0, 1 << 30);
    final normEnd = endOffset.clamp(0, 1 << 30);
    final minOffset = normStart < normEnd ? normStart : normEnd;
    final maxOffset = normStart < normEnd ? normEnd : normStart;

    toolbarRangeSelection =
        TextSelection(baseOffset: minOffset, extentOffset: maxOffset);
    toolbarRangeBlockIndex = blockIndex;
    pendingInline = null;

    focusedBlockIndex = blockIndex;
    final id = document.blocks[blockIndex].id;
    focusNodes[id]?.requestFocus();
    final blockState = blockKeys[id]?.currentState;
    blockState?.setSelection(normStart + 1, normEnd + 1);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      blockState?.setSelection(normStart + 1, normEnd + 1);
      final formats = getMergedFormats(blockIndex, minOffset);
      widget.editorSettings.onChangeSelection?.call(formats);
      widget.onFormatStateChanged?.call(blockIndex, formats);
      checkLinkTooltip(blockIndex, minOffset, maxOffset);
    });

    docController.refresh();
  }

  /// Merges pending format into the state at the given offset
  @override
  Map<SmartButtonType, dynamic> getMergedFormats(int blockIndex, int offset) {
    final block = document.blocks[blockIndex];
    final formats = docController.getFormatAt(blockIndex, offset);

    // Include block-level alignment
    formats[SmartButtonType.blockType] = block.blockType;
    formats[SmartButtonType.alignLeft] =
        block.alignment == SmartTextAlign.left;
    formats[SmartButtonType.alignCenter] =
        block.alignment == SmartTextAlign.center;
    formats[SmartButtonType.alignRight] =
        block.alignment == SmartTextAlign.right;
    formats[SmartButtonType.alignJustify] =
        block.alignment == SmartTextAlign.justify;

    if (pendingInline != null) {
      pendingInline!.mergeIntoToolbarMap(formats);
    }

    return formats;
  }

  /// Strut hint when pending explicitly sets font size (including cleared → default).
  @override
  double? pendingStrutFontSize(int index) {
    if (index != focusedBlockIndex || pendingInline == null) return null;
    if (!pendingInline!.inheritFontSize) {
      return pendingInline!.fontSize ?? widget.editorSettings.defaultFontSize;
    }
    return null;
  }
}

/// Backwards-compatibility alias for [SelectionEditorMixin].
typedef SelectionEditorState = SelectionEditorMixin;
