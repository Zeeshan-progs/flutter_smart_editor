import '../../core/document/document.dart';
import '../enums.dart';

/// A horizontal rule block (`<hr>`).
class HorizontalRuleNode extends BlockNode {
  HorizontalRuleNode({super.id})
      : super(spans: [TextFormatSpan.plain('')]);

  @override
  String get tag => 'hr';

  @override
  BlockType get blockType => BlockType.horizontalRule;

  @override
  BlockNode deepCopy() => HorizontalRuleNode(id: id);
}
