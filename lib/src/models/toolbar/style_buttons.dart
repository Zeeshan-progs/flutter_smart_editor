import '../enums.dart';
import 'toolbar_group.dart';

/// Style dropdown group (paragraph style: H1, H2, ..., Normal)
class SmartStyleButtons extends SmartToolbarGroup {
  final bool style;
  final List<BlockType> options;

  const SmartStyleButtons({
    this.style = true,
    this.options = const [
      BlockType.heading1,
      BlockType.heading2,
      BlockType.heading3,
      BlockType.heading4,
      BlockType.heading5,
      BlockType.heading6,
      BlockType.paragraph,
    ],
  });
}
