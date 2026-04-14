import '../enums.dart';
import 'toolbar_group.dart';

/// List buttons (Bullet list, Numbered list, Horizontal Rule)
class SmartListButtons extends SmartToolbarGroup {
  final bool ul;
  final bool ol;
  final bool hr;
  final bool listStyles;
  final List<SmartBulletStyle>? availableStyles;

  const SmartListButtons({
    this.ul = true,
    this.ol = true,
    this.hr = true,
    this.listStyles = true,
    this.availableStyles,
  });
}
