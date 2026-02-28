import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_editor/src/core/document.dart';
import 'package:flutter_smart_editor/src/core/document_controller.dart';
import 'package:flutter_smart_editor/src/models/enums.dart';

void main() {
  late DocumentController controller;

  setUp(() {
    controller = DocumentController();
  });

  group('Text insertion', () {
    test('inserts text into empty document', () {
      controller.insertText(0, 0, 'Hello');
      expect(controller.document.blocks[0].plainText, 'Hello');
    });

    test('inserts text at the end', () {
      controller.insertText(0, 0, 'Hello');
      controller.insertText(0, 5, ' World');
      expect(controller.document.blocks[0].plainText, 'Hello World');
    });

    test('inserts text in the middle', () {
      controller.insertText(0, 0, 'Hello World');
      controller.insertText(0, 5, ' Beautiful');
      expect(controller.document.blocks[0].plainText, 'Hello Beautiful World');
    });
  });

  group('Text deletion', () {
    test('deletes text from block', () {
      controller.insertText(0, 0, 'Hello World');
      controller.deleteText(0, 5, 6); // delete " World"
      expect(controller.document.blocks[0].plainText, 'Hello');
    });

    test('deletes single character', () {
      controller.insertText(0, 0, 'Hello');
      controller.deleteText(0, 4, 1); // delete "o"
      expect(controller.document.blocks[0].plainText, 'Hell');
    });
  });

  group('Block splitting', () {
    test('splits block at cursor', () {
      controller.insertText(0, 0, 'Hello World');
      controller.splitBlock(0, 5);

      expect(controller.document.blocks.length, 2);
      expect(controller.document.blocks[0].plainText, 'Hello');
      expect(controller.document.blocks[1].plainText, ' World');
    });

    test('splits at start creates empty block above', () {
      controller.insertText(0, 0, 'Hello');
      controller.splitBlock(0, 0);

      expect(controller.document.blocks.length, 2);
      expect(controller.document.blocks[0].plainText, '');
      expect(controller.document.blocks[1].plainText, 'Hello');
    });

    test('splits at end creates empty block below', () {
      controller.insertText(0, 0, 'Hello');
      controller.splitBlock(0, 5);

      expect(controller.document.blocks.length, 2);
      expect(controller.document.blocks[0].plainText, 'Hello');
      expect(controller.document.blocks[1].plainText, '');
    });
  });

  group('Block merging', () {
    test('merges two blocks', () {
      controller.insertText(0, 0, 'Hello');
      controller.splitBlock(0, 5);
      controller.insertText(1, 0, ' World');

      final cursorOffset = controller.mergeWithPrevious(1);

      expect(controller.document.blocks.length, 1);
      expect(controller.document.blocks[0].plainText, 'Hello World');
      expect(cursorOffset, 5);
    });
  });

  group('Formatting', () {
    test('toggles bold on a range', () {
      controller.insertText(0, 0, 'Hello World');
      controller.toggleFormat(0, 0, 5, 'bold');

      // The first span(s) covering [0,5) should be bold
      final spans = controller.document.blocks[0].spans;
      expect(spans[0].isBold, true);
      expect(spans[0].text, 'Hello');
    });

    test('toggles bold off when already active', () {
      controller.document.blocks[0].spans = [
        TextFormatSpan(text: 'Hello', isBold: true),
      ];
      controller.toggleFormat(0, 0, 5, 'bold');

      expect(controller.document.blocks[0].spans[0].isBold, false);
    });

    test('gets format at offset', () {
      controller.document.blocks[0].spans = [
        TextFormatSpan(text: 'Hello', isBold: true, isItalic: true),
      ];

      final format = controller.getFormatAt(0, 2);
      expect(format['bold'], true);
      expect(format['italic'], true);
      expect(format['underline'], false);
    });
  });

  group('Block type changes', () {
    test('changes paragraph to heading', () {
      controller.insertText(0, 0, 'Title');
      controller.changeBlockType(0, BlockType.heading1);

      expect(controller.document.blocks[0], isA<HeadingNode>());
      expect((controller.document.blocks[0] as HeadingNode).level, 1);
      expect(controller.document.blocks[0].plainText, 'Title');
    });

    test('changes heading to paragraph', () {
      controller.document.blocks[0] =
          HeadingNode(level: 2, spans: [TextFormatSpan.plain('Title')]);

      controller.changeBlockType(0, BlockType.paragraph);
      expect(controller.document.blocks[0], isA<ParagraphNode>());
    });
  });

  group('Undo/Redo', () {
    test('undoes the last action', () {
      controller.insertText(0, 0, 'Hello');
      controller.insertText(0, 5, ' World');

      controller.undo();
      expect(controller.document.blocks[0].plainText, 'Hello');
    });

    test('redoes the last undone action', () {
      controller.insertText(0, 0, 'Hello');
      controller.insertText(0, 5, ' World');

      controller.undo();
      controller.redo();
      expect(controller.document.blocks[0].plainText, 'Hello World');
    });

    test('undo when nothing to undo returns false', () {
      final result = controller.undo();
      expect(result, false);
    });

    test('clear resets to empty document', () {
      controller.insertText(0, 0, 'Hello World');
      controller.clear();

      expect(controller.document.blocks.length, 1);
      expect(controller.document.blocks[0].plainText, '');
    });
  });
}
