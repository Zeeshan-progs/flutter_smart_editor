import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../../smart_editor_controller.dart';
import '../../core/document/document.dart';
import '../../core/document/document_controller.dart';
import '../../core/infra/html_serializer.dart';
import '../../models/editor_settings.dart';
import '../../models/enums.dart';
import '../../models/pending_inline_format.dart';
import '../../models/search/search_index.dart';
import '../blocks/block_widget.dart';
import '../blocks/table_block_widget.dart';
import '../toolbar/inputs/link_dialog.dart';
import 'package:super_clipboard/super_clipboard.dart';
import '../../core/infra/html_parser.dart';
import 'keyboard_done_overlay.dart';

/// The main editor widget that renders the document as a list of blocks.
///
/// It composes [BlockWidget]s in a scrollable column, manages focus
/// transitions between blocks, and coordinates with [DocumentController]
/// for text operations.
class SmartEditorWidget extends StatefulWidget {
  const SmartEditorWidget({
    super.key,
    required this.documentController,
    this.controller,
    this.editorSettings = const SmartEditorSettings(),
    this.onFormatStateChanged,
  });

  final DocumentController documentController;
  final SmartEditorController? controller;
  final SmartEditorSettings editorSettings;

  /// Internal callback to update toolbar state when formatting changes
  final void Function(int blockIndex, Map<SmartButtonType, dynamic> formats)?
      onFormatStateChanged;

  @override
  State<SmartEditorWidget> createState() => SmartEditorWidgetState();
}

class SmartEditorWidgetState extends State<SmartEditorWidget> {
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, GlobalKey<BlockWidgetState>> _blockKeys = {};
  final Map<String, GlobalKey<TableBlockWidgetState>> _tableBlockKeys = {};
  final SmartHtmlSerializer _serializer = SmartHtmlSerializer();
  int _focusedBlockIndex = 0;
  bool _initialized = false;
  bool _isTyping = false;

  /// Table cell focus tracking.
  int _focusedCellRow = -1;
  int _focusedCellCol = -1;

  /// Pending inline style at caret (no selection). Applied to the next insert.
  PendingInlineFormat? _pendingInline;
  int? _pendingFormatOffset;
  int? _pendingFormatBlockIndex;
  int? _pendingFormatCellRow;
  int? _pendingFormatCellCol;

  /// Last non-collapsed range, retained when the field loses focus (e.g. toolbar tap).
  TextSelection? _toolbarRangeSelection;
  int? _toolbarRangeBlockIndex;

  /// Floating overlay tooltip for hyperlinks.
  OverlayEntry? _linkTooltipOverlay;
  int? _tooltipBlockIndex;
  int? _tooltipCellRow;
  int? _tooltipCellCol;
  int? _tooltipSpanStart;
  int? _tooltipSpanEnd;

  DocumentController get _docController => widget.documentController;
  Document get _document => _docController.document;

