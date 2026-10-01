import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_editor/flutter_smart_editor.dart';
import 'package:flutter_smart_editor/src/core/document/document_controller.dart';

void main() {
  group('DocumentController Search Engine', () {
    late DocumentController controller;

    setUp(() {
      controller = DocumentController();
    });

    test('findMatches returns matches across multiple blocks', () {
      controller.document = Document(blocks: [
        ParagraphNode(spans: [TextFormatSpan(text: 'Flutter is awesome.')]),
        ParagraphNode(spans: [TextFormatSpan(text: 'Learn Flutter today.')]),
      ]);

      final matches = controller.findMatches(
        'Flutter',
        const SearchOptions(),
      );

      expect(matches.length, 2);
      expect(matches[0].blockIndex, 0);
      expect(matches[0].start, 0);
      expect(matches[0].end, 7);
      expect(matches[0].matchedText, 'Flutter');

      expect(matches[1].blockIndex, 1);
      expect(matches[1].start, 6);
      expect(matches[1].end, 13);
      expect(matches[1].matchedText, 'Flutter');
    });

    test('findMatches respects caseSensitive option', () {
      controller.document = Document(blocks: [
        ParagraphNode(spans: [TextFormatSpan(text: 'Flutter flutter FLUTTER')]),
      ]);

      final caseInsensitive = controller.findMatches(
        'flutter',
        const SearchOptions(matchCase: false),
      );
      expect(caseInsensitive.length, 3);

      final caseSensitive = controller.findMatches(
        'flutter',
        const SearchOptions(matchCase: true),
      );
      expect(caseSensitive.length, 1);
      expect(caseSensitive.first.matchedText, 'flutter');
      expect(caseSensitive.first.start, 8);
    });

    test('findMatches respects wholeWord option', () {
      controller.document = Document(blocks: [
        ParagraphNode(
            spans: [TextFormatSpan(text: 'cat catch concatenate cat')]),
      ]);

      final wholeWordMatches = controller.findMatches(
        'cat',
        const SearchOptions(wholeWord: true),
      );
      expect(wholeWordMatches.length, 2);
      expect(wholeWordMatches[0].start, 0);
      expect(wholeWordMatches[1].start, 22);
    });

    test('findMatches handles regex query and throws on invalid regex', () {
      controller.document = Document(blocks: [
        ParagraphNode(
            spans: [TextFormatSpan(text: 'Item 1, Item 42, Item 999')]),
      ]);

      final regexMatches = controller.findMatches(
        r'Item \d+',
        const SearchOptions(isRegex: true),
      );
      expect(regexMatches.length, 3);
      expect(regexMatches[0].matchedText, 'Item 1');
      expect(regexMatches[1].matchedText, 'Item 42');
      expect(regexMatches[2].matchedText, 'Item 999');

      expect(
        () => controller.findMatches(
            '[invalid', const SearchOptions(isRegex: true)),
        throwsFormatException,
      );
    });

    test('findMatches identifies hyperlink metadata', () {
      controller.document = Document(blocks: [
        ParagraphNode(spans: [
          TextFormatSpan(text: 'Visit '),
          TextFormatSpan(text: 'Flutter', linkUrl: 'https://flutter.dev'),
          TextFormatSpan(text: ' website'),
        ]),
      ]);

      final matches = controller.findMatches(
        'Flutter',
        const SearchOptions(),
      );
      expect(matches.length, 1);
      expect(matches[0].isLink, isTrue);
      expect(matches[0].linkUrl, 'https://flutter.dev');
    });

    test('findMatches works in TableNode cells', () {
      final table = TableNode.empty(rows: 2, cols: 2);
      table.getCell(0, 1).spans = [TextFormatSpan(text: 'Table Flutter')];
      table.getCell(1, 0).spans = [
        TextFormatSpan(text: 'Doc Flutter', linkUrl: 'https://docs.flutter.dev')
      ];

      controller.document = Document(blocks: [table]);

      final matches = controller.findMatches(
        'Flutter',
        const SearchOptions(),
      );
      expect(matches.length, 2);
      expect(matches[0].isTableCell, isTrue);
      expect(matches[0].row, 0);
      expect(matches[0].col, 1);

      expect(matches[1].isTableCell, isTrue);
      expect(matches[1].row, 1);
      expect(matches[1].col, 0);
      expect(matches[1].isLink, isTrue);
      expect(matches[1].linkUrl, 'https://docs.flutter.dev');
    });

    test('replaceMatch updates link display text while preserving linkUrl', () {
      controller.document = Document(blocks: [
        ParagraphNode(spans: [
          TextFormatSpan(text: 'Click '),
          TextFormatSpan(text: 'Flutter', linkUrl: 'https://flutter.dev'),
          TextFormatSpan(text: ' here'),
        ]),
      ]);

      final matches = controller.findMatches('Flutter', const SearchOptions());
      expect(matches.length, 1);

      controller.replaceMatch(
        matches.first,
        'Google Flutter',
        preserveLink: true,
      );

      final block = controller.document.blocks[0];
      expect(block.plainText, 'Click Google Flutter here');
      expect(block.spans.length, 3);
      expect(block.spans[1].text, 'Google Flutter');
      expect(block.spans[1].linkUrl, 'https://flutter.dev');
    });

    test(
        'replaceAllMatches updates all occurrences and restores via single undo',
        () {
      controller.document = Document(blocks: [
        ParagraphNode(
            spans: [TextFormatSpan(text: 'Apples and Apples and Apples')]),
      ]);

      final matches = controller.findMatches('Apples', const SearchOptions());
      expect(matches.length, 3);

      final replacedCount = controller.replaceAllMatches(matches, 'Oranges');
      expect(replacedCount, 3);

      final block = controller.document.blocks[0];
      expect(block.plainText, 'Oranges and Oranges and Oranges');

      // Undo should restore all occurrences in exactly 1 step!
      expect(controller.undoRedoManager.canUndo, isTrue);
      controller.undo();
      expect(controller.document.blocks[0].plainText,
          'Apples and Apples and Apples');
    });
  });
}
