import '../../core/document/document.dart';
import '../enums.dart';

/// A paragraph block (`<p>`)
class ParagraphNode extends BlockNode {
  ParagraphNode({
    super.id,
    super.spans,
    super.alignment,
    super.lineHeight,
  });

  @override
  String get tag => 'p';

  @override
  BlockType get blockType => BlockType.paragraph;

  @override
  BlockNode deepCopy() => ParagraphNode(
        id: id,
        spans: spans.map((s) => s.copyWith()).toList(),
        alignment: alignment,
        lineHeight: lineHeight,
      );
}
