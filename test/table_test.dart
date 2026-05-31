import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_editor/src/core/document/document.dart';
import 'package:flutter_smart_editor/src/core/document/document_controller.dart';
import 'package:flutter_smart_editor/src/models/enums.dart';

void main() {
  group('TableNode model', () {
    test('empty factory creates correct dimensions', () {
      final table = TableNode.empty(rows: 3, cols: 4);
      expect(table.rowCount, 3);
      expect(table.colCount, 4);
      expect(table.blockType, BlockType.table);
      expect(table.tag, 'table');
    });

    test('insertRow adds a new row at the correct position', () {
      final table = TableNode.empty(rows: 2, cols: 3);
      table.insertRow(1);
      expect(table.rowCount, 3);
      expect(table.rows[1].length, 3);
    });

    test('removeRow removes the correct row', () {
      final table = TableNode.empty(rows: 3, cols: 2);
      table.rows[1][0].spans = [TextFormatSpan.plain('target')];
      table.removeRow(1);
      expect(table.rowCount, 2);
      expect(table.rows[0][0].plainText, '');
      expect(table.rows[1][0].plainText, '');
    });

    test('removeRow does nothing when only 1 row', () {
      final table = TableNode.empty(rows: 1, cols: 2);
      table.removeRow(0);
      expect(table.rowCount, 1);
    });

    test('insertColumn adds a column at the correct position', () {
      final table = TableNode.empty(rows: 2, cols: 2);
      table.insertColumn(1);
      expect(table.colCount, 3);
      for (final row in table.rows) {
        expect(row.length, 3);
      }
    });

    test('removeColumn removes the correct column', () {
      final table = TableNode.empty(rows: 2, cols: 3);
      table.rows[0][1].spans = [TextFormatSpan.plain('target')];
      table.removeColumn(1);
      expect(table.colCount, 2);
      expect(table.rows[0][0].plainText, '');
      expect(table.rows[0][1].plainText, '');
    });

    test('removeColumn does nothing when only 1 column', () {
      final table = TableNode.empty(rows: 2, cols: 1);
      table.removeColumn(0);
      expect(table.colCount, 1);
    });

    test('deepCopy creates independent copy', () {
      final table = TableNode.empty(rows: 2, cols: 2);
      table.rows[0][0].spans = [TextFormatSpan.plain('hello')];
      final copy = table.deepCopy() as TableNode;
      copy.rows[0][0].spans = [TextFormatSpan.plain('changed')];
      expect(table.rows[0][0].plainText, 'hello');
      expect(copy.rows[0][0].plainText, 'changed');
    });

    test('plainText joins cells with tabs and rows with newlines', () {
      final table = TableNode.empty(rows: 2, cols: 2);
      table.rows[0][0].spans = [TextFormatSpan.plain('A')];
      table.rows[0][1].spans = [TextFormatSpan.plain('B')];
      table.rows[1][0].spans = [TextFormatSpan.plain('C')];
      table.rows[1][1].spans = [TextFormatSpan.plain('D')];
      expect(table.plainText, 'A\tB\nC\tD');
    });
  });

  group('TableCellNode model', () {
    test('empty factory creates empty cell', () {
      final cell = TableCellNode.empty();
      expect(cell.plainText, '');
      expect(cell.textLength, 0);
      expect(cell.alignment, SmartTextAlign.left);
    });

    test('getSpanAt locates correct span', () {
      final cell = TableCellNode(spans: [
        TextFormatSpan(text: 'Hello', isBold: true),
        TextFormatSpan(text: ' World'),
      ]);
      final loc = cell.getSpanAt(7); // 'W' in ' World'
      expect(loc.spanIndex, 1);
      expect(loc.localOffset, 2);
    });

    test('normalizeSpans merges adjacent spans with same format', () {
      final cell = TableCellNode(spans: [
        TextFormatSpan.plain('Hello'),
        TextFormatSpan.plain(' World'),
      ]);
      cell.normalizeSpans();
      expect(cell.spans.length, 1);
      expect(cell.plainText, 'Hello World');
    });

    test('deepCopy creates independent copy', () {
      final cell = TableCellNode(
        spans: [TextFormatSpan(text: 'test', isBold: true)],
        alignment: SmartTextAlign.center,
      );
      final copy = cell.deepCopy();
      copy.spans[0].text = 'changed';
      expect(cell.spans[0].text, 'test');
    });
  });

  group('DocumentController table operations', () {
    late DocumentController controller;

    setUp(() {
      controller = DocumentController(
        document: Document(blocks: [ParagraphNode()]),
      );
    });

    test('insertTable adds table and trailing paragraph', () {
      controller.insertTable(0, rows: 3, cols: 2);
      expect(controller.document.blocks.length, 3);
      expect(controller.document.blocks[1], isA<TableNode>());
      expect(controller.document.blocks[2], isA<ParagraphNode>());
      final table = controller.document.blocks[1] as TableNode;
      expect(table.rowCount, 3);
      expect(table.colCount, 2);
    });

    test('updateCellText modifies cell text', () {
      controller.insertTable(0, rows: 2, cols: 2);
      controller.updateCellText(1, 0, 0, '', 'Hello');
      final table = controller.document.blocks[1] as TableNode;
      expect(table.rows[0][0].plainText, 'Hello');
    });

    test('toggleCellFormat toggles bold', () {
      controller.insertTable(0, rows: 2, cols: 2);
      controller.updateCellText(1, 0, 0, '', 'Hello');
      controller.toggleCellFormat(
          1, 0, 0, 0, 5, SmartButtonType.bold);
      final table = controller.document.blocks[1] as TableNode;
      expect(table.rows[0][0].spans.first.isBold, true);
    });

    test('applyCellFormat applies font size', () {
      controller.insertTable(0, rows: 2, cols: 2);
      controller.updateCellText(1, 0, 0, '', 'Hello');
      controller.applyCellFormat(
          1, 0, 0, 0, 5, SmartButtonType.fontSize, 24.0);
      final table = controller.document.blocks[1] as TableNode;
      expect(table.rows[0][0].spans.first.fontSize, 24.0);
    });

    test('getCellFormatAt returns correct format', () {
      controller.insertTable(0, rows: 2, cols: 2);
      controller.updateCellText(1, 0, 0, '', 'Hello');
      controller.toggleCellFormat(
          1, 0, 0, 0, 5, SmartButtonType.bold);
      final format = controller.getCellFormatAt(1, 0, 0, 2);
      expect(format[SmartButtonType.bold], true);
      expect(format[SmartButtonType.italic], false);
    });

    test('insertTableRow adds row correctly', () {
      controller.insertTable(0, rows: 2, cols: 2);
      controller.insertTableRow(1, 1);
      final table = controller.document.blocks[1] as TableNode;
      expect(table.rowCount, 3);
    });

    test('removeTableRow removes row', () {
      controller.insertTable(0, rows: 3, cols: 2);
      controller.removeTableRow(1, 1);
      final table = controller.document.blocks[1] as TableNode;
      expect(table.rowCount, 2);
    });

    test('insertTableColumn adds column', () {
      controller.insertTable(0, rows: 2, cols: 2);
      controller.insertTableColumn(1, 1);
      final table = controller.document.blocks[1] as TableNode;
      expect(table.colCount, 3);
    });

    test('removeTableColumn removes column', () {
      controller.insertTable(0, rows: 2, cols: 3);
      controller.removeTableColumn(1, 1);
      final table = controller.document.blocks[1] as TableNode;
      expect(table.colCount, 2);
    });

    test('deleteTable replaces table with paragraph', () {
      controller.insertTable(0, rows: 2, cols: 2);
      expect(controller.document.blocks[1], isA<TableNode>());
      controller.deleteTable(1);
      expect(controller.document.blocks[1], isA<ParagraphNode>());
    });

    test('undo restores state after insertTable', () {
      controller.insertTable(0, rows: 2, cols: 2);
      expect(controller.document.blocks.length, 3);
      controller.undo();
      expect(controller.document.blocks.length, 1);
    });
  });
}
