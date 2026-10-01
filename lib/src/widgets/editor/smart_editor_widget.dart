import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../smart_editor_controller.dart';
import '../../core/document/document.dart';
import '../../core/document/document_controller.dart';
import '../../models/editor_settings.dart';
import '../../models/enums.dart';
import '../../models/search/search_index.dart';
import '../blocks/block_widget.dart';
import '../blocks/table_block_widget.dart';
import '../blocks/image_block_widget.dart';
import 'states/base_editor_state.dart';
import 'states/block_editor_state.dart';
import 'states/text_editor_state.dart';
import 'states/selection_editor_state.dart';
import 'states/link_editor_state.dart';
import 'states/table_editor_state.dart';
import 'states/image_editor_state.dart';
import 'states/search_editor_state.dart';

export 'states/base_editor_state.dart';
export 'states/block_editor_state.dart';
export 'states/text_editor_state.dart';
export 'states/selection_editor_state.dart';
export 'states/link_editor_state.dart';
export 'states/table_editor_state.dart';
export 'states/image_editor_state.dart';
export 'states/search_editor_state.dart';

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

/// The unified widget state combining editor lifecycle, block management,
/// text editing, formatting/selection, hyperlinks, tables, images, search, and layout rendering.
///
/// Composed of clean, independent mixins on [BaseEditorState]:
/// - [BaseEditorState]: Editor lifecycle, focus nodes, document bindings, and core rebuilds.
/// - [BlockEditorMixin]: Block-level mutations, indentation, list numbering, and keyboard events.
/// - [TextEditorMixin]: Text input, diffing, and clipboard paste operations.
/// - [SelectionEditorMixin]: Cursor position, selections, pending inline formats, and format probes.
/// - [LinkEditorMixin]: Hyperlink floating tooltips, inspection, editing, and dialog transitions.
/// - [TableEditorMixin]: Table cell selection, cell focus, cell editing, and cell-level formatting.
/// - [ImageEditorMixin]: Image block selection, alignment, resizing, and removal operations.
/// - [SearchEditorMixin]: Find & Replace live search match scrolling, highlighting focus, and state updates.
class SmartEditorWidgetState extends BaseEditorState
    with
        BlockEditorMixin,
        TextEditorMixin,
        SelectionEditorMixin,
        LinkEditorMixin,
        TableEditorMixin,
        ImageEditorMixin,
        SearchEditorMixin {
  /// Called when a block is reordered
  void _onReorder(int oldUnitIndex, int newUnitIndex) {
    final units = _getEditorUnits();
    if (oldUnitIndex < 0 || oldUnitIndex >= units.length) return;

    // Capture the unit mapping before modifying indices
    final unitToMove = units[oldUnitIndex];
    int targetFlatIndex;

    if (newUnitIndex >= units.length) {
      targetFlatIndex = document.blocks.length;
    } else {
      targetFlatIndex = units[newUnitIndex].startIndex;
    }

    setState(() {
      // Track the ID of the focused block to restore focus index after move
      String? focusedId;
      if (focusedBlockIndex >= 0 &&
          focusedBlockIndex < document.blocks.length) {
        focusedId = document.blocks[focusedBlockIndex].id;
      }

      String? selectedImageId;
      if (selectedImageBlockIndex != null &&
          selectedImageBlockIndex! >= 0 &&
          selectedImageBlockIndex! < document.blocks.length) {
        selectedImageId = document.blocks[selectedImageBlockIndex!].id;
      }

      docController.moveBlockRange(
          unitToMove.startIndex, unitToMove.blocks.length, targetFlatIndex);
      syncFocusNodes();

      // Restore focused block index
      if (focusedId != null) {
        focusedBlockIndex =
            document.blocks.indexWhere((b) => b.id == focusedId);
      }

      // Restore selected image block index
      if (selectedImageId != null) {
        final newIdx =
            document.blocks.indexWhere((b) => b.id == selectedImageId);
        selectedImageBlockIndex = newIdx != -1 ? newIdx : null;
      }
    });

    notifyContentChanged();
  }

  List<EditorUnit> _getEditorUnits() {
    final units = <EditorUnit>[];
    if (document.blocks.isEmpty) return units;

    for (int i = 0; i < document.blocks.length; i++) {
      final block = document.blocks[i];
      if (block is ListItemNode) {
        // Start of a potential group
        final groupBlocks = <BlockNode>[block];
        int j = i + 1;
        while (j < document.blocks.length) {
          final next = document.blocks[j];
          if (next is ListItemNode && next.listType == block.listType) {
            groupBlocks.add(next);
            j++;
          } else {
            break;
          }
        }
        units.add(EditorUnit(blocks: groupBlocks, startIndex: i));
        i = j - 1; // Skip the items we grouped
      } else {
        units.add(EditorUnit(blocks: [block], startIndex: i));
      }
    }
    return units;
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
      blockMatches =
          searchState.matches.where((m) => m.blockIndex == index).toList();
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
      tableBlockKeys.putIfAbsent(
        block.id,
        () => GlobalKey<TableBlockWidgetState>(debugLabel: 'table_${block.id}'),
      );
      return TableBlockWidget(
        key: tableBlockKeys[block.id],
        table: block,
        blockIndex: index,
        editorSettings: widget.editorSettings,
        docController: docController,
        onCellFocusChanged: onCellFocusChanged,
        onCellSelectionChanged: onCellSelectionChanged,
        onCellTextChanged: onCellTextChanged,
        onCellPaste: onCellPaste,
        isDarkMode: isDark,
        readOnly:
            widget.editorSettings.disabled || widget.editorSettings.readOnly,
        showDragHandle: showDragHandle,
        dragIndex: dragIndex,
        searchMatches: blockMatches,
        activeSearchMatch: activeTableMatch,
      );
    }

    // Image blocks use ImageBlockWidget
    if (block is ImageNode) {
      return ImageBlockWidget(
        key: ValueKey('img_${block.id}'),
        imageNode: block,
        blockIndex: index,
        editorSettings: widget.editorSettings,
        isSelected: isImageSelected(index),
        isDarkMode: isDark,
        readOnly:
            widget.editorSettings.disabled || widget.editorSettings.readOnly,
        showDragHandle: showDragHandle,
        dragIndex: dragIndex,
        onTap: () => onImageTap(index),
        onRemove: () => onImageRemove(index),
        onHideResizeHandles: deselectImage,
        onAlignmentChanged: (alignment) => onImageAlignment(index, alignment),
        onResize: (width, height) =>
            onImageResize(index, width: width, height: height),
        onCrop: (cropped) => onImageCrop(index, cropped),
      );
    }

    return BlockWidget(
      key: key,
      block: block,
      blockIndex: index,
      dragIndex: dragIndex,
      focusNode: focusNodes[block.id]!,
      editorSettings: widget.editorSettings,
      pendingFontSize: pendingStrutFontSize(index),
      onTextChanged: onTextChanged,
      onEnter: onEnter,
      onBackspaceAtStart: onBackspaceAtStart,
      onDeleteAtEnd: onDeleteAtEnd,
      onFocusChanged: onFocusChanged,
      onSelectionChanged: onSelectionChanged,
      onPaste: onPaste,
      onIncreaseIndent: () => onIncreaseIndent(index),
      onDecreaseIndent: () => onDecreaseIndent(index),
      onHrTap: onHrTap,
      orderedCount: computeOrderedCount(index),
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

  @override
  Widget build(BuildContext context) {
    if (document.blocks.isEmpty) {
      return const SizedBox.shrink();
    }

    final units = _getEditorUnits();
    final isDark = isDarkMode();
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
          hideLinkTooltip();
        }
        return false;
      },
      child: Container(
        decoration: widget.editorSettings.editorDecoration ??
            BoxDecoration(color: bgColor),
        child: ReorderableListView.builder(
          scrollController: widget.editorSettings.scrollController ??
              (widget.editorSettings.autoAdjustHeight &&
                      widget.editorSettings.maxLines == null
                  ? null
                  : internalScrollController),
          primary: false,
          shrinkWrap: widget.editorSettings.autoAdjustHeight,
          physics: widget.editorSettings.scrollPhysics ??
              (widget.editorSettings.autoAdjustHeight
                  ? (widget.editorSettings.maxLines != null
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics())
                  : null),
          padding: adaptedPadding,
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
                blockKeys[block.id] ?? ValueKey(unit.id),
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
                  blockKeys[block.id] ?? ValueKey('${block.id}_inner'),
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
}

class EditorUnit {
  final List<BlockNode> blocks;
  final int startIndex;
  final String id;

  EditorUnit({required this.blocks, required this.startIndex})
      : id = blocks.first.id;
}
