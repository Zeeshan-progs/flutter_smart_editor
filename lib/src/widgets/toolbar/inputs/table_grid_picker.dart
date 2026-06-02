import 'package:flutter/material.dart';

/// A hoverable grid picker for selecting table dimensions,
/// designed to be shown inside a bottom sheet.
///
/// Displays a grid of small squares. As the user taps/hovers,
/// cells highlight from (0,0) to the current position. A label
/// shows the selected dimensions and a confirm button inserts.
class TableGridPicker extends StatefulWidget {
  const TableGridPicker({
    super.key,
    required this.onSelect,
    this.isDarkMode = false,
    this.maxRows = 8,
    this.maxCols = 8,
  });

  final void Function(int rows, int cols) onSelect;
  final bool isDarkMode;
  final int maxRows;
  final int maxCols;

  @override
  State<TableGridPicker> createState() => _TableGridPickerState();
}

class _TableGridPickerState extends State<TableGridPicker> {
  int _selectedRow = 1; // default 2×2 (0-indexed → row=1 means 2 rows)
  int _selectedCol = 1;

  static const double _cellSize = 32;
  static const double _cellSpacing = 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlightColor = theme.colorScheme.primary;
    final defaultColor = widget.isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.grey.shade200;
    final selectedBorder = highlightColor;
    final unselectedBorder = widget.isDarkMode
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.grey.shade300;

    final label = '${_selectedRow + 1} × ${_selectedCol + 1}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? Colors.white24 : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Text(
            'Insert Table',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: widget.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),

          const SizedBox(height: 16),

          // Grid
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int r = 0; r < widget.maxRows; r++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int c = 0; c < widget.maxCols; c++)
                        Padding(
                          padding: const EdgeInsets.all(_cellSpacing / 2),
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _selectedRow = r;
                              _selectedCol = c;
                            }),
                            onPanUpdate: (details) {
                              // Drag to select
                              final RenderBox box =
                                  context.findRenderObject() as RenderBox;
                              final local =
                                  box.globalToLocal(details.globalPosition);
                              // Approximate cell from position
                              const totalCellSize = _cellSize + _cellSpacing;
                              // Calculate grid origin (centered)
                              final gridWidth = widget.maxCols * totalCellSize;
                              final boxWidth = box.size.width;
                              final gridLeft = (boxWidth - gridWidth) / 2;
                              const gridTop = 4 +
                                  16 +
                                  22 +
                                  16.0; // handle + title + spacing

                              final col =
                                  ((local.dx - gridLeft) / totalCellSize)
                                      .floor()
                                      .clamp(0, widget.maxCols - 1);
                              final row = ((local.dy - gridTop) / totalCellSize)
                                  .floor()
                                  .clamp(0, widget.maxRows - 1);

                              if (row != _selectedRow || col != _selectedCol) {
                                setState(() {
                                  _selectedRow = row;
                                  _selectedCol = col;
                                });
                              }
                            },
                            child: MouseRegion(
                              onEnter: (_) => setState(() {
                                _selectedRow = r;
                                _selectedCol = c;
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                width: _cellSize,
                                height: _cellSize,
                                decoration: BoxDecoration(
                                  color: (r <= _selectedRow &&
                                          c <= _selectedCol)
                                      ? highlightColor.withValues(alpha: 0.25)
                                      : defaultColor,
                                  border: Border.all(
                                    color:
                                        (r <= _selectedRow && c <= _selectedCol)
                                            ? selectedBorder
                                            : unselectedBorder,
                                    width:
                                        (r <= _selectedRow && c <= _selectedCol)
                                            ? 2
                                            : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Dimension label
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: highlightColor,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: 16),

          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () =>
                  widget.onSelect(_selectedRow + 1, _selectedCol + 1),
              icon: const Icon(Icons.check, size: 20),
              label: Text(
                  'Insert ${_selectedRow + 1} × ${_selectedCol + 1} Table'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
