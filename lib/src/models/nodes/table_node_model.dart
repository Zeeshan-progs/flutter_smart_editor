import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import '../../core/document/document.dart';
import '../enums.dart';

/// A single cell in a table.
///
/// Each cell wraps a [BlockNode] which holds the spans and alignment.
/// This allows the cell to be rendered using the same [BlockWidget] that
/// renders regular document blocks, inheriting all formatting support.
class TableCellNode {
  /// Unique identifier for this cell.
  final String id;

  /// The backing block for this cell.
  /// This is what gets rendered by [BlockWidget].
  BlockNode block;

  /// Optional background color for the cell.
  Color? backgroundColor;

  TableCellNode({
    String? id,
    List<TextFormatSpan>? spans,
    this.backgroundColor,
    SmartTextAlign alignment = SmartTextAlign.left,
    BlockNode? block,
  })  : id = id ?? UniqueKey().toString(),
        block = block ??
            ParagraphNode(
              spans: spans ?? [TextFormatSpan.plain('')],
              alignment: alignment,
            );

  /// Internal constructor that takes an existing BlockNode.
  TableCellNode._withBlock({
    required this.id,
    required this.block,
    this.backgroundColor,
  });

  /// Creates an empty cell with a single plain-text span.
  factory TableCellNode.empty() => TableCellNode();

  // ─── Delegate to the backing block ──────────────────────────

  /// The formatted text spans within this cell.
  List<TextFormatSpan> get spans => block.spans;
  set spans(List<TextFormatSpan> value) => block.spans = value;

  /// Text alignment within this cell.
  SmartTextAlign get alignment => block.alignment;
  set alignment(SmartTextAlign value) => block.alignment = value;

  /// The combined plain text of all spans.
  String get plainText => block.plainText;

  /// The total character length across all spans.
  int get textLength => block.textLength;

  /// Locates the span and local offset for a given global offset.
  ({int spanIndex, int localOffset}) getSpanAt(int globalOffset) =>
      block.getSpanAt(globalOffset);

  /// Merges adjacent spans with identical formatting.
  void normalizeSpans() => block.normalizeSpans();

  /// Creates a deep copy of this cell.
  TableCellNode deepCopy() => TableCellNode._withBlock(
        id: id,
        block: block.deepCopy(),
        backgroundColor: backgroundColor,
      );

  @override
  String toString() => 'TableCellNode(text="$plainText")';
}

/// A table block containing a 2D grid of [TableCellNode]s.
///
/// Each table is a top-level block in the document, rendered as
/// a grid of editable cells. All inline formatting is supported
/// within each cell via the backing [ParagraphNode].
class TableNode extends BlockNode {
  /// The 2D grid of cells: `rows[rowIndex][colIndex]`.
  final List<List<TableCellNode>> rows;

  /// Whether the first row should be treated as a header row.
  bool hasHeaderRow;

  /// Border width in logical pixels.
  double borderWidth;

  /// Border color. If null, uses the theme default.
  Color? borderColor;

  /// Padding inside each cell.
  EdgeInsets cellPadding;

  TableNode({
    required this.rows,
    this.hasHeaderRow = false,
    this.borderWidth = 1.0,
    this.borderColor,
    this.cellPadding = const EdgeInsets.all(8),
    super.id,
  }) : super(spans: [TextFormatSpan.plain('')]);

  /// Creates an empty table with the given dimensions.
  factory TableNode.empty({
    int rows = 2,
    int cols = 2,
    String? id,
  }) {
    final grid = List.generate(
      rows,
      (_) => List.generate(cols, (_) => TableCellNode.empty()),
    );
    return TableNode(rows: grid, id: id);
  }

  /// Number of rows in the table.
  int get rowCount => rows.length;

  /// Number of columns (based on the first row).
  int get colCount => rows.isEmpty ? 0 : rows.first.length;

  /// Gets the cell at the given position.
  TableCellNode getCell(int row, int col) => rows[row][col];

  /// Inserts a new empty row at the given index.
  void insertRow(int atIndex) {
    final cols = colCount;
    final newRow = List.generate(cols, (_) => TableCellNode.empty());
    rows.insert(atIndex.clamp(0, rows.length), newRow);
  }

  /// Removes the row at the given index.
  void removeRow(int atIndex) {
    if (rows.length <= 1) return; // Don't remove the last row
    if (atIndex >= 0 && atIndex < rows.length) {
      rows.removeAt(atIndex);
    }
  }

  /// Inserts a new empty column at the given index.
  void insertColumn(int atIndex) {
    final clampedIndex = atIndex.clamp(0, colCount);
    for (final row in rows) {
      row.insert(clampedIndex, TableCellNode.empty());
    }
  }

  /// Removes the column at the given index.
  void removeColumn(int atIndex) {
    if (colCount <= 1) return; // Don't remove the last column
    if (atIndex >= 0 && atIndex < colCount) {
      for (final row in rows) {
        row.removeAt(atIndex);
      }
    }
  }

  @override
  String get tag => 'table';

  @override
  BlockType get blockType => BlockType.table;

  /// Total text length across all cells.
  @override
  int get textLength =>
      rows.fold(0, (sum, row) => sum + row.fold(0, (s, c) => s + c.textLength));

  /// Combined plain text of all cells (rows separated by tabs, cells by newlines).
  @override
  String get plainText =>
      rows.map((row) => row.map((c) => c.plainText).join('\t')).join('\n');

  @override
  BlockNode deepCopy() => TableNode(
        rows: rows
            .map((row) => row.map((cell) => cell.deepCopy()).toList())
            .toList(),
        hasHeaderRow: hasHeaderRow,
        borderWidth: borderWidth,
        borderColor: borderColor,
        cellPadding: cellPadding,
        id: id,
      );

  @override
  String toString() => 'TableNode(${rowCount}x$colCount)';
}
