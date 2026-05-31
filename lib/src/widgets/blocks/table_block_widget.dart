import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/document/document.dart';
import '../../core/document/document_controller.dart';
import '../../models/editor_settings.dart';
import 'block_widget.dart';

/// Renders a [TableNode] as an editable grid of [BlockWidget]s.
///
/// Each cell's [ParagraphNode] is rendered using the same [BlockWidget]
/// used for regular document paragraphs, inheriting all formatting
/// (bold, italic, colors, fonts, alignment, etc.) for free.
///
/// Manages focus navigation between cells (Tab/Shift+Tab).
class TableBlockWidget extends StatefulWidget {
  const TableBlockWidget({
    super.key,
    required this.table,
    required this.blockIndex,
    required this.editorSettings,
    required this.docController,
    required this.onCellFocusChanged,
    required this.onCellSelectionChanged,
    required this.onCellTextChanged,
    required this.onCellPaste,
    this.isDarkMode = false,
    this.readOnly = false,
    this.showDragHandle = true,
    this.dragIndex,
  });

  final TableNode table;
  final int blockIndex;
  final SmartEditorSettings editorSettings;
  final DocumentController docController;
  final void Function(int blockIndex, int row, int col, bool hasFocus)
      onCellFocusChanged;
  final void Function(int blockIndex, int row, int col, int base, int extent)
      onCellSelectionChanged;
  final void Function(int blockIndex, int row, int col, String newText)
      onCellTextChanged;
  final void Function(int blockIndex, int row, int col) onCellPaste;
  final bool isDarkMode;
  final bool readOnly;
  final bool showDragHandle;
  final int? dragIndex;

  @override
  State<TableBlockWidget> createState() => TableBlockWidgetState();
}

class TableBlockWidgetState extends State<TableBlockWidget> {
  /// Currently focused cell coordinates (-1 = none).
  int _focusedRow = -1;
  int _focusedCol = -1;

  /// 2D map of GlobalKeys for accessing cell BlockWidget state.
  late List<List<GlobalKey<BlockWidgetState>>> _cellKeys;

  /// 2D map of FocusNodes for each cell.
  late List<List<FocusNode>> _cellFocusNodes;

  /// Public access to focused cell info.
  int get focusedRow => _focusedRow;
  int get focusedCol => _focusedCol;
  bool get hasFocusedCell => _focusedRow >= 0 && _focusedCol >= 0;

  /// Returns the selection of the currently focused cell.
  TextSelection? get selection {
    if (!hasFocusedCell) return null;
    return _cellKeys[_focusedRow][_focusedCol].currentState?.selection;
  }

  /// Returns the cursor offset of the currently focused cell.
  int get cursorOffset {
    if (!hasFocusedCell) return 0;
    return _cellKeys[_focusedRow][_focusedCol].currentState?.cursorOffset ?? 0;
  }

  /// Sets the cursor position in the currently focused cell.
  void setCursorPosition(int offset) {
    if (!hasFocusedCell) return;
    _cellKeys[_focusedRow][_focusedCol].currentState?.setCursorPosition(offset);
  }

  /// Requests focus on a specific cell.
  void requestFocusOnCell(int row, int col) {
    if (row < 0 ||
        col < 0 ||
        row >= _cellFocusNodes.length ||
        _cellFocusNodes.isEmpty ||
        col >= _cellFocusNodes[row].length) {
      return;
    }
    _cellFocusNodes[row][col].requestFocus();
  }

  @override
  void initState() {
    super.initState();
    _initCellGrid();
  }

  @override
  void didUpdateWidget(TableBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncCellGrid();
  }

  void _initCellGrid() {
    final table = widget.table;
    _cellKeys = List.generate(
      table.rowCount,
      (r) => List.generate(
        table.colCount,
        (c) => GlobalKey<BlockWidgetState>(
            debugLabel: 'cell_${widget.blockIndex}_${r}_$c'),
      ),
    );
    _cellFocusNodes = List.generate(
      table.rowCount,
      (r) => List.generate(
        table.colCount,
        (c) => FocusNode(debugLabel: 'cellFocus_${r}_$c'),
      ),
    );
  }

  void _syncCellGrid() {
    final table = widget.table;

    // Grow/shrink rows
    while (_cellKeys.length < table.rowCount) {
      final r = _cellKeys.length;
      _cellKeys.add(List.generate(
        table.colCount,
        (c) => GlobalKey<BlockWidgetState>(
            debugLabel: 'cell_${widget.blockIndex}_${r}_$c'),
      ));
      _cellFocusNodes.add(List.generate(
        table.colCount,
        (c) => FocusNode(debugLabel: 'cellFocus_${r}_$c'),
      ));
    }
    while (_cellKeys.length > table.rowCount) {
      final removed = _cellFocusNodes.removeLast();
      for (final fn in removed) {
        fn.dispose();
      }
      _cellKeys.removeLast();
    }

    // Grow/shrink columns within each row
    for (int r = 0; r < table.rowCount; r++) {
      while (_cellKeys[r].length < table.colCount) {
        final c = _cellKeys[r].length;
        _cellKeys[r].add(GlobalKey<BlockWidgetState>(
            debugLabel: 'cell_${widget.blockIndex}_${r}_$c'));
        _cellFocusNodes[r].add(FocusNode(debugLabel: 'cellFocus_${r}_$c'));
      }
      while (_cellKeys[r].length > table.colCount) {
        _cellFocusNodes[r].removeLast().dispose();
        _cellKeys[r].removeLast();
      }
    }
  }

