import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_editor/flutter_smart_editor.dart';
import 'package:flutter_smart_editor/src/core/html_serializer.dart';

void main() {
  test('Modifying styles map without returning custom string', () {
    final serializer = SmartHtmlSerializer(
      onTagSerialize: (type, tag, attributes, styles, content) {
        if (type == SmartTagType.bold) {
          styles['color'] = 'blue';
          styles['font-weight'] = '900';
          return null; // Let the serializer handle it with modified styles
        }
        return null;
      },
    );

    final document = Document(blocks: [
      ParagraphNode(
        spans: [
          TextFormatSpan(text: 'Bold Text', isBold: true),
        ],
      ),
    ]);

    final html = serializer.serialize(document);
    // By default, bold is <b>. Our interceptor added styles, so it should become <b style="...">
    expect(html, contains('<b style="color: blue; font-weight: 900">Bold Text</b>'));
  });

  test('Overriding tag and styles manually', () {
    final serializer = SmartHtmlSerializer(
      onTagSerialize: (type, tag, attributes, styles, content) {
        if (type == SmartTagType.block && tag == 'p') {
          return '<div class="para">$content</div>';
        }
        return null;
      },
    );

    final document = Document(blocks: [
      ParagraphNode(
        spans: [TextFormatSpan.plain('Paragraph')],
      ),
    ]);

    final html = serializer.serialize(document);
    expect(html, contains('<div class="para">Paragraph</div>'));
  });
}
