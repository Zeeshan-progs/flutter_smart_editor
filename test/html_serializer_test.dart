import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_editor/src/core/document/document.dart';
import 'package:flutter_smart_editor/src/core/infra/html_serializer.dart';
import 'package:flutter_smart_editor/src/core/infra/html_parser.dart';
import 'package:flutter_smart_editor/src/models/enums.dart';

void main() {
  late SmartHtmlSerializer serializer;
  late SmartHtmlParser parser;

  setUp(() {
    serializer = SmartHtmlSerializer();
    parser = SmartHtmlParser();
  });

  group('SmartHtmlSerializer', () {
    test('serializes empty paragraph', () {
      final doc = Document();
      final html = serializer.serialize(doc);
      expect(html, '<p></p>');
    });

    test('serializes simple paragraph', () {
      final doc = Document(blocks: [
        ParagraphNode(spans: [TextFormatSpan.plain('Hello World')]),
      ]);
      final html = serializer.serialize(doc);
      expect(html, '<p>Hello World</p>');
    });

    test('serializes bold text', () {
      final doc = Document(blocks: [
        ParagraphNode(spans: [TextFormatSpan(text: 'Bold', isBold: true)]),
      ]);
      final html = serializer.serialize(doc);
      expect(html, '<p><b>Bold</b></p>');
    });

    test('serializes italic text', () {
      final doc = Document(blocks: [
        ParagraphNode(spans: [TextFormatSpan(text: 'Italic', isItalic: true)]),
      ]);
      final html = serializer.serialize(doc);
      expect(html, '<p><i>Italic</i></p>');
    });

    test('serializes underline text', () {
      final doc = Document(blocks: [
        ParagraphNode(
            spans: [TextFormatSpan(text: 'Underline', isUnderline: true)]),
      ]);
      final html = serializer.serialize(doc);
      expect(html, '<p><u>Underline</u></p>');
    });

    test('serializes strikethrough text', () {
      final doc = Document(blocks: [
        ParagraphNode(
            spans: [TextFormatSpan(text: 'Strike', isStrikethrough: true)]),
      ]);
      final html = serializer.serialize(doc);
      expect(html, '<p><s>Strike</s></p>');
    });

    test('serializes bold + italic', () {
      final doc = Document(blocks: [
        ParagraphNode(spans: [
          TextFormatSpan(text: 'BoldItalic', isBold: true, isItalic: true)
        ]),
      ]);
      final html = serializer.serialize(doc);
      expect(html, '<p><b><i>BoldItalic</i></b></p>');
    });

    test('serializes heading', () {
      final doc = Document(blocks: [
        HeadingNode(level: 2, spans: [TextFormatSpan.plain('Title')]),
      ]);
      final html = serializer.serialize(doc);
      expect(html, '<h2>Title</h2>');
    });

    test('serializes text alignment', () {
      final doc = Document(blocks: [
        ParagraphNode(
          spans: [TextFormatSpan.plain('Centered')],
          alignment: SmartTextAlign.center,
        ),
      ]);
      final html = serializer.serialize(doc);
      expect(html, '<p style="text-align: center">Centered</p>');
    });

    test('serializes mixed content', () {
      final doc = Document(blocks: [
        ParagraphNode(spans: [
          TextFormatSpan.plain('Hello '),
          TextFormatSpan(text: 'World', isBold: true),
          TextFormatSpan.plain('!'),
        ]),
      ]);
      final html = serializer.serialize(doc);
      expect(html, '<p>Hello <b>World</b>!</p>');
    });

    test('escapes HTML special characters', () {
      final doc = Document(blocks: [
        ParagraphNode(spans: [TextFormatSpan.plain('a < b & c > d')]),
      ]);
      final html = serializer.serialize(doc);
      expect(html, '<p>a &lt; b &amp; c &gt; d</p>');
    });

    test('serializes link', () {
      final doc = Document(blocks: [
        ParagraphNode(spans: [
          TextFormatSpan(text: 'Google', linkUrl: 'https://google.com'),
        ]),
      ]);
      final html = serializer.serialize(doc);
      expect(html, '<p><a href="https://google.com">Google</a></p>');
    });
  });

  group('Roundtrip: parse → serialize', () {
    test('simple paragraph roundtrip', () {
      const original = '<p>Hello World</p>';
      final doc = parser.parse(original);
      final result = serializer.serialize(doc);
      expect(result, original);
    });

    test('bold text roundtrip', () {
      const original = '<p>Hello <b>World</b></p>';
      final doc = parser.parse(original);
      final result = serializer.serialize(doc);
      expect(result, original);
    });

    test('heading roundtrip', () {
      const original = '<h1>Title</h1>';
      final doc = parser.parse(original);
      final result = serializer.serialize(doc);
      expect(result, original);
    });

    test('mixed content roundtrip', () {
      const original = '<p>Hello <b>Bold</b> and <i>Italic</i> text</p>';
      final doc = parser.parse(original);
      final result = serializer.serialize(doc);
      expect(result, original);
    });
  });

  group('SmartHtmlSerializer - Interception', () {
    test('intercepts and replaces tags', () {
      final customSerializer = SmartHtmlSerializer(
        onTagSerialize: (type, tag, attributes, styles, content) {
          if (type == SmartTagType.bold) {
            return '<strong>$content</strong>';
          }
          return null;
        },
      );

      final doc = Document(blocks: [
        ParagraphNode(spans: [
          TextFormatSpan.plain('Hello '),
          TextFormatSpan(text: 'World', isBold: true),
        ]),
      ]);

      final html = customSerializer.serialize(doc);
      expect(html, '<p>Hello <strong>World</strong></p>');
    });

    test('modifies styles map for a tag', () {
      final customSerializer = SmartHtmlSerializer(
        onTagSerialize: (type, tag, attributes, styles, content) {
          if (type == SmartTagType.bold) {
            styles['color'] = 'blue';
            return null; // Return null to use the modified styles map
          }
          return null;
        },
      );

      final doc = Document(blocks: [
        ParagraphNode(spans: [
          TextFormatSpan(text: 'BlueBold', isBold: true),
        ]),
      ]);

      final html = customSerializer.serialize(doc);
      expect(html, '<p><b style="color: blue">BlueBold</b></p>');
    });

    test('intercepts and replaces block tags', () {
      final customSerializer = SmartHtmlSerializer(
        onTagSerialize: (type, tag, attributes, styles, content) {
          if (type == SmartTagType.block && tag == 'p') {
            return '<div class="para">$content</div>';
          }
          return null;
        },
      );

      final doc = Document(blocks: [
        ParagraphNode(spans: [TextFormatSpan.plain('Paragraph text')]),
      ]);

      final html = customSerializer.serialize(doc);
      expect(html, '<div class="para">Paragraph text</div>');
    });

    test('intercepts nested tags properly', () {
      final customSerializer = SmartHtmlSerializer(
        onTagSerialize: (type, tag, attributes, styles, content) {
          if (type == SmartTagType.bold) {
            return '<strong class="b">$content</strong>';
          }
          if (type == SmartTagType.italic) {
            return '<em class="i">$content</em>';
          }
          return null;
        },
      );

      final doc = Document(blocks: [
        ParagraphNode(spans: [
          TextFormatSpan(text: 'Nested', isBold: true, isItalic: true),
        ]),
      ]);

      final html = customSerializer.serialize(doc);
      expect(html, '<p><strong class="b"><em class="i">Nested</em></strong></p>');
    });
  });
}
