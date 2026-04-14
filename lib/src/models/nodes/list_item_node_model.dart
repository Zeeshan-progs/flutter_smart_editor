import '../../core/document/document.dart';
import '../enums.dart';

/// A list item block (`<li>`) inside an ordered or unordered list.
class ListItemNode extends BlockNode {
  /// Whether this is a bullet (unordered) or ordered list item
  final SmartListType listType;

  /// Nesting depth (0 = top level, 1 = one level in, etc.)
  final int depth;

  /// Custom bullet shape for unordered lists.
  final SmartBulletStyle? bulletStyle;

  ListItemNode({
    required this.listType,
    this.depth = 0,
    this.bulletStyle,
    super.id,
    super.spans,
    super.alignment,
    super.lineHeight,
  });

  @override
  String get tag => 'li';

  @override
  BlockType get blockType =>
      listType == SmartListType.bullet ? BlockType.bulletList : BlockType.orderedList;

  @override
  BlockNode deepCopy() => ListItemNode(
        listType: listType,
        depth: depth,
        bulletStyle: bulletStyle,
        id: id,
        spans: spans.map((s) => s.copyWith()).toList(),
        alignment: alignment,
        lineHeight: lineHeight,
      );

  ListItemNode copyWithDepth(int newDepth) => ListItemNode(
        listType: listType,
        depth: newDepth,
        bulletStyle: bulletStyle,
        id: id,
        spans: spans.map((s) => s.copyWith()).toList(),
        alignment: alignment,
        lineHeight: lineHeight,
      );

  ListItemNode copyWithBulletStyle(SmartBulletStyle? style) => ListItemNode(
        listType: listType,
        depth: depth,
        bulletStyle: style,
        id: id,
        spans: spans.map((s) => s.copyWith()).toList(),
        alignment: alignment,
        lineHeight: lineHeight,
      );
}
