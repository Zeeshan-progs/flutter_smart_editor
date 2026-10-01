import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../core/document/document.dart';
import '../../toolbar/inputs/link_dialog.dart';
import 'base_editor_state.dart';

/// Mixin managing hyperlink floating tooltips, inspection, editing, and dialog transitions.
mixin LinkEditorMixin on BaseEditorState {
  OverlayEntry? linkTooltipOverlay;
  int? tooltipBlockIndex;
  int? tooltipCellRow;
  int? tooltipCellCol;
  int? tooltipSpanStart;
  int? tooltipSpanEnd;

  @override
  void checkLinkTooltip(int blockIndex, int offset) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) {
      hideLinkTooltip();
      return;
    }
    final block = document.blocks[blockIndex];
    if (block.spans.isEmpty) {
      hideLinkTooltip();
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
        showLinkTooltip(
          blockIndex: blockIndex,
          spanStart: spanStart,
          spanEnd: spanEnd,
          displayText: span.text,
          url: span.linkUrl!,
        );
        return;
      }
    }
    hideLinkTooltip();
  }

  @override
  void checkCellLinkTooltip(int blockIndex, int row, int col, int offset) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) {
      hideLinkTooltip();
      return;
    }
    final block = document.blocks[blockIndex];
    if (block is! TableNode) {
      hideLinkTooltip();
      return;
    }

    final cell = block.getCell(row, col);
    if (cell.spans.isEmpty) {
      hideLinkTooltip();
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
        showLinkTooltip(
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
    hideLinkTooltip();
  }

  @protected
  void showLinkTooltip({
    required int blockIndex,
    int? row,
    int? col,
    required int spanStart,
    required int spanEnd,
    required String displayText,
    required String url,
  }) {
    if (linkTooltipOverlay != null &&
        tooltipBlockIndex == blockIndex &&
        tooltipCellRow == row &&
        tooltipCellCol == col &&
        tooltipSpanStart == spanStart &&
        tooltipSpanEnd == spanEnd) {
      return;
    }

    hideLinkTooltip();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final overlayState = Overlay.maybeOf(context, rootOverlay: true);
      if (overlayState == null) return;

      RenderEditable? renderEditable;
      RenderBox? fallbackBox;

      if (row != null && col != null) {
        final tableId = document.blocks[blockIndex].id;
        final cellState = tableBlockKeys[tableId]
            ?.currentState
            ?.getCellKey(row, col)
            ?.currentState;
        renderEditable = cellState?.renderEditable;
        fallbackBox = cellState?.context.findRenderObject() as RenderBox?;
      } else {
        final blockId = document.blocks[blockIndex].id;
        final blockState = blockKeys[blockId]?.currentState;
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

      tooltipBlockIndex = blockIndex;
      tooltipCellRow = row;
      tooltipCellCol = col;
      tooltipSpanStart = spanStart;
      tooltipSpanEnd = spanEnd;

      linkTooltipOverlay = OverlayEntry(
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
                      hideLinkTooltip();
                      widget.editorSettings.onLinkTapped?.call(url);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    tooltip: 'Edit link',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      hideLinkTooltip();
                      showLinkDialog(
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
                      hideLinkTooltip();
                      if (row != null && col != null) {
                        docController.applyCellLink(
                            blockIndex, row, col, spanStart, spanEnd, null);
                      } else {
                        docController.applyLink(
                            blockIndex, spanStart, spanEnd, null);
                      }
                      widget.onFormatStateChanged?.call(
                          blockIndex, getMergedFormats(blockIndex, spanStart));
                      rebuild();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      overlayState.insert(linkTooltipOverlay!);
    });
  }

  @override
  void hideLinkTooltip() {
    linkTooltipOverlay?.remove();
    linkTooltipOverlay = null;
    tooltipBlockIndex = null;
    tooltipCellRow = null;
    tooltipCellCol = null;
    tooltipSpanStart = null;
    tooltipSpanEnd = null;
  }

  @protected
  void showLinkDialog({
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
            docController.applyCellLink(
                blockIndex, row, col, spanStart, spanEnd, null);
          } else {
            docController.applyLink(blockIndex, spanStart, spanEnd, null);
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
              docController.setCellLink(
                blockIndex: blockIndex,
                row: row,
                col: col,
                start: spanStart,
                end: spanEnd,
                text: newText,
                url: newUrl,
              );
            } else {
              docController.setLink(
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
}

/// Backwards-compatibility alias for [LinkEditorMixin].
typedef LinkEditorState = LinkEditorMixin;
