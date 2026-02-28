import 'package:flutter_smart_editor/src/core/html_parser.dart';

void main() {
  final parser = SmartHtmlParser();
  final doc = parser.parse(
      '<p>This is <b>bold</b> text, and this is <strong>important</strong> text.</p>');

  for (final block in doc.blocks) {
    print('Block: ${block.runtimeType}');
    for (final span in block.spans) {
      print('  Span: "${span.text}" (bold: ${span.isBold})');
    }
  }
}