  @override
  void dispose() {
    for (final row in _cellFocusNodes) {
      for (final fn in row) {
        fn.dispose();
      }
    }
    super.dispose();
  }

  // ─── Cell Focus Navigation ─────────────────────────────────

  /// Moves focus to the next or previous cell (Tab / Shift+Tab).
  void _handleTab({bool reverse = false}) {
    if (!hasFocusedCell) return;

    int nextRow = _focusedRow;
    int nextCol = _focusedCol;

    if (reverse) {
      nextCol--;
      if (nextCol < 0) {
        nextRow--;
        nextCol = widget.table.colCount - 1;
      }
    } else {
      nextCol++;
      if (nextCol >= widget.table.colCount) {
        nextRow++;
        nextCol = 0;
      }
    }

    if (nextRow >= 0 &&
        nextRow < widget.table.rowCount &&
        nextCol >= 0 &&
        nextCol < widget.table.colCount) {
      _cellFocusNodes[nextRow][nextCol].requestFocus();
    }
  }

  // ─── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final table = widget.table;
    final tableStyle = widget.editorSettings.tableStyle;

    final borderSide = tableStyle.showGridLines
        ? BorderSide(
            color: tableStyle.borderColor,
            width: tableStyle.borderWidth,
          )
        : BorderSide.none;

    final isBlockTypeDraggable = widget.editorSettings.draggableBlockTypes
            ?.contains(widget.table.blockType) ??
        false;
    final isDraggable = widget.showDragHandle && isBlockTypeDraggable;

    final tableContainer = Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: tableStyle.borderColor,
            width: tableStyle.borderWidth,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Table(
            border: TableBorder(
              horizontalInside: borderSide,
              verticalInside: borderSide,
            ),
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            children: [
              for (int r = 0; r < table.rowCount; r++)
                TableRow(
                  decoration: _getRowDecoration(r, tableStyle),
                  children: [
                    for (int c = 0; c < table.colCount; c++)
                      _buildCell(r, c, table),
                  ],
                ),
            ],
          ),
        ),
      );

    Widget content = Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.tab) {
          final reverse = HardwareKeyboard.instance.isShiftPressed;
          _handleTab(reverse: reverse);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: tableContainer,
    );

    if (!isDraggable) {
      return content;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          child: ReorderableDragStartListener(
            index: widget.dragIndex ?? widget.blockIndex,
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Icon(
                Icons.drag_indicator,
                size: 18,
                color: widget.isDarkMode ? Colors.white38 : Colors.black26,
              ),
            ),
          ),
        ),
        Expanded(child: content),
      ],
    );
  }


  /// Builds a single cell using [BlockWidget] for full formatting support.
  Widget _buildCell(int row, int col, TableNode table) {
    final cell = table.rows[row][col];
    final cursorColor = widget.editorSettings.cursorColor ??
        Theme.of(context).colorScheme.primary;

    return TableCell(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!_cellFocusNodes[row][col].hasFocus) {
            _cellFocusNodes[row][col].requestFocus();
          }
        },
        child: Container(
          color: cell.backgroundColor ?? Colors.transparent,
          padding: widget.editorSettings.tableStyle.cellPadding,
          child: BlockWidget(
            key: _cellKeys[row][col],
            block: cell.block,
            blockIndex: widget.blockIndex,
            focusNode: _cellFocusNodes[row][col],
            editorSettings: widget.editorSettings,
            onTextChanged: (_, newText) {
              widget.onCellTextChanged(widget.blockIndex, row, col, newText);
            },
            onEnter: (_, __) {
              // In table cells, Enter does nothing (no block splitting)
            },
            onBackspaceAtStart: (_) {
              // In table cells, backspace at start does nothing
            },
            onDeleteAtEnd: (_) {
              // In table cells, delete at end does nothing
            },
            onFocusChanged: (_, hasFocus) {
              if (hasFocus) {
                setState(() {
                  _focusedRow = row;
                  _focusedCol = col;
                });
              }
              widget.onCellFocusChanged(widget.blockIndex, row, col, hasFocus);
            },
            onSelectionChanged: (_, baseOffset, extentOffset) {
              widget.onCellSelectionChanged(
                  widget.blockIndex, row, col, baseOffset, extentOffset);
            },
            onPaste: (_) {
              widget.onCellPaste(widget.blockIndex, row, col);
            },
            readOnly: widget.readOnly,
            isDarkMode: widget.isDarkMode,
            cursorColor: cursorColor,
            cursorWidth: widget.editorSettings.cursorWidth,
            cursorRadius: widget.editorSettings.cursorRadius,
            selectionColor: widget.editorSettings.selectionColor,
            showDragHandle: false,
            orderedCount: 0,
          ),
        ),
      ),
    );
  }

  BoxDecoration? _getRowDecoration(int rowIndex, SmartTableStyle tableStyle) {
    if (widget.table.hasHeaderRow &&
        rowIndex == 0 &&
        tableStyle.headerBackgroundColor != null) {
      return BoxDecoration(color: tableStyle.headerBackgroundColor);
    }
    return null;
  }
}
