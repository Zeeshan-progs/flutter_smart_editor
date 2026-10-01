import 'package:meta/meta.dart';
import 'package:flutter_smart_editor/src/core/document/document.dart';
import '../../../models/enums.dart';
import 'list_document_controller.dart';

/// Controller handling table creation, cell modifications, rows, columns, and cell formatting.
class TableDocumentController extends ListDocumentController {
  TableDocumentController({
    super.document,
    super.undoRedoManager,
  });

  // ─── Table Operations ──────────────────────────────────────────

  /// Inserts an empty table after [blockIndex].
  ///
  /// Also inserts an empty paragraph after the table so the user
  /// can escape the table by pressing Enter or Down at the end.
  void insertTable(int blockIndex, {int rows = 2, int cols = 2}) {
    saveState();
    final table = TableNode.empty(rows: rows, cols: cols);
    final insertAt = (blockIndex + 1).clamp(0, document.blocks.length);
    document.blocks.insert(insertAt, table);
    // Insert an empty paragraph after the table for cursor escape
    document.blocks.insert(insertAt + 1, ParagraphNode());
    notifyChanged();
  }

  /// Updates the text in a specific table cell.
  ///
  /// Uses the same span-diffing logic as [updateBlockText] but
  /// operates on the cell's spans rather than the block's spans.
  void updateCellText(
      int blockIndex, int row, int col, String oldText, String newText,
      {TextFormatSpan? pendingFormat}) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! TableNode) return;
    if (row < 0 || row >= block.rowCount || col < 0 || col >= block.colCount) {
      return;
    }
    if (oldText == newText) return;

    saveState();
    final cell = block.getCell(row, col);

    // Find the diff between old and new text
    int commonPrefix = 0;
    while (commonPrefix < oldText.length &&
        commonPrefix < newText.length &&
        oldText[commonPrefix] == newText[commonPrefix]) {
      commonPrefix++;
    }

    int commonSuffix = 0;
    while (commonSuffix < (oldText.length - commonPrefix) &&
        commonSuffix < (newText.length - commonPrefix) &&
        oldText[oldText.length - 1 - commonSuffix] ==
            newText[newText.length - 1 - commonSuffix]) {
      commonSuffix++;
    }

    final deleteCount = oldText.length - commonPrefix - commonSuffix;
    final insertText =
        newText.substring(commonPrefix, newText.length - commonSuffix);

    // Delete removed text
    if (deleteCount > 0) {
      deleteFromCellSpans(cell, commonPrefix, deleteCount);
    }

    // Insert new text
    if (insertText.isNotEmpty) {
      if (pendingFormat != null) {
        insertFormattedIntoCellSpans(
            cell, commonPrefix, insertText, pendingFormat);
      } else {
        insertIntoCellSpans(cell, commonPrefix, insertText);
      }
    }

    notifyChanged();
  }

  /// Toggles a formatting flag on a cell's text selection.
  void toggleCellFormat(int blockIndex, int row, int col, int start, int end,
      SmartButtonType format) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! TableNode) return;
    if (start >= end) return;

    saveState();
    final cell = block.getCell(row, col);
    splitCellSpanAt(cell, start);
    splitCellSpanAt(cell, end);

    bool isActive = false;
    var offset = 0;
    for (final span in cell.spans) {
      final spanEnd = offset + span.text.length;
      if (offset >= start && spanEnd <= end && span.text.isNotEmpty) {
        isActive = getFormat(span, format) == true;
        break;
      }
      offset = spanEnd;
    }

    offset = 0;
    for (final span in cell.spans) {
      final spanEnd = offset + span.text.length;
      if (offset >= start && spanEnd <= end) {
        setFormat(span, format, !isActive);
      }
      offset = spanEnd;
    }

    cell.normalizeSpans();
    notifyChanged();
  }

  /// Applies a formatting value on a cell's text selection.
  void applyCellFormat(int blockIndex, int row, int col, int start, int end,
      SmartButtonType format, dynamic value) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! TableNode) return;
    if (start >= end) return;

    saveState();
    final cell = block.getCell(row, col);
    splitCellSpanAt(cell, start);
    splitCellSpanAt(cell, end);

    var offset = 0;
    for (final span in cell.spans) {
      final spanEnd = offset + span.text.length;
      if (offset >= start && spanEnd <= end) {
        setFormat(span, format, value);
      }
      offset = spanEnd;
    }

    cell.normalizeSpans();
    notifyChanged();
  }

  /// Sets alignment on a specific table cell.
  void setCellAlignment(
      int blockIndex, int row, int col, SmartTextAlign alignment) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! TableNode) return;

    saveState();
    block.getCell(row, col).alignment = alignment;
    notifyChanged();
  }

  /// Changes the block type of a specific table cell.
  void changeCellBlockType(
      int blockIndex, int row, int col, BlockType newType) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! TableNode) return;

    final cell = block.getCell(row, col);
    final oldBlock = cell.block;
    final spans = oldBlock.spans;
    final alignment = oldBlock.alignment;
    final id = oldBlock.id;

    BlockNode newBlock;
    switch (newType) {
      case BlockType.paragraph:
        newBlock = ParagraphNode(id: id, spans: spans, alignment: alignment);
        break;
      case BlockType.heading1:
        newBlock =
            HeadingNode(id: id, level: 1, spans: spans, alignment: alignment);
        break;
      case BlockType.heading2:
        newBlock =
            HeadingNode(id: id, level: 2, spans: spans, alignment: alignment);
        break;
      case BlockType.heading3:
        newBlock =
            HeadingNode(id: id, level: 3, spans: spans, alignment: alignment);
        break;
      case BlockType.heading4:
        newBlock =
            HeadingNode(id: id, level: 4, spans: spans, alignment: alignment);
        break;
      case BlockType.heading5:
        newBlock =
            HeadingNode(id: id, level: 5, spans: spans, alignment: alignment);
        break;
      case BlockType.heading6:
        newBlock =
            HeadingNode(id: id, level: 6, spans: spans, alignment: alignment);
        break;
      case BlockType.bulletList:
        newBlock = ListItemNode(
            id: id,
            listType: SmartListType.bullet,
            spans: spans,
            alignment: alignment);
        break;
      case BlockType.orderedList:
        newBlock = ListItemNode(
            id: id,
            listType: SmartListType.ordered,
            spans: spans,
            alignment: alignment);
        break;
      case BlockType.horizontalRule:
        // Horizontal rules aren't supported inside table cells
        return;
      case BlockType.table:
      case BlockType.image:
        // Tables and images cannot be nested or converted as cell blocks
        return;
    }

    saveState();
    cell.block = newBlock;
    notifyChanged();
  }

  /// Toggles a list type on a specific table cell.
  void toggleCellList(
      int blockIndex, int row, int col, SmartListType listType) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! TableNode) return;

    saveState();
    final cell = block.getCell(row, col);
    final cellBlock = cell.block;

    if (cellBlock is ListItemNode) {
      if (cellBlock.listType == listType) {
        cell.block = ParagraphNode(
            id: cellBlock.id,
            spans: cellBlock.spans,
            alignment: cellBlock.alignment);
      } else {
        cell.block = ListItemNode(
          id: cellBlock.id,
          listType: listType,
          depth: cellBlock.depth,
          bulletStyle: cellBlock.bulletStyle,
          spans: cellBlock.spans,
          alignment: cellBlock.alignment,
        );
      }
    } else {
      cell.block = ListItemNode(
        id: cellBlock.id,
        listType: listType,
        depth: 0,
        spans: cellBlock.spans,
        alignment: cellBlock.alignment,
      );
    }

    notifyChanged();
  }

  /// Clears formatting on a range within a table cell.
  void clearCellFormat(
      int blockIndex, int row, int col, int offset, int length) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! TableNode) return;
    if (length <= 0) return;

    saveState();
    final cell = block.getCell(row, col);
    final oldSpans = cell.spans;
    final newSpans = <TextFormatSpan>[];

    var currentOffset = 0;
    for (final span in oldSpans) {
      final spanEnd = currentOffset + span.text.length;
      if (spanEnd <= offset || currentOffset >= offset + length) {
        newSpans.add(span);
      } else {
        if (currentOffset < offset) {
          newSpans.add(span.copyWith(
              text: span.text.substring(0, offset - currentOffset)));
        }
        final startInside = currentOffset < offset ? offset - currentOffset : 0;
        final endInside = spanEnd > offset + length
            ? span.text.length - (spanEnd - (offset + length))
            : span.text.length;
        if (endInside > startInside) {
          newSpans.add(TextFormatSpan.plain(
              span.text.substring(startInside, endInside)));
        }
        if (spanEnd > offset + length) {
          final rightStart = span.text.length - (spanEnd - (offset + length));
          newSpans.add(span.copyWith(
              text: span.text.substring(rightStart)));
        }
      }
      currentOffset = spanEnd;
    }

    cell.spans = newSpans;
    cell.normalizeSpans();
    notifyChanged();
  }

  /// Applies or removes a hyperlink over a range of text in a table cell.
  void applyCellLink(
      int blockIndex, int row, int col, int start, int end, String? url) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    if (start >= end) return;
    final block = document.blocks[blockIndex];
    if (block is! TableNode) return;

    saveState();
    final cell = block.getCell(row, col);
    splitCellSpanAt(cell, start);
    splitCellSpanAt(cell, end);

    var offset = 0;
    for (final span in cell.spans) {
      final spanEnd = offset + span.text.length;
      if (offset >= start && spanEnd <= end) {
        span.linkUrl = url;
      }
      offset = spanEnd;
    }
    notifyChanged();
  }

  /// Inserts a new hyperlinked text run at [offset] in a table cell.
  void insertCellLink(int blockIndex, int row, int col, int offset, String text,
      String? url) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    if (text.isEmpty) return;
    final block = document.blocks[blockIndex];
    if (block is! TableNode) return;

    saveState();
    final cell = block.getCell(row, col);
    final linkSpan = TextFormatSpan(text: text, linkUrl: url);
    insertFormattedIntoCellSpans(cell, offset, text, linkSpan);
    notifyChanged();
  }

  /// Atomically applies or replaces a hyperlink for a table cell, appending an unlinked space if needed.
  /// Returns the target cursor offset (immediately after the inserted space).
  int setCellLink({
    required int blockIndex,
    required int row,
    required int col,
    required int start,
    required int end,
    required String text,
    required String url,
  }) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return 0;
    if (text.isEmpty) return 0;
    final block = document.blocks[blockIndex];
    if (block is! TableNode) return 0;

    saveState();
    final cell = block.getCell(row, col);
    final currentCellText = cell.plainText;
    final safeStart = start.clamp(0, currentCellText.length);
    final safeEnd = end.clamp(safeStart, currentCellText.length);

    int linkEnd;
    final selectedText = (safeStart < safeEnd)
        ? currentCellText.substring(safeStart, safeEnd)
        : '';

    if (safeStart < safeEnd && text == selectedText) {
      splitCellSpanAt(cell, safeStart);
      splitCellSpanAt(cell, safeEnd);

      var offset = 0;
      for (final span in cell.spans) {
        final spanEnd = offset + span.text.length;
        if (offset >= safeStart && spanEnd <= safeEnd) {
          span.linkUrl = url;
        }
        offset = spanEnd;
      }
      linkEnd = safeEnd;
    } else {
      if (safeEnd > safeStart) {
        deleteFromCellSpans(cell, safeStart, safeEnd - safeStart);
      }
      final linkSpan = TextFormatSpan(text: text, linkUrl: url);
      insertFormattedIntoCellSpans(cell, safeStart, text, linkSpan);
      linkEnd = safeStart + text.length;
    }

    final textAfterLink = cell.plainText;
    final hasSpaceAfter =
        linkEnd < textAfterLink.length && textAfterLink[linkEnd] == ' ';

    if (!hasSpaceAfter) {
      insertFormattedIntoCellSpans(
        cell,
        linkEnd,
        ' ',
        TextFormatSpan.plain(' '),
      );
    }

    cell.normalizeSpans();
    notifyChanged();

    return linkEnd + 1;
  }

  /// Deletes [length] characters starting from [start] in a table cell.
  void deleteCellText(
      int blockIndex, int row, int col, int start, int length) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    if (length <= 0) return;
    final block = document.blocks[blockIndex];
    if (block is! TableNode) return;

    saveState();
    final cell = block.getCell(row, col);
    deleteFromCellSpans(cell, start, length);
    notifyChanged();
  }

  /// Returns the link text and url at [offset] in a table cell, if any.
  Map<String, String?> getCellLinkInfoAt(
      int blockIndex, int row, int col, int offset) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) {
      return {'text': null, 'url': null};
    }
    final block = document.blocks[blockIndex];
    if (block is! TableNode) return {'text': null, 'url': null};

    final cell = block.getCell(row, col);
    if (cell.spans.isEmpty) return {'text': null, 'url': null};

    final loc = cell.getSpanAt(offset);
    if (loc.spanIndex >= cell.spans.length) return {'text': null, 'url': null};

    final span = cell.spans[loc.spanIndex];
    if (span.linkUrl != null && span.linkUrl!.isNotEmpty) {
      return {'text': span.text, 'url': span.linkUrl};
    }
    return {'text': null, 'url': null};
  }

  /// Gets the format state at a specific offset within a table cell.
  Map<SmartButtonType, dynamic> getCellFormatAt(
      int blockIndex, int row, int col, int offset) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) {
      return defaultFormat();
    }
    final block = document.blocks[blockIndex];
    if (block is! TableNode) return defaultFormat();

    final cell = block.getCell(row, col);
    if (cell.spans.isEmpty) return defaultFormat();

    final loc = cell.getSpanAt(offset);
    if (loc.spanIndex >= cell.spans.length) return defaultFormat();

    final span = cell.spans[loc.spanIndex];
    final cellBlock = cell.block;

    return {
      SmartButtonType.bold: span.isBold,
      SmartButtonType.italic: span.isItalic,
      SmartButtonType.underline: span.isUnderline,
      SmartButtonType.strikethrough: span.isStrikethrough,
      SmartButtonType.fontName: span.fontFamily,
      SmartButtonType.fontSize: span.fontSize,
      SmartButtonType.foregroundColor: span.foregroundColor,
      SmartButtonType.highlightColor: span.backgroundColor,
      SmartButtonType.alignLeft: cellBlock.alignment == SmartTextAlign.left,
      SmartButtonType.alignCenter: cellBlock.alignment == SmartTextAlign.center,
      SmartButtonType.alignRight: cellBlock.alignment == SmartTextAlign.right,
      SmartButtonType.alignJustify:
          cellBlock.alignment == SmartTextAlign.justify,
      SmartButtonType.blockType: cellBlock.blockType,
      SmartButtonType.insertLink:
          span.linkUrl != null && span.linkUrl!.isNotEmpty,
    };
  }

  /// Inserts a row into the table at [atRowIndex].
  void insertTableRow(int blockIndex, int atRowIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! TableNode) return;

    saveState();
    block.insertRow(atRowIndex);
    notifyChanged();
  }

  /// Removes a row from the table.
  void removeTableRow(int blockIndex, int rowIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! TableNode) return;
    if (block.rowCount <= 1) return; // Don't remove the last row

    saveState();
    block.removeRow(rowIndex);
    notifyChanged();
  }

  /// Inserts a column into the table at [atColIndex].
  void insertTableColumn(int blockIndex, int atColIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! TableNode) return;

    saveState();
    block.insertColumn(atColIndex);
    notifyChanged();
  }

  /// Removes a column from the table.
  void removeTableColumn(int blockIndex, int colIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! TableNode) return;
    if (block.colCount <= 1) return; // Don't remove the last column

    saveState();
    block.removeColumn(colIndex);
    notifyChanged();
  }

  /// Deletes an entire table, replacing it with an empty paragraph.
  void deleteTable(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    if (document.blocks[blockIndex] is! TableNode) return;

    saveState();
    document.blocks[blockIndex] = ParagraphNode();
    notifyChanged();
  }

  /// Inserts a parsed document into a specific table cell.
  void insertCellParsedDocument(
      int blockIndex, int row, int col, int offset, Document parsedDoc) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! TableNode) return;

    final cell = block.getCell(row, col);
    saveState();

    // For now, we only support merging text content into the cell's current block
    // since TableCellNode holds a single block.
    final textToInsert = parsedDoc.plainText;
    if (textToInsert.isNotEmpty) {
      insertIntoCellSpans(cell, offset, textToInsert);
    }

    notifyChanged();
  }

  /// Inserts text into a specific table cell at the given offset.
  void insertCellText(
      int blockIndex, int row, int col, int offset, String text) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! TableNode) return;

    final cell = block.getCell(row, col);
    saveState();
    insertIntoCellSpans(cell, offset, text);
    notifyChanged();
  }

  // ─── Table Span Helpers ────────────────────────────────────────

  /// Splits a cell's span at the given offset (cell-level equivalent of splitSpanAt).
  @protected
  void splitCellSpanAt(TableCellNode cell, int offset) {
    if (offset <= 0) return;
    var current = 0;
    for (var i = 0; i < cell.spans.length; i++) {
      final span = cell.spans[i];
      final spanEnd = current + span.text.length;
      if (offset > current && offset < spanEnd) {
        final localOffset = offset - current;
        final left = span.copyWith(text: span.text.substring(0, localOffset));
        final right = span.copyWith(text: span.text.substring(localOffset));
        cell.spans[i] = left;
        cell.spans.insert(i + 1, right);
        return;
      }
      current = spanEnd;
    }
  }

  @protected
  void deleteFromCellSpans(TableCellNode cell, int offset, int count) {
    if (count <= 0) return;
    final delStart = offset;
    final delEnd = offset + count;
    var current = 0;

    for (var i = 0; i < cell.spans.length; i++) {
      final span = cell.spans[i];
      final origLen = span.text.length;
      final spanEnd = current + origLen;

      if (spanEnd > delStart && current < delEnd) {
        final localStart = (delStart - current).clamp(0, origLen);
        final localEnd = (delEnd - current).clamp(0, origLen);
        if (localEnd > localStart) {
          span.text = span.text.substring(0, localStart) +
              span.text.substring(localEnd);
          if (span.text.isEmpty) {
            cell.spans.removeAt(i);
            i--;
          }
        }
      }
      current = spanEnd;
    }

    if (cell.spans.isEmpty) {
      cell.spans.add(TextFormatSpan.plain(''));
    }
  }

  /// Inserts text into a cell's spans (cell-level equivalent of insertIntoSpans).
  @protected
  void insertIntoCellSpans(TableCellNode cell, int offset, String text) {
    if (text.isEmpty) return;

    var current = 0;
    for (var i = 0; i < cell.spans.length; i++) {
      final span = cell.spans[i];
      final spanEnd = current + span.text.length;

      if (offset <= spanEnd) {
        final localOffset = offset - current;
        span.text = span.text.substring(0, localOffset) +
            text +
            span.text.substring(localOffset);
        return;
      }
      current = spanEnd;
    }

    // Append to last span
    cell.spans.last.text += text;
  }

  @protected
  void insertFormattedIntoCellSpans(
    TableCellNode cell,
    int offset,
    String text,
    TextFormatSpan format,
  ) {
    if (text.isEmpty) return;

    splitCellSpanAt(cell, offset);

    var currentOffset = 0;
    var insertIndex = 0;
    for (var i = 0; i < cell.spans.length; i++) {
      if (currentOffset >= offset) {
        insertIndex = i;
        break;
      }
      currentOffset += cell.spans[i].text.length;
      insertIndex = i + 1;
    }

    final newSpan = format.copyWith(text: text);
    cell.spans.insert(insertIndex, newSpan);
  }
}
