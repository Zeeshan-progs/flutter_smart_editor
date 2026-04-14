import 'toolbar_group.dart';

/// Paragraph/Alignment buttons
class SmartParagraphButtons extends SmartToolbarGroup {
  final bool alignLeft;
  final bool alignCenter;
  final bool alignRight;
  final bool alignJustify;

  const SmartParagraphButtons({
    this.alignLeft = true,
    this.alignCenter = true,
    this.alignRight = true,
    this.alignJustify = true,
  });
}
