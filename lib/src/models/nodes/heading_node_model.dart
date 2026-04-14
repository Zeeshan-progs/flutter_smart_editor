import '../../core/document/document.dart';
import '../enums.dart';

/// A heading block (`<h1>` through `<h6>`)
class HeadingNode extends BlockNode {
  final int level;

  HeadingNode({
    required this.level,
    super.id,
    super.spans,
    super.alignment,
    super.lineHeight,
  }) : assert(level >= 1 && level <= 6);

  @override
  String get tag => 'h$level';

  @override
  BlockType get blockType {
    switch (level) {
      case 1: return BlockType.heading1;
      case 2: return BlockType.heading2;
      case 3: return BlockType.heading3;
      case 4: return BlockType.heading4;
      case 5: return BlockType.heading5;
      case 6: return BlockType.heading6;
      default: return BlockType.heading1;
    }
  }

  @override
  BlockNode deepCopy() => HeadingNode(
        level: level,
        id: id,
        spans: spans.map((s) => s.copyWith()).toList(),
        alignment: alignment,
        lineHeight: lineHeight,
      );
}