  @override
  void didUpdateWidget(SmartEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.documentController != oldWidget.documentController) {
      oldWidget.documentController.removeListener(_onDocChanged);
      widget.documentController.addListener(_onDocChanged);
    }
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.searchStateNotifier
          .removeListener(_onSearchStateChanged);
      widget.controller?.searchStateNotifier.addListener(_onSearchStateChanged);
      widget.controller?.attachEditor(this);
    }
    _syncFocusNodes();
  }

  @override
  void initState() {
    super.initState();
    _syncFocusNodes();

    _docController.addListener(_onDocChanged);
    widget.controller?.searchStateNotifier.addListener(_onSearchStateChanged);
    widget.controller?.attachEditor(this);

    // Connect message callback
    _docController.onMessage = (msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
      );
    };

    // Fire onInit after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialized) {
        _initialized = true;
        widget.editorSettings.onInit?.call();
        if (widget.editorSettings.autofocus && _document.blocks.isNotEmpty) {
          _focusNodes[_document.blocks[0].id]?.requestFocus();
        }
      }
    });
  }

  @override
  void dispose() {
    widget.controller?.searchStateNotifier
        .removeListener(_onSearchStateChanged);
    _hideLinkTooltip();
    _docController.removeListener(_onDocChanged);
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _onSearchStateChanged() {
    _safeSetState(() {});
  }

  /// Scrolls to make the block or table containing [match] visible.
  void scrollToMatch(SearchMatch match) {
    if (!mounted) return;
    if (match.blockIndex < 0 || match.blockIndex >= _document.blocks.length) {
      return;
    }
    final block = _document.blocks[match.blockIndex];

    BuildContext? targetContext;
    if (match.isTableCell && match.row != null && match.col != null) {
      final tableState = _tableBlockKeys[block.id]?.currentState;
      targetContext =
          tableState?.getCellKey(match.row!, match.col!)?.currentContext ??
              _tableBlockKeys[block.id]?.currentContext;
    } else {
      targetContext = _blockKeys[block.id]?.currentContext;
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
    if (match.blockIndex < 0 || match.blockIndex >= _document.blocks.length) {
      return;
    }
    final block = _document.blocks[match.blockIndex];

    // +1 offset accounts for the ZWSP character at index 0 of BlockWidget
    final start = match.start + 1;
    final end = match.end + 1;

    if (match.isTableCell && match.row != null && match.col != null) {
      final tableState = _tableBlockKeys[block.id]?.currentState;
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
        _focusNodes[block.id]?.requestFocus();
      }
      _blockKeys[block.id]?.currentState?.setSelection(start, end);
    }
  }

  void _onDocChanged() {
    if (!mounted) return;
    _hideLinkTooltip();
    rebuild();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
    } else {
      setState(fn);
    }
  }

  /// Synchronizes the focus nodes and block keys with the document blocks
  void _syncFocusNodes() {
    final currentIds = _document.blocks.map((b) => b.id).toSet();

    // Add new ones
    for (final block in _document.blocks) {
      if (!_focusNodes.containsKey(block.id)) {
        _focusNodes[block.id] = FocusNode();
        _blockKeys[block.id] =
            GlobalKey<BlockWidgetState>(debugLabel: block.id);
      }
    }

    // Remove old ones
    final toRemove =
        _focusNodes.keys.where((id) => !currentIds.contains(id)).toList();
    for (final id in toRemove) {
      _focusNodes.remove(id)?.dispose();
      _blockKeys.remove(id);
    }
  }

  /// Notifies the content change callback
  void _notifyContentChanged() {
    final html = _serializer.serialize(_document);
    widget.editorSettings.onChangeContent?.call(html);
  }

  /// Called when text in a block changes.
  /// Uses smart diffing to preserve inline formatting.
  void _onTextChanged(int blockIndex, String newText) {
    if (blockIndex < 0 || blockIndex >= _document.blocks.length) return;

    _isTyping = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _isTyping = false;
    });

    final oldText = _document.blocks[blockIndex].plainText;

    final insertAt = _insertOffsetInOldText(oldText, newText);
    TextFormatSpan? pendingSpan;
    if (_pendingInline != null) {
      pendingSpan = _pendingInline!.resolveForInsert(
        _document.blocks[blockIndex],
        insertAt,
      );
    }

    _docController.updateBlockText(
      blockIndex,
      oldText,
      newText,
      pendingFormat: pendingSpan,
    );

    // Update pending format offset to the new cursor position after typing
    // This allows the format to "stick" for the next character.
    if (_pendingInline != null) {
      _pendingFormatOffset = insertAt + (newText.length - oldText.length);
      _pendingFormatBlockIndex = blockIndex;
    }

    if (_toolbarRangeBlockIndex == blockIndex) {
      _toolbarRangeSelection = null;
      _toolbarRangeBlockIndex = null;
    }

    setState(() {});
    _notifyContentChanged();
  }

  /// Start offset of inserted text in [oldText] (matches [DocumentController.updateBlockText]).
  static int _insertOffsetInOldText(String oldText, String newText) {
    if (oldText == newText) return 0;
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
    return commonPrefix;
  }

  /// Called when Enter is pressed in a block
  void _onEnter(int blockIndex, int offset) {
    widget.editorSettings.onEnter?.call();

    final block = _document.blocks[blockIndex];

    // Special Enter behavior for list items
    if (block is ListItemNode) {
      final isEmpty = block.plainText.trim().isEmpty;
      if (isEmpty && block.depth > 0) {
        // De-indent
        _docController.decreaseIndent(blockIndex);
        setState(() {});
        _notifyContentChanged();
        return;
      } else if (isEmpty && block.depth == 0) {
        // Exit list → become paragraph
        _docController.toggleList(blockIndex, block.listType);
        setState(() {
          _syncFocusNodes();
        });
        _notifyContentChanged();
        return;
      } else {
        // Insert new list item of same type and depth
        _saveState();
        final newItem = ListItemNode(
          listType: block.listType,
          depth: block.depth,
          bulletStyle: block.bulletStyle,
        );
        _docController.document.blocks.insert(blockIndex + 1, newItem);
        _docController.document.normalize();
        setState(() {
          _syncFocusNodes();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (blockIndex + 1 < _document.blocks.length) {
            final id = _document.blocks[blockIndex + 1].id;
            _focusNodes[id]?.requestFocus();
            _blockKeys[id]?.currentState?.setCursorPosition(0);
          }
        });
        _notifyContentChanged();
        return;
      }
    }

    final newBlockIndex = _docController.splitBlock(
      blockIndex,
      offset,
      pendingFormat: _pendingInline?.resolveForInsert(
          _document.blocks[blockIndex], offset),
    );

    _pendingInline = null;

    setState(() {
      _syncFocusNodes();
    });

    // Focus the new block after rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (newBlockIndex < _document.blocks.length) {
        final id = _document.blocks[newBlockIndex].id;
        _focusNodes[id]?.requestFocus();
        _blockKeys[id]?.currentState?.setCursorPosition(0);
      }
    });

    _notifyContentChanged();
  }

  void _saveState() {
    // Trigger undo state save via a no-op update
    _docController.undoRedoManager.pushState(_docController.document);
  }

  void _onIncreaseIndent(int blockIndex) {
    _docController.increaseIndent(
      blockIndex,
      maxDepth: widget.editorSettings.maxListDepth,
    );
    setState(() {});
    _notifyContentChanged();
  }

  void _onDecreaseIndent(int blockIndex) {
    final id = _document.blocks[blockIndex].id;
    final cursorOffset = _blockKeys[id]?.currentState?.cursorOffset ?? 0;

    _docController.decreaseIndent(blockIndex);

    setState(() {
      _syncFocusNodes();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // After type change (like from list to paragraph),
      // the ID is preserved so we can re-request focus.
      if (blockIndex < _document.blocks.length) {
        _focusNodes[id]?.requestFocus();
        _blockKeys[id]?.currentState?.setCursorPosition(cursorOffset);
      }
    });

    _notifyContentChanged();
  }

  void _onHrTap(int blockIndex) {
    // Move focus to the block after the HR (insert paragraph if none)
    final nextIndex = blockIndex + 1;
    if (nextIndex < _document.blocks.length) {
      final id = _document.blocks[nextIndex].id;
      _focusNodes[id]?.requestFocus();
      _focusedBlockIndex = nextIndex;
    }
  }

  /// Computes the 1-based ordered counter for a list item at [blockIndex].
  /// Resets to 1 for each contiguous group and each depth.
  int _computeOrderedCount(int blockIndex) {
    final blocks = _document.blocks;
    final current = blocks[blockIndex];
    if (current is! ListItemNode || current.listType != SmartListType.ordered) {
      return 1;
    }
    final depth = current.depth;
    int count = 1;
    for (int i = blockIndex - 1; i >= 0; i--) {
      final prev = blocks[i];
      if (prev is! ListItemNode) break; // contiguous group ended
      if (prev.depth == depth && prev.listType == SmartListType.ordered) {
        count++;
      } else if (prev.depth < depth) {
        break; // parent level — stop
      }
      // deeper level items are skipped (they don't affect this level count)
    }
    return count;
  }

  /// Called when Backspace is pressed at the start of a block
  void _onBackspaceAtStart(int blockIndex) {
    if (blockIndex <= 0) return;

    final currentBlock = _document.blocks[blockIndex];
    final prevBlock = _document.blocks[blockIndex - 1];

    // Smart Backspace for Lists
    if (currentBlock is ListItemNode) {
      // 1. If empty, merge/delete immediately regardless of depth
      if (currentBlock.textLength == 0) {
        _docController.mergeWithPrevious(blockIndex);
        setState(() {
          _syncFocusNodes();
        });
        _focusTarget(blockIndex - 1);
        return;
      }

      // 2. If indented, un-indent first
      if (currentBlock.depth > 0) {
        _onDecreaseIndent(blockIndex);
        return;
      }

      // 3. If previous is a list item of the same type, merge text immediately
      if (prevBlock is ListItemNode &&
          prevBlock.listType == currentBlock.listType) {
        final cursorOffset = _docController.mergeWithPrevious(blockIndex);
        setState(() {
          _syncFocusNodes();
        });
        _focusTarget(blockIndex - 1, offset: cursorOffset);
        return;
      }

      // 4. Otherwise, convert to paragraph (remove bullet)
      _docController.changeBlockType(blockIndex, BlockType.paragraph);
      rebuild();
      return;
    }

    // Regular merge for paragraphs or already-converted lists
    final cursorOffset = _docController.mergeWithPrevious(blockIndex);
    final targetIndex = blockIndex - 1;

    _pendingInline = null;

    setState(() {
      _syncFocusNodes();
    });

    _focusTarget(targetIndex, offset: cursorOffset);
    _notifyContentChanged();
  }

  /// Helper to focus a specific block with optional offset
  void _focusTarget(int targetIndex, {int offset = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (targetIndex >= 0 && targetIndex < _document.blocks.length) {
        final id = _document.blocks[targetIndex].id;
        _focusNodes[id]?.requestFocus();
        _blockKeys[id]?.currentState?.setCursorPosition(offset);
      }
    });
  }

  /// Called when Delete is pressed at the end of a block
  /// Called when Delete is pressed at the end of a block
  void _onDeleteAtEnd(int blockIndex) {
    if (blockIndex >= _document.blocks.length - 1) return;

    final nextBlock = _document.blocks[blockIndex + 1];

    // Smart Delete for Lists at the start of the NEXT block
    if (nextBlock is ListItemNode) {
      if (nextBlock.depth > 0) {
        _onDecreaseIndent(blockIndex + 1);
        return;
      } else {
        _docController.changeBlockType(blockIndex + 1, BlockType.paragraph);
        rebuild();
        return;
      }
    }

    final cursorOffset = _document.blocks[blockIndex].textLength;
    _docController.mergeWithPrevious(blockIndex + 1);

    setState(() {
      _syncFocusNodes();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (blockIndex < _document.blocks.length) {
        final id = _document.blocks[blockIndex].id;
        _focusNodes[id]?.requestFocus();
        _blockKeys[id]?.currentState?.setCursorPosition(cursorOffset);
      }
    });

    _notifyContentChanged();
  }

  /// Handles paste events from the BlockWidget
  void _onPaste(int blockIndex) async {
    try {
      final reader = await SystemClipboard.instance?.read();
      if (reader != null && reader.canProvide(Formats.htmlText)) {
        final html = await reader.readValue(Formats.htmlText);
        if (html != null && html.isNotEmpty) {
          final parser = SmartHtmlParser();
          final parsed = parser.parse(html);
          if (parsed.blocks.isNotEmpty) {
            _docController.insertParsedDocument(
              blockIndex,
              _blockKeys[_document.blocks[blockIndex].id]
                      ?.currentState
                      ?.cursorOffset ??
                  0,
              parsed,
            );
            rebuild();
            return;
          }
        }
      }

      // Fallback: Check if there is plain text
      if (reader != null && reader.canProvide(Formats.plainText)) {
        final text = await reader.readValue(Formats.plainText);
        if (text != null && text.isNotEmpty) {
          // If the text looks like raw HTML and processInputHtml is enabled, parse it
          final isLikelyHtml =
              RegExp(r'<[a-z][\s\S]*>', caseSensitive: false).hasMatch(text);
          if (widget.editorSettings.processInputHtml && isLikelyHtml) {
            final parser = SmartHtmlParser();
            final parsed = parser.parse(text);
            if (parsed.blocks.isNotEmpty) {
              _docController.insertParsedDocument(
                blockIndex,
                _blockKeys[_document.blocks[blockIndex].id]
                        ?.currentState
                        ?.cursorOffset ??
                    0,
                parsed,
              );
              rebuild();
              return;
            }
          }

          _docController.insertText(
            blockIndex,
            _blockKeys[_document.blocks[blockIndex].id]
                    ?.currentState
                    ?.cursorOffset ??
                0,
            text,
          );
          rebuild();
        }
      }
      widget.editorSettings.onPaste?.call();
    } catch (e) {
      debugPrint('Paste error: $e');
    }
  }

  /// Called when focus changes on a block
  void _onFocusChanged(int blockIndex, bool hasFocus) {
    if (hasFocus) {
      _focusedBlockIndex = blockIndex;
      widget.editorSettings.onFocus?.call();

      KeyboardDoneOverlay.show(context);

      // Clear pending format when changing blocks
      if (blockIndex != _pendingFormatBlockIndex) {
        _pendingInline = null;
        _pendingFormatOffset = null;
        _pendingFormatBlockIndex = null;
      }

      final cursorOffset = _blockKeys[_document.blocks[blockIndex].id]
              ?.currentState
              ?.cursorOffset ??
          0;
      final formats = _getMergedFormats(blockIndex, cursorOffset);
      widget.editorSettings.onChangeSelection?.call(formats);
      widget.onFormatStateChanged?.call(blockIndex, formats);
    } else {
      widget.editorSettings.onBlur?.call();

      // Delay hiding slightly to prevent flickering when moving between blocks
      Future.delayed(const Duration(milliseconds: 50), () {
        final anyFocused = _focusNodes.values.any((node) => node.hasFocus);
        if (!anyFocused) {
          KeyboardDoneOverlay.hide();
        }
      });
    }
  }

  void _onSelectionChanged(int blockIndex, int baseOffset, int extentOffset) {
    _focusedBlockIndex = blockIndex;
    final blockId = _document.blocks[blockIndex].id;
    final hasFocus = _focusNodes[blockId]?.hasFocus ?? false;

    // Normalize raw offsets from BlockWidget (subtract 1 for ZWSP)
    final normBase = (baseOffset - 1).clamp(0, 1 << 30);
    final normExtent = (extentOffset - 1).clamp(0, 1 << 30);
    final int minOffset = normBase < normExtent ? normBase : normExtent;
    final int maxOffset = normBase < normExtent ? normExtent : normBase;

    if (minOffset != maxOffset) {
      _toolbarRangeSelection = TextSelection(
        baseOffset: minOffset,
        extentOffset: maxOffset,
      );
      _toolbarRangeBlockIndex = blockIndex;
    } else if (hasFocus) {
      // Only clear remembered selection when a collapsed cursor event arrives
      // while the block still HAS focus. If focus was lost (blur), preserve range!
      _toolbarRangeSelection = null;
      _toolbarRangeBlockIndex = null;
    }

    _checkLinkTooltip(blockIndex, minOffset);

    // Clear pending format when cursor moves significantly and we are not just typing
    bool movedManually = !_isTyping &&
        (minOffset != _pendingFormatOffset ||
            blockIndex != _pendingFormatBlockIndex);

    if (movedManually) {
      _pendingInline = null;
      _pendingFormatOffset = null;
      _pendingFormatBlockIndex = null;
    }

    // Probe format at the start of the actual characters in selection
    int probeOffset = minOffset;

    final formats = _getMergedFormats(blockIndex, probeOffset);
    widget.editorSettings.onChangeSelection?.call(formats);
    widget.onFormatStateChanged?.call(blockIndex, formats);

    // Notify listeners so the public controller (which queries our selection) updates the toolbar
    _docController.refresh();
  }

  /// Called when a block is reordered
  void _onReorder(int oldUnitIndex, int newUnitIndex) {
    final units = _getEditorUnits();
    if (oldUnitIndex < 0 || oldUnitIndex >= units.length) return;

    // Capture the unit mapping before modifying indices
    final unitToMove = units[oldUnitIndex];
    int targetFlatIndex;

    if (newUnitIndex >= units.length) {
      targetFlatIndex = _document.blocks.length;
    } else {
      targetFlatIndex = units[newUnitIndex].startIndex;
    }

    setState(() {
      // Track the ID of the focused block to restore focus index after move
      String? focusedId;
      if (_focusedBlockIndex >= 0 &&
          _focusedBlockIndex < _document.blocks.length) {
        focusedId = _document.blocks[_focusedBlockIndex].id;
      }

      _docController.moveBlockRange(
          unitToMove.startIndex, unitToMove.blocks.length, targetFlatIndex);
      _syncFocusNodes();

      // Restore focused block index
      if (focusedId != null) {
        _focusedBlockIndex =
            _document.blocks.indexWhere((b) => b.id == focusedId);
      }
    });

    _notifyContentChanged();
  }

  List<_EditorUnit> _getEditorUnits() {
    final units = <_EditorUnit>[];
    if (_document.blocks.isEmpty) return units;

    for (int i = 0; i < _document.blocks.length; i++) {
      final block = _document.blocks[i];
      if (block is ListItemNode) {
        // Start of a potential group
        final groupBlocks = <BlockNode>[block];
        int j = i + 1;
        while (j < _document.blocks.length) {
          final next = _document.blocks[j];
          if (next is ListItemNode && next.listType == block.listType) {
            groupBlocks.add(next);
            j++;
          } else {
            break;
          }
        }
        units.add(_EditorUnit(blocks: groupBlocks, startIndex: i));
        i = j - 1; // Skip the items we grouped
      } else {
        units.add(_EditorUnit(blocks: [block], startIndex: i));
      }
    }
    return units;
  }

  /// Sets pending inline style for the next insertion (caret, no selection).
  void setPendingInlineFormat(PendingInlineFormat format) {
    setState(() {
      _pendingInline = format;
      final info = focusedTableInfo;
      if (info != null) {
        _pendingFormatBlockIndex = info.blockIndex;
        _pendingFormatCellRow = info.row;
        _pendingFormatCellCol = info.col;

        final tableId = _document.blocks[info.blockIndex].id;
        final rawOffset =
            _tableBlockKeys[tableId]?.currentState?.cursorOffset ?? 1;
        _pendingFormatOffset = (rawOffset - 1).clamp(0, 1 << 30);
      } else {
        _pendingFormatCellRow = null;
        _pendingFormatCellCol = null;

        final id = _document.blocks[_focusedBlockIndex].id;
        final rawOffset = _blockKeys[id]?.currentState?.cursorOffset ?? 1;
        _pendingFormatOffset = (rawOffset - 1).clamp(0, 1 << 30);
        _pendingFormatBlockIndex = _focusedBlockIndex;
      }
    });
  }

  /// Full toolbar format map at the current caret (merges document + pending).
  Map<SmartButtonType, dynamic> getToolbarFormatState() {
    if (_focusedBlockIndex < 0 ||
        _focusedBlockIndex >= _document.blocks.length) {
      return {};
    }
    TextSelection? sel;
    final info = focusedTableInfo;
    if (info != null) {
      final tableId = _document.blocks[info.blockIndex].id;
      final raw = _tableBlockKeys[tableId]?.currentState?.selection;
      if (raw != null && raw.isValid) {
        sel = _normalizeTextSelection(raw);
      }
    } else {
      final id = _document.blocks[_focusedBlockIndex].id;
      final raw = _blockKeys[id]?.currentState?.selection;
      if (raw != null && raw.isValid) {
        sel = _normalizeTextSelection(raw);
      }
    }

    int offset = sel?.baseOffset ?? 0;

    if (sel != null &&
        !sel.isCollapsed &&
        sel.start < _document.blocks[_focusedBlockIndex].textLength) {
      offset = sel.start + 1;
    }

    return _getMergedFormats(_focusedBlockIndex, offset);
  }

  /// Determines if dark mode is active
  bool _isDarkMode() {
    final darkMode = widget.editorSettings.darkMode;
    if (darkMode != null) return darkMode;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  /// Returns the currently focused block index
  int get focusedBlockIndex => _focusedBlockIndex;

  /// Returns the cursor offset in the focused block
  int? get cursorOffset {
    if (_focusedBlockIndex >= _document.blocks.length) return null;
    final info = focusedTableInfo;
    if (info != null) {
      final tableId = _document.blocks[info.blockIndex].id;
      final raw = _tableBlockKeys[tableId]?.currentState?.cursorOffset;
      if (raw == null) return null;
      return (raw - 1).clamp(0, 1 << 30);
    }

    final raw = _blockKeys[_document.blocks[_focusedBlockIndex].id]
        ?.currentState
        ?.cursorOffset;
    if (raw == null) return null;
    return (raw - 1).clamp(0, 1 << 30);
  }

  /// Returns the live selection in the focused block (may be collapsed after unfocus).
  TextSelection? get selection {
    if (_focusedBlockIndex >= _document.blocks.length) return null;
    final info = focusedTableInfo;
    if (info != null) {
      final tableId = _document.blocks[info.blockIndex].id;
      final raw = _tableBlockKeys[tableId]?.currentState?.selection;
      if (raw == null || !raw.isValid) return null;
      return _normalizeTextSelection(raw);
    }

    final raw = _blockKeys[_document.blocks[_focusedBlockIndex].id]
        ?.currentState
        ?.selection;
    if (raw == null || !raw.isValid) return null;
    return _normalizeTextSelection(raw);
  }

  /// Selection used by the toolbar: live range, else last range before focus was lost.
  TextSelection? get selectionForToolbar {
    if (_focusedBlockIndex < 0 ||
        _focusedBlockIndex >= _document.blocks.length) {
      return null;
    }
    TextSelection? live;
    final info = focusedTableInfo;
    if (info != null) {
      final tableId = _document.blocks[info.blockIndex].id;
      final raw = _tableBlockKeys[tableId]?.currentState?.selection;
      if (raw != null && raw.isValid) live = _normalizeTextSelection(raw);
    } else {
      final raw = _blockKeys[_document.blocks[_focusedBlockIndex].id]
          ?.currentState
          ?.selection;
      if (raw != null && raw.isValid) live = _normalizeTextSelection(raw);
    }

    if (live != null && live.isValid && !live.isCollapsed) {
      return live;
    }
    if (_toolbarRangeSelection != null &&
        _toolbarRangeBlockIndex == _focusedBlockIndex) {
      final len = info != null
          ? ((_document.blocks[_focusedBlockIndex] as TableNode)
              .getCell(info.row, info.col)
              .plainText
              .length)
          : _document.blocks[_focusedBlockIndex].plainText.length;
      final r = _toolbarRangeSelection!;
      if (r.isValid && r.start >= 0 && r.end <= len && r.start < r.end) {
        return r;
      }
    }
    return live;
  }

  static TextSelection _normalizeTextSelection(TextSelection raw) {
    // BlockWidget prepends a ZWSP to the TextField text. Normalize offsets
    // to document/model offsets by subtracting 1.
    final base = (raw.baseOffset - 1).clamp(0, 1 << 30);
    final extent = (raw.extentOffset - 1).clamp(0, 1 << 30);
    return TextSelection(baseOffset: base, extentOffset: extent);
  }

  void _checkLinkTooltip(int blockIndex, int offset) {
    if (blockIndex < 0 || blockIndex >= _document.blocks.length) {
      _hideLinkTooltip();
      return;
    }
    final block = _document.blocks[blockIndex];
    if (block.spans.isEmpty) {
      _hideLinkTooltip();
      return;
    }

    final loc = block.getSpanAt(offset);
    if (loc.spanIndex < block.spans.length) {
      final span = block.spans[loc.spanIndex];
      if (span.linkUrl != null && span.linkUrl!.isNotEmpty) {
        var spanStart = 0;
        for (var i = 0; i < loc.spanIndex; i++) {
          spanStart += block.spans[i].text.length;
        }
        final spanEnd = spanStart + span.text.length;
        _showLinkTooltip(
          blockIndex: blockIndex,
          spanStart: spanStart,
          spanEnd: spanEnd,
          displayText: span.text,
          url: span.linkUrl!,
        );
        return;
      }
    }
    _hideLinkTooltip();
  }

  void _checkCellLinkTooltip(int blockIndex, int row, int col, int offset) {
    if (blockIndex < 0 || blockIndex >= _document.blocks.length) {
      _hideLinkTooltip();
      return;
    }
    final block = _document.blocks[blockIndex];
    if (block is! TableNode) {
      _hideLinkTooltip();
      return;
    }

    final cell = block.getCell(row, col);
    if (cell.spans.isEmpty) {
      _hideLinkTooltip();
      return;
    }

    final loc = cell.getSpanAt(offset);
    if (loc.spanIndex < cell.spans.length) {
      final span = cell.spans[loc.spanIndex];
      if (span.linkUrl != null && span.linkUrl!.isNotEmpty) {
        var spanStart = 0;
        for (var i = 0; i < loc.spanIndex; i++) {
          spanStart += cell.spans[i].text.length;
        }
        final spanEnd = spanStart + span.text.length;
        _showLinkTooltip(
          blockIndex: blockIndex,
          row: row,
          col: col,
          spanStart: spanStart,
          spanEnd: spanEnd,
          displayText: span.text,
          url: span.linkUrl!,
        );
        return;
      }
    }
    _hideLinkTooltip();
  }

  void _showLinkTooltip({
    required int blockIndex,
    int? row,
    int? col,
    required int spanStart,
    required int spanEnd,
    required String displayText,
    required String url,
  }) {
    if (_linkTooltipOverlay != null &&
        _tooltipBlockIndex == blockIndex &&
        _tooltipCellRow == row &&
        _tooltipCellCol == col &&
        _tooltipSpanStart == spanStart &&
        _tooltipSpanEnd == spanEnd) {
      return;
    }

    _hideLinkTooltip();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final overlayState = Overlay.maybeOf(context, rootOverlay: true);
      if (overlayState == null) return;

      RenderEditable? renderEditable;
      RenderBox? fallbackBox;

      if (row != null && col != null) {
        final tableId = _document.blocks[blockIndex].id;
        final cellState = _tableBlockKeys[tableId]
            ?.currentState
            ?.getCellKey(row, col)
            ?.currentState;
        renderEditable = cellState?.renderEditable;
        fallbackBox = cellState?.context.findRenderObject() as RenderBox?;
      } else {
        final blockId = _document.blocks[blockIndex].id;
        final blockState = _blockKeys[blockId]?.currentState;
        renderEditable = blockState?.renderEditable;
        fallbackBox = blockState?.context.findRenderObject() as RenderBox?;
      }

      Offset targetOffset;
      if (renderEditable != null && renderEditable.hasSize) {
        final boxes = renderEditable.getBoxesForSelection(
          TextSelection(baseOffset: spanStart + 1, extentOffset: spanEnd + 1),
        );
        if (boxes.isNotEmpty) {
          final box = boxes.first;
          targetOffset = renderEditable.localToGlobal(box.toRect().bottomLeft);
        } else if (fallbackBox != null && fallbackBox.hasSize) {
          targetOffset =
              fallbackBox.localToGlobal(Offset(0, fallbackBox.size.height));
        } else {
          return;
        }
      } else if (fallbackBox != null && fallbackBox.hasSize) {
        targetOffset =
            fallbackBox.localToGlobal(Offset(0, fallbackBox.size.height));
      } else {
        return;
      }

      final screenSize = MediaQuery.of(context).size;
      final left = (targetOffset.dx)
          .clamp(16.0, (screenSize.width - 290.0).clamp(16.0, double.infinity));
      final top = targetOffset.dy + 4.0;

      final isDark = widget.editorSettings.darkMode ??
          (MediaQuery.platformBrightnessOf(context) == Brightness.dark);

      _tooltipBlockIndex = blockIndex;
      _tooltipCellRow = row;
      _tooltipCellCol = col;
      _tooltipSpanStart = spanStart;
      _tooltipSpanEnd = spanEnd;

      _linkTooltipOverlay = OverlayEntry(
        builder: (ctx) => Positioned(
          left: left,
          top: top,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(10),
            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF1E88E5),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    tooltip: 'Open link',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _hideLinkTooltip();
                      widget.editorSettings.onLinkTapped?.call(url);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    tooltip: 'Edit link',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _hideLinkTooltip();
                      _showLinkDialog(
                        blockIndex: blockIndex,
                        row: row,
                        col: col,
                        spanStart: spanStart,
                        spanEnd: spanEnd,
                        initialText: displayText,
                        initialUrl: url,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.link_off, size: 16),
                    tooltip: 'Remove link',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _hideLinkTooltip();
                      if (row != null && col != null) {
                        _docController.applyCellLink(
                            blockIndex, row, col, spanStart, spanEnd, null);
                      } else {
                        _docController.applyLink(
                            blockIndex, spanStart, spanEnd, null);
                      }
                      widget.onFormatStateChanged?.call(
                          blockIndex, _getMergedFormats(blockIndex, spanStart));
                      rebuild();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      overlayState.insert(_linkTooltipOverlay!);
    });
  }

  void _hideLinkTooltip() {
    _linkTooltipOverlay?.remove();
    _linkTooltipOverlay = null;
    _tooltipBlockIndex = null;
    _tooltipCellRow = null;
    _tooltipCellCol = null;
    _tooltipSpanStart = null;
    _tooltipSpanEnd = null;
  }

  void _showLinkDialog({
    required int blockIndex,
    int? row,
    int? col,
    required int spanStart,
    required int spanEnd,
    required String initialText,
    required String initialUrl,
  }) {
    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => LinkDialog(
        initialUrl: initialUrl,
        initialText: initialText,
        isDarkMode: widget.editorSettings.darkMode ?? false,
      ),
    ).then((result) {
      if (result != null) {
        if (result['action'] == 'remove') {
          if (row != null && col != null) {
            _docController.applyCellLink(
                blockIndex, row, col, spanStart, spanEnd, null);
          } else {
            _docController.applyLink(blockIndex, spanStart, spanEnd, null);
          }
        } else if (result['action'] == 'insert') {
          final newUrl = result['url'] as String;
          final newText = result['text'] as String;
          if (widget.controller != null) {
            widget.controller!.insertLink(
              newUrl,
              newText,
              blockIndex: blockIndex,
              selection:
                  TextSelection(baseOffset: spanStart, extentOffset: spanEnd),
            );
          } else {
            if (row != null && col != null) {
              _docController.setCellLink(
                blockIndex: blockIndex,
                row: row,
                col: col,
                start: spanStart,
                end: spanEnd,
                text: newText,
                url: newUrl,
              );
            } else {
              _docController.setLink(
                blockIndex: blockIndex,
                start: spanStart,
                end: spanEnd,
                text: newText,
                url: newUrl,
              );
            }
            rebuild();
          }
        }
      }
    });
  }

  /// Requests focus back to the currently focused block
  void requestEditorFocus() {
    if (_focusedBlockIndex >= 0 &&
        _focusedBlockIndex < _document.blocks.length) {
      final info = focusedTableInfo;
      if (info != null) {
        final tableId = _document.blocks[info.blockIndex].id;
        _tableBlockKeys[tableId]
            ?.currentState
            ?.requestFocusOnCell(info.row, info.col);
        return;
      }

      final id = _document.blocks[_focusedBlockIndex].id;
      _focusNodes[id]?.requestFocus();
    }
  }

  /// Sets cursor position in the specified block (or table cell if row/col provided)
  /// using 0-based document offset, focuses the block/cell, clears remembered range selections,
  /// and updates toolbar/format listeners.
  void setCursorPosition(int blockIndex, int docOffset, {int? row, int? col}) {
    if (blockIndex < 0 || blockIndex >= _document.blocks.length) return;

    _toolbarRangeSelection = null;
    _toolbarRangeBlockIndex = null;
    _pendingInline = null;
    _hideLinkTooltip();

    if (row != null && col != null) {
      _focusedBlockIndex = blockIndex;
      _focusedCellRow = row;
      _focusedCellCol = col;
      final block = _document.blocks[blockIndex];
      if (block is TableNode) {
        final tableId = block.id;
        final tableState = _tableBlockKeys[tableId]?.currentState;
        tableState?.requestFocusOnCell(row, col);
        final cellKey = tableState?.getCellKey(row, col);
        cellKey?.currentState?.setCursorPosition(docOffset + 1);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          cellKey?.currentState?.setCursorPosition(docOffset + 1);
          final formats =
              _docController.getCellFormatAt(blockIndex, row, col, docOffset);
          formats[SmartButtonType.insertLink] = false;
          widget.editorSettings.onChangeSelection?.call(formats);
          widget.onFormatStateChanged?.call(blockIndex, formats);
        });
      }
    } else {
      _focusedBlockIndex = blockIndex;
      final id = _document.blocks[blockIndex].id;
      _focusNodes[id]?.requestFocus();
      final blockState = _blockKeys[id]?.currentState;
      blockState?.setCursorPosition(docOffset + 1);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        blockState?.setCursorPosition(docOffset + 1);
        final formats = _getMergedFormats(blockIndex, docOffset);
        formats[SmartButtonType.insertLink] = false;
        widget.editorSettings.onChangeSelection?.call(formats);
        widget.onFormatStateChanged?.call(blockIndex, formats);
      });
    }

    _docController.refresh();
  }

  /// Forces a rebuild of all blocks
  void rebuild() {
    _safeSetState(() {
      _syncFocusNodes();
    });
    _notifyContentChanged();

    // After rebuild, report updated formatting to the toolbar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final blockIndex = _focusedBlockIndex;
      if (blockIndex < _document.blocks.length) {
        final info = focusedTableInfo;
        Map<SmartButtonType, dynamic> formats;
        if (info != null) {
          final tableId = _document.blocks[info.blockIndex].id;
          final raw = _tableBlockKeys[tableId]?.currentState?.selection;
          final sel =
              raw != null && raw.isValid ? _normalizeTextSelection(raw) : null;
          int offset = sel?.baseOffset ?? 0;
          if (sel != null && !sel.isCollapsed) {
            final cellLen = (_document.blocks[info.blockIndex] as TableNode)
                .getCell(info.row, info.col)
                .plainText
                .length;
            if (sel.start < cellLen) {
              offset = sel.start + 1;
            }
          }
          formats = _docController.getCellFormatAt(
              info.blockIndex, info.row, info.col, offset);
        } else {
          final raw = _blockKeys[_document.blocks[blockIndex].id]
              ?.currentState
              ?.selection;
          final sel =
              raw != null && raw.isValid ? _normalizeTextSelection(raw) : null;
          int offset = sel?.baseOffset ?? 0;

          if (sel != null &&
              !sel.isCollapsed &&
              sel.start < _document.blocks[blockIndex].textLength) {
            offset = sel.start + 1;
          }

          formats = _getMergedFormats(blockIndex, offset);
        }
        widget.onFormatStateChanged?.call(blockIndex, formats);
      } 
    });
  }

  /// Merges pending format into the state at the given offset
  Map<SmartButtonType, dynamic> _getMergedFormats(int blockIndex, int offset) {
    final block = _document.blocks[blockIndex];

    // When inside a table cell, use cell-level format state
    Map<SmartButtonType, dynamic> formats;
    if (block is TableNode && _focusedCellRow >= 0 && _focusedCellCol >= 0) {
      formats = _docController.getCellFormatAt(
          blockIndex, _focusedCellRow, _focusedCellCol, offset);
    } else {
      formats = _docController.getFormatAt(blockIndex, offset);
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
    }

    if (_pendingInline != null) {
      _pendingInline!.mergeIntoToolbarMap(formats);
    }

    return formats;
  }

  /// Strut hint when pending explicitly sets font size (including cleared → default).
  double? _pendingStrutFontSize(int index) {
    if (index != _focusedBlockIndex || _pendingInline == null) return null;
    if (!_pendingInline!.inheritFontSize) {
      return _pendingInline!.fontSize ?? widget.editorSettings.defaultFontSize;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_document.blocks.isEmpty) {
      return const SizedBox.shrink();
    }

    final units = _getEditorUnits();
    final isDark = _isDarkMode();
    final bgColor = widget.editorSettings.editorBackgroundColor ??
        (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final cursorColor = widget.editorSettings.cursorColor ??
        Theme.of(context).colorScheme.primary;

    final viewInsets = MediaQuery.of(context).viewInsets;
    final needsAccessoryPadding = !kIsWeb &&
        (Platform.isIOS || Platform.isAndroid) &&
        viewInsets.bottom > 0;

    final bottomPadding = needsAccessoryPadding
        ? widget.editorSettings.editorPadding.bottom + 44.0
        : widget.editorSettings.editorPadding.bottom;

    final adaptedPadding =
        widget.editorSettings.editorPadding.copyWith(bottom: bottomPadding);

    final searchController = widget.controller;
    final enableFindReplace =
        widget.editorSettings.enableFindReplace && searchController != null;

    final editorContent = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification ||
            notification is ScrollStartNotification) {
          _hideLinkTooltip();
        }
        return false;
      },
      child: Container(
        decoration: widget.editorSettings.editorDecoration ??
            BoxDecoration(color: bgColor),
        child: ReorderableListView.builder(
          padding: adaptedPadding,
          physics: widget.editorSettings.scrollPhysics,
          buildDefaultDragHandles: false,
          itemCount: units.length,
          // ignore: deprecated_member_use
          onReorder: _onReorder,
          itemBuilder: (context, unitIndex) {
            final unit = units[unitIndex];

            // If it's a single non-list block, render it directly
            if (unit.blocks.length == 1 && unit.blocks[0] is! ListItemNode) {
              final block = unit.blocks[0];
              return _buildBlock(
                block,
                unit.startIndex,
                cursorColor,
                isDark,
                _blockKeys[block.id] ?? ValueKey(unit.id),
                dragIndex: unitIndex,
              );
            }

            // If it's a list (one or more items), bundle them in a Column
            // with a single drag handle for the group.
            return Column(
              key: ValueKey(unit.id),
              mainAxisSize: MainAxisSize.min,
              children: unit.blocks.asMap().entries.map((entry) {
                final internalIndex = entry.key;
                final block = entry.value;
                final flatIndex = unit.startIndex + internalIndex;

                return _buildBlock(
                  block,
                  flatIndex,
                  cursorColor,
                  isDark,
                  _blockKeys[block.id] ?? ValueKey('${block.id}_inner'),
                  showDragHandle: internalIndex == 0,
                  dragIndex: unitIndex,
                );
              }).toList(),
            );
          },
        ),
      ),
    );

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        if (enableFindReplace) ...{
          const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () {
            searchController.showFindReplace();
          },
          const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
            searchController.showFindReplace();
          },
          const SingleActivator(LogicalKeyboardKey.keyH, meta: true): () {
            searchController.showFindReplace(showReplace: true);
          },
          const SingleActivator(LogicalKeyboardKey.keyH, control: true): () {
            searchController.showFindReplace(showReplace: true);
          },
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (searchController.searchState.isBarVisible) {
              searchController.hideFindReplace();
            }
          },
        },
      },
      child: editorContent,
    );
  }

  Widget _buildBlock(
    BlockNode block,
    int index,
    Color cursorColor,
    bool isDark,
    Key key, {
    bool showDragHandle = true,
    int? dragIndex,
  }) {
    final searchState = widget.controller?.searchState;
    final List<SearchMatch> blockMatches;
    final int activeSearchMatchIndex;
    final SearchMatch? activeTableMatch;

    if (searchState != null && searchState.matches.isNotEmpty) {
      blockMatches = searchState.matches
          .where((m) => m.blockIndex == index)
          .toList();
      final currentMatch = searchState.currentMatch;
      if (currentMatch != null && currentMatch.blockIndex == index) {
        activeSearchMatchIndex = currentMatch.matchIndex;
        activeTableMatch = currentMatch;
      } else {
        activeSearchMatchIndex = -1;
        activeTableMatch = null;
      }
    } else {
      blockMatches = const [];
      activeSearchMatchIndex = -1;
      activeTableMatch = null;
    }

    // Table blocks use a separate widget
    if (block is TableNode) {
      _tableBlockKeys.putIfAbsent(
        block.id,
        () => GlobalKey<TableBlockWidgetState>(debugLabel: 'table_${block.id}'),
      );
      return TableBlockWidget(
        key: _tableBlockKeys[block.id],
        table: block,
        blockIndex: index,
        editorSettings: widget.editorSettings,
        docController: _docController,
        onCellFocusChanged: _onCellFocusChanged,
        onCellSelectionChanged: _onCellSelectionChanged,
        onCellTextChanged: _onCellTextChanged,
        onCellPaste: _onCellPaste,
        isDarkMode: isDark,
        readOnly:
            widget.editorSettings.disabled || widget.editorSettings.readOnly,
        showDragHandle: showDragHandle,
        dragIndex: dragIndex,
        searchMatches: blockMatches,
        activeSearchMatch: activeTableMatch,
      );
    }

    return BlockWidget(
      key: key,
      block: block,
      blockIndex: index,
      dragIndex: dragIndex,
      focusNode: _focusNodes[block.id]!,
      editorSettings: widget.editorSettings,
      pendingFontSize: _pendingStrutFontSize(index),
      onTextChanged: _onTextChanged,
      onEnter: _onEnter,
      onBackspaceAtStart: _onBackspaceAtStart,
      onDeleteAtEnd: _onDeleteAtEnd,
      onFocusChanged: _onFocusChanged,
      onSelectionChanged: _onSelectionChanged,
      onPaste: _onPaste,
      onIncreaseIndent: () => _onIncreaseIndent(index),
      onDecreaseIndent: () => _onDecreaseIndent(index),
      onHrTap: _onHrTap,
      orderedCount: _computeOrderedCount(index),
      showDragHandle: showDragHandle,
      readOnly:
          widget.editorSettings.disabled || widget.editorSettings.readOnly,
      hint: index == 0 ? widget.editorSettings.hint : null,
      cursorColor: cursorColor,
      cursorWidth: widget.editorSettings.cursorWidth,
      cursorRadius: widget.editorSettings.cursorRadius,
      selectionColor: widget.editorSettings.selectionColor,
      isDarkMode: isDark,
      searchMatches: blockMatches,
      activeSearchMatchIndex: activeSearchMatchIndex,
    );
  }

  // ─── Table Cell Callbacks ─────────────────────────────────────

  /// Info about the currently focused table cell, or null if not inside a table.
  ({int blockIndex, int row, int col})? get focusedTableInfo {
    if (_focusedBlockIndex < 0 ||
        _focusedBlockIndex >= _document.blocks.length) {
      return null;
    }
    if (_document.blocks[_focusedBlockIndex] is! TableNode) return null;
    if (_focusedCellRow < 0 || _focusedCellCol < 0) return null;
    return (
      blockIndex: _focusedBlockIndex,
      row: _focusedCellRow,
      col: _focusedCellCol,
    );
  }

  void _onCellFocusChanged(int blockIndex, int row, int col, bool hasFocus) {
    if (hasFocus) {
      _focusedBlockIndex = blockIndex;
      _focusedCellRow = row;
      _focusedCellCol = col;
      widget.editorSettings.onFocus?.call();
      KeyboardDoneOverlay.show(context);

      // Report cell format state to toolbar
      final formats = _docController.getCellFormatAt(blockIndex, row, col, 0);
      widget.editorSettings.onChangeSelection?.call(formats);
      widget.onFormatStateChanged?.call(blockIndex, formats);
    } else {
      widget.editorSettings.onBlur?.call();
      Future.delayed(const Duration(milliseconds: 50), () {
        if (!mounted) return;
        final anyFocused = _focusNodes.values.any((node) => node.hasFocus);
        if (!anyFocused) {
          KeyboardDoneOverlay.hide();
        }
      });
    }
  }

  void _onCellSelectionChanged(
      int blockIndex, int row, int col, int base, int extent) {
    _focusedBlockIndex = blockIndex;
    _focusedCellRow = row;
    _focusedCellCol = col;

    final tableId = _document.blocks[blockIndex].id;
    final isCellFocused =
        _tableBlockKeys[tableId]?.currentState?.isCellFocused(row, col) ??
            false;

    final int normBase = (base - 1).clamp(0, 1 << 30);
    final int normExtent = (extent - 1).clamp(0, 1 << 30);
    final int minOffset = normBase < normExtent ? normBase : normExtent;
    final int maxOffset = normBase < normExtent ? normExtent : normBase;

    if (normBase != normExtent) {
      _toolbarRangeSelection =
          TextSelection(baseOffset: minOffset, extentOffset: maxOffset);
      _toolbarRangeBlockIndex = blockIndex;
    } else if (isCellFocused) {
      _toolbarRangeSelection = null;
      _toolbarRangeBlockIndex = null;
    }

    _checkCellLinkTooltip(blockIndex, row, col, minOffset);

    int probeOffset = minOffset;

    final formats =
        _docController.getCellFormatAt(blockIndex, row, col, probeOffset);
    widget.editorSettings.onChangeSelection?.call(formats);
    widget.onFormatStateChanged?.call(blockIndex, formats);
    _docController.refresh();
  }

  void _onCellTextChanged(int blockIndex, int row, int col, String newText) {
    if (blockIndex < 0 || blockIndex >= _document.blocks.length) return;
    final block = _document.blocks[blockIndex];
    if (block is! TableNode) return;

    _isTyping = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _isTyping = false;
    });

    final cell = block.getCell(row, col);
    final oldText = cell.plainText;

    final insertAt = _insertOffsetInOldText(oldText, newText);
    TextFormatSpan? pendingSpan;
    if (_pendingInline != null &&
        _pendingFormatBlockIndex == blockIndex &&
        _pendingFormatCellRow == row &&
        _pendingFormatCellCol == col) {
      pendingSpan = _pendingInline!.resolveForInsert(cell.block, insertAt);
    }

    _docController.updateCellText(
      blockIndex,
      row,
      col,
      oldText,
      newText,
      pendingFormat: pendingSpan,
    );
    _notifyContentChanged();
  }

  void _onCellPaste(int blockIndex, int row, int col) {
    // Delegate to the same paste flow as block paste
    _onPaste(blockIndex);
  }
}

class _EditorUnit {
  final List<BlockNode> blocks;
  final int startIndex;
  final String id;

  _EditorUnit({required this.blocks, required this.startIndex})
      : id = blocks.first.id;
}
