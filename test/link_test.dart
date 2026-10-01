import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_editor/smart_editor_controller.dart';
import 'package:flutter_smart_editor/src/core/document/document.dart';
import 'package:flutter_smart_editor/src/core/document/document_controller.dart';
import 'package:flutter_smart_editor/src/core/infra/html_parser.dart';
import 'package:flutter_smart_editor/src/core/infra/html_serializer.dart';
import 'package:flutter_smart_editor/src/widgets/blocks/rich_text_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('DocumentController Link Operations', () {
    late DocumentController controller;

    setUp(() {
      controller = DocumentController();
    });

    test('applyLink applies URL to specified range in a paragraph', () {
      controller.document = Document(
        blocks: [
          ParagraphNode(spans: [TextFormatSpan(text: 'Hello World')])
        ],
      );

      // Apply link to "World" (offsets 6 to 11)
      controller.applyLink(0, 6, 11, 'https://flutter.dev');

      final block = controller.document.blocks[0];
      expect(block.spans.length, 2);
      expect(block.spans[0].text, 'Hello ');
      expect(block.spans[0].linkUrl, isNull);
      expect(block.spans[1].text, 'World');
      expect(block.spans[1].linkUrl, 'https://flutter.dev');
    });

    test('applyLink with null removes link URL from range', () {
      controller.document = Document(
        blocks: [
          ParagraphNode(spans: [
            TextFormatSpan(text: 'Hello '),
            TextFormatSpan(text: 'World', linkUrl: 'https://flutter.dev'),
          ])
        ],
      );

      // Remove link from "World"
      controller.applyLink(0, 6, 11, null);

      final block = controller.document.blocks[0];
      final linkInfo = controller.getLinkInfoAt(0, 6);
      expect(linkInfo['url'], isNull);
      expect(block.plainText, 'Hello World');
    });

    test('insertLink inserts a new link span at offset', () {
      controller.document = Document(
        blocks: [
          ParagraphNode(spans: [TextFormatSpan(text: 'Hello ')])
        ],
      );

      controller.insertLink(0, 6, 'Flutter', 'https://flutter.dev');

      final block = controller.document.blocks[0];
      expect(block.plainText, 'Hello Flutter');
      final linkInfo = controller.getLinkInfoAt(0, 7);
      expect(linkInfo['text'], 'Flutter');
      expect(linkInfo['url'], 'https://flutter.dev');
    });

    test('deleteText cleanly deletes across span boundaries without looping', () {
      controller.document = Document(
        blocks: [
          ParagraphNode(spans: [
            TextFormatSpan(text: 'ABC'),
            TextFormatSpan(text: 'DEF', linkUrl: 'https://example.com'),
            TextFormatSpan(text: 'GHI'),
          ])
        ],
      );

      // Delete 'CDE' (from index 2, length 3)
      controller.deleteText(0, 2, 3);

      final block = controller.document.blocks[0];
      expect(block.plainText, 'ABFGHI');
    });

    test('applyCellLink and insertCellLink in TableNode', () {
      final table = TableNode.empty(rows: 2, cols: 2);
      controller.document = Document(blocks: [table]);

      table.getCell(0, 0).spans = [TextFormatSpan(text: 'Cell 0-0')];
      controller.applyCellLink(0, 0, 0, 0, 4, 'https://table.cell');

      final cell = table.getCell(0, 0);
      expect(cell.spans.first.linkUrl, 'https://table.cell');
      expect(cell.spans.first.text, 'Cell');

      final cellInfo = controller.getCellLinkInfoAt(0, 0, 0, 1);
      expect(cellInfo['url'], 'https://table.cell');
    });
  });

  group('HTML Parser and Serializer Hyperlink roundtrip', () {
    final parser = SmartHtmlParser();
    final serializer = SmartHtmlSerializer();

    test('parses <a href="..."> into TextFormatSpan with linkUrl', () {
      const html = '<p>Visit <a href="https://flutter.dev">Flutter</a> today!</p>';
      final doc = parser.parse(html);

      final block = doc.blocks[0];
      expect(block.spans.length, 3);
      expect(block.spans[1].text, 'Flutter');
      expect(block.spans[1].linkUrl, 'https://flutter.dev');
    });

    test('serializes TextFormatSpan with linkUrl back into <a href="...">', () {
      final doc = Document(blocks: [
        ParagraphNode(spans: [
          TextFormatSpan(text: 'Visit '),
          TextFormatSpan(text: 'Flutter', linkUrl: 'https://flutter.dev'),
          TextFormatSpan(text: ' today!'),
        ])
      ]);

      final html = serializer.serialize(doc);
      expect(html, contains('<a href="https://flutter.dev">Flutter</a>'));
    });
  });

  group('SmartEditorController Link Methods', () {
    test('insertLink and getLinkInfo on document', () {
      final controller = SmartEditorController();
      controller.documentController.document = Document(
        blocks: [
          ParagraphNode(spans: [TextFormatSpan(text: 'Flutter Framework')])
        ],
      );

      // Select "Flutter" (offsets 0 to 7)
      const selection = TextSelection(baseOffset: 0, extentOffset: 7);
      final infoBefore = controller.getLinkInfo(
        blockIndex: 0,
        selection: selection,
      );
      expect(infoBefore['text'], 'Flutter');
      expect(infoBefore['url'], isNull);

      // Apply link
      controller.insertLink(
        'https://flutter.dev',
        'Flutter',
        blockIndex: 0,
        selection: selection,
      );

      final infoAfter = controller.getLinkInfo(
        blockIndex: 0,
        selection: selection,
      );
      expect(infoAfter['text'], 'Flutter');
      expect(infoAfter['url'], 'https://flutter.dev');

      // Edit display text from "Flutter" to "Google Flutter"
      controller.insertLink(
        'https://flutter.dev',
        'Google Flutter',
        blockIndex: 0,
        selection: selection,
      );

      final block = controller.document.blocks[0];
      expect(block.plainText, 'Google Flutter Framework');

      // Remove link
      controller.removeLink(
        blockIndex: 0,
        selection: const TextSelection(baseOffset: 0, extentOffset: 14),
      );

      final infoRemoved = controller.getLinkInfo(
        blockIndex: 0,
        selection: const TextSelection(baseOffset: 0, extentOffset: 14),
      );
      expect(infoRemoved['url'], isNull);
    });

    test('setLink and setCellLink atomically insert links and append space', () {
      final docCtrl = DocumentController();
      final table = TableNode.empty(rows: 2, cols: 2);
      docCtrl.document = Document(
        blocks: [
          ParagraphNode(spans: [TextFormatSpan(text: 'Hello')]),
          table,
        ],
      );

      // setLink replacing 'Hello' with 'Flutter'
      final cursorOffset = docCtrl.setLink(
        blockIndex: 0,
        start: 0,
        end: 5,
        text: 'Flutter',
        url: 'https://flutter.dev',
      );

      final block = docCtrl.document.blocks[0];
      expect(block.plainText, 'Flutter ');
      expect(block.spans.length, 2);
      expect(block.spans[0].text, 'Flutter');
      expect(block.spans[0].linkUrl, 'https://flutter.dev');
      expect(block.spans[1].text, ' ');
      expect(block.spans[1].linkUrl, isNull);
      expect(cursorOffset, 8); // after trailing space

      // setCellLink in Table
      final cellCursorOffset = docCtrl.setCellLink(
        blockIndex: 1,
        row: 0,
        col: 0,
        start: 0,
        end: 0,
        text: 'CellLink',
        url: 'https://example.com',
      );

      final cell = table.getCell(0, 0);
      expect(cell.plainText, 'CellLink ');
      expect(cell.spans.length, 2);
      expect(cell.spans[0].text, 'CellLink');
      expect(cell.spans[0].linkUrl, 'https://example.com');
      expect(cell.spans[1].text, ' ');
      expect(cell.spans[1].linkUrl, isNull);
      expect(cellCursorOffset, 9);
    });
  });

  group('SmartTextEditingController styling', () {
    testWidgets('buildTextSpan styles entire word test including last character when prepended with ZWSP', (tester) async {
      final controller = SmartTextEditingController(text: '\u200Btest ');
      controller.formatSpans = [
        TextFormatSpan(text: 'test', linkUrl: 'https://example.com'),
        TextFormatSpan.plain(' '),
      ];

      late TextSpan span;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              span = controller.buildTextSpan(
                context: context,
                withComposing: false,
              );
              return const SizedBox();
            },
          ),
        ),
      );

      final children = span.children!.cast<TextSpan>();
      expect(children.length, 3);
      // Span 0: ZWSP
      expect(children[0].text, '\u200B');
      // Span 1: Whole word 'test' with link style (underline + linkColor)
      expect(children[1].text, 'test');
      expect(children[1].style?.decoration, TextDecoration.underline);
      expect(children[1].style?.color, const Color(0xFF1E88E5));
      // Span 2: Trailing space with unlinked plain style
      expect(children[2].text, ' ');
      expect(children[2].style?.decoration, TextDecoration.none);
    });
  });
}

