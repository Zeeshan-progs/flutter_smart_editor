import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_editor/src/core/document_controller.dart';
import 'package:flutter_smart_editor/src/core/document.dart';

void main() {
  test('toggleFormat applies bold to exactly the selected range', () {
    final controller = DocumentController();
    controller.document.blocks.clear();
    final block = ParagraphNode(spans: [TextFormatSpan(text: 'Hello World')]);
    controller.document.blocks.add(block);

    // Try to make "World" (index 6 to 11) bold
    controller.toggleFormat(0, 6, 11, 'bold');

    final spans = controller.document.blocks[0].spans;
    print('After formatting 6-11: $spans');

    expect(spans.length, 2);
    expect(spans[0].text, 'Hello ');
    expect(spans[0].isBold, false);

    expect(spans[1].text, 'World');
    expect(spans[1].isBold, true);
  });
}
