import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/painting.dart';
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
      controller.toggleFormat(0, 0, 5, SmartButtonType.bold);

      // The first span(s) covering [0,5) should be bold
      final spans = controller.document.blocks[0].spans;
      expect(spans[0].isBold, true);
      expect(spans[0].text, 'Hello');
    });

    test('toggles bold off when already active', () {
      controller.document.blocks[0].spans = [
        TextFormatSpan(text: 'Hello', isBold: true),
      ];
      controller.toggleFormat(0, 0, 5, SmartButtonType.bold);

      expect(controller.document.blocks[0].spans[0].isBold, false);
    });

    test('gets format at offset', () {
      controller.document.blocks[0].spans = [
        TextFormatSpan(text: 'Hello', isBold: true, isItalic: true),
      ];

      final format = controller.getFormatAt(0, 2);
      expect(format[SmartButtonType.bold], true);
      expect(format[SmartButtonType.italic], true);
      expect(format[SmartButtonType.underline], false);
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

    test('undo when nothing to undo does nothing', () {
      controller.undo();
      expect(controller.document.blocks[0].plainText, '');
    });

    test('clear resets to empty document', () {
      controller.insertText(0, 0, 'Hello World');
      controller.clear();

      expect(controller.document.blocks.length, 1);
      expect(controller.document.blocks[0].plainText, '');
    });
  });

  group('Phase 2: Extended Formatting', () {
    test('applies font family to range', () {
      controller.insertText(0, 0, 'Hello World');
      controller.applyFormat(0, 0, 5, SmartButtonType.fontName, 'Roboto');

      final spans = controller.document.blocks[0].spans;
      expect(spans[0].fontFamily, 'Roboto');
      expect(spans[0].text, 'Hello');
      expect(spans[1].fontFamily, isNull);
    });

    test('applies font size to range', () {
      controller.insertText(0, 0, 'Hello World');
      controller.applyFormat(0, 0, 5, SmartButtonType.fontSize, 18.0);

      final spans = controller.document.blocks[0].spans;
      expect(spans[0].fontSize, 18.0);
      expect(spans[0].text, 'Hello');
    });

    test('applies foreground color to range', () {
      const testColor = Color(0xFFFF0000); // Red
      controller.insertText(0, 0, 'Hello World');
      controller.applyFormat(0, 0, 5, SmartButtonType.foregroundColor, testColor);

      final spans = controller.document.blocks[0].spans;
      expect(spans[0].foregroundColor, testColor);
    });

    test('clears foreground color on range when value is null', () {
      const testColor = Color(0xFFFF0000);
      controller.insertText(0, 0, 'Hello World');
      controller.applyFormat(0, 0, 5, SmartButtonType.foregroundColor, testColor);
      controller.applyFormat(0, 0, 5, SmartButtonType.foregroundColor, null);

      final spans = controller.document.blocks[0].spans;
      final helloSpan = spans.firstWhere((s) => s.text.startsWith('Hello'));
      expect(helloSpan.foregroundColor, isNull);
    });

    test('applies background color to range', () {
      const testColor = Color(0xFF00FF00); // Green
      controller.insertText(0, 0, 'Hello World');
      controller.applyFormat(0, 0, 5, SmartButtonType.highlightColor, testColor);

      final spans = controller.document.blocks[0].spans;
      expect(spans[0].backgroundColor, testColor);
    });

    test('sets block alignment', () {
      controller.setAlignment(0, SmartTextAlign.center);
      expect(controller.document.blocks[0].alignment, SmartTextAlign.center);

      controller.setAlignment(0, SmartTextAlign.right);
      expect(controller.document.blocks[0].alignment, SmartTextAlign.right);
    });

    test('sets block line height', () {
      controller.setLineHeight(0, 2.0);
      expect(controller.document.blocks[0].lineHeight, 2.0);

      controller.setLineHeight(0, null);
      expect(controller.document.blocks[0].lineHeight, isNull);
    });

    test('clears formatting on a range', () {
      // 1. Setup formatted text
      controller.document.blocks[0].spans = [
        TextFormatSpan(
          text: 'Hello World',
          isBold: true,
          fontSize: 20.0,
          fontFamily: 'Lato',
        ),
      ];

      // 2. Clear format for 'Hello'
      controller.clearFormat(0, 0, 5);

      final spans = controller.document.blocks[0].spans;
      // Should have 2 spans now: 'Hello' (plain) and ' World' (formatted)
      expect(spans.length, 2);
      expect(spans[0].text, 'Hello');
      expect(spans[0].isBold, false);
      expect(spans[0].fontSize, isNull);

      expect(spans[1].text, ' World');
      expect(spans[1].isBold, true);
      expect(spans[1].fontSize, 20.0);
    });
  });
}
