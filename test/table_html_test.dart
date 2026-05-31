import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_editor/src/core/document/document.dart';
import 'package:flutter_smart_editor/src/core/infra/html_parser.dart';
import 'package:flutter_smart_editor/src/core/infra/html_serializer.dart';
import 'package:flutter_smart_editor/src/models/enums.dart';

void main() {
  final parser = SmartHtmlParser();
  final serializer = SmartHtmlSerializer();

  group('Table HTML Parsing', () {
    test('parses simple table', () {
      const html = '<table><tr><td>A</td><td>B</td></tr>'
          '<tr><td>C</td><td>D</td></tr></table>';
      final doc = parser.parse(html);

      expect(doc.blocks.length, 1);
      expect(doc.blocks[0], isA<TableNode>());
      final table = doc.blocks[0] as TableNode;
      expect(table.rowCount, 2);
      expect(table.colCount, 2);
      expect(table.rows[0][0].plainText, 'A');
      expect(table.rows[0][1].plainText, 'B');
      expect(table.rows[1][0].plainText, 'C');
      expect(table.rows[1][1].plainText, 'D');
    });

    test('parses table with thead and tbody', () {
      const html = '<table>'
          '<thead><tr><th>Header1</th><th>Header2</th></tr></thead>'
          '<tbody><tr><td>Data1</td><td>Data2</td></tr></tbody>'
          '</table>';
      final doc = parser.parse(html);

      expect(doc.blocks.length, 1);
      final table = doc.blocks[0] as TableNode;
      expect(table.hasHeaderRow, true);
      expect(table.rowCount, 2);
      expect(table.rows[0][0].plainText, 'Header1');
      expect(table.rows[1][0].plainText, 'Data1');
    });

    test('parses inline formatting inside table cells', () {
      const html =
          '<table><tr><td><b>Bold</b> text</td><td><i>Italic</i></td></tr></table>';
      final doc = parser.parse(html);

      final table = doc.blocks[0] as TableNode;
      expect(table.rows[0][0].spans.length, greaterThanOrEqualTo(2));
      expect(table.rows[0][0].spans[0].isBold, true);
      expect(table.rows[0][0].spans[0].text, 'Bold');
      expect(table.rows[0][1].spans[0].isItalic, true);
    });

    test('parses cell alignment', () {
      const html =
          '<table><tr><td style="text-align: center">Centered</td></tr></table>';
      final doc = parser.parse(html);

      final table = doc.blocks[0] as TableNode;
      expect(table.rows[0][0].alignment, SmartTextAlign.center);
    });

    test('parses cell background color', () {
      const html =
          '<table><tr><td style="background-color: #ff0000">Red</td></tr></table>';
      final doc = parser.parse(html);

      final table = doc.blocks[0] as TableNode;
      expect(table.rows[0][0].backgroundColor, isNotNull);
    });

    test('parses table alongside other blocks', () {
      const html = '<p>Before</p>'
          '<table><tr><td>Cell</td></tr></table>'
          '<p>After</p>';
      final doc = parser.parse(html);

      expect(doc.blocks.length, 3);
      expect(doc.blocks[0], isA<ParagraphNode>());
      expect(doc.blocks[1], isA<TableNode>());
      expect(doc.blocks[2], isA<ParagraphNode>());
    });

    test('parses empty cells', () {
      const html = '<table><tr><td></td><td></td></tr></table>';
      final doc = parser.parse(html);

      final table = doc.blocks[0] as TableNode;
      expect(table.rows[0][0].plainText, '');
      expect(table.rows[0][1].plainText, '');
    });
  });

  group('Table HTML Serialization', () {
    test('serializes simple table', () {
      final table = TableNode.empty(rows: 2, cols: 2);
      table.rows[0][0].spans = [TextFormatSpan.plain('A')];
      table.rows[0][1].spans = [TextFormatSpan.plain('B')];
      table.rows[1][0].spans = [TextFormatSpan.plain('C')];
      table.rows[1][1].spans = [TextFormatSpan.plain('D')];

      final doc = Document(blocks: [table]);
      final html = serializer.serialize(doc);

      expect(html, contains('<table>'));
      expect(html, contains('<tr>'));
      expect(html, contains('<td>A</td>'));
      expect(html, contains('<td>B</td>'));
      expect(html, contains('<td>C</td>'));
      expect(html, contains('<td>D</td>'));
      expect(html, contains('</table>'));
    });

    test('serializes header row with th tags', () {
      final table = TableNode.empty(rows: 2, cols: 2);
      table.hasHeaderRow = true;
      table.rows[0][0].spans = [TextFormatSpan.plain('H1')];
      table.rows[0][1].spans = [TextFormatSpan.plain('H2')];

      final doc = Document(blocks: [table]);
      final html = serializer.serialize(doc);

      expect(html, contains('<th>H1</th>'));
      expect(html, contains('<th>H2</th>'));
    });

    test('serializes cell alignment', () {
      final table = TableNode.empty(rows: 1, cols: 1);
      table.rows[0][0].spans = [TextFormatSpan.plain('Center')];
      table.rows[0][0].alignment = SmartTextAlign.center;

      final doc = Document(blocks: [table]);
      final html = serializer.serialize(doc);

      expect(html, contains('text-align: center'));
    });

    test('serializes cell background color', () {
      final table = TableNode.empty(rows: 1, cols: 1);
      table.rows[0][0].spans = [TextFormatSpan.plain('Red')];
      table.rows[0][0].backgroundColor = const Color(0xFFFF0000);

      final doc = Document(blocks: [table]);
      final html = serializer.serialize(doc);

      expect(html, contains('background-color: #'));
    });

    test('serializes bold text in cells', () {
      final table = TableNode.empty(rows: 1, cols: 1);
      table.rows[0][0].spans = [
        TextFormatSpan(text: 'Bold', isBold: true),
      ];

      final doc = Document(blocks: [table]);
      final html = serializer.serialize(doc);

      expect(html, contains('<b>Bold</b>'));
    });

    test('round-trips simple table through parse/serialize', () {
      const html = '<table><tr><td>A</td><td>B</td></tr>'
          '<tr><td>C</td><td>D</td></tr></table>';
      final doc = parser.parse(html);
      final output = serializer.serialize(doc);

      expect(output, contains('<table>'));
      expect(output, contains('<td>A</td>'));
      expect(output, contains('<td>D</td>'));
    });

    test('serializes table alongside other blocks', () {
      final blocks = <BlockNode>[
        ParagraphNode(spans: [TextFormatSpan.plain('Before')]),
        TableNode.empty(rows: 1, cols: 1),
        ParagraphNode(spans: [TextFormatSpan.plain('After')]),
      ];
      final doc = Document(blocks: blocks);
      final html = serializer.serialize(doc);

      expect(html, contains('<p>Before</p>'));
      expect(html, contains('<table>'));
      expect(html, contains('<p>After</p>'));
    });
  });
}
