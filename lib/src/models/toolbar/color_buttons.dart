import 'toolbar_group.dart';

/// Color picker buttons (Text color, Highlight color)
class SmartColorButtons extends SmartToolbarGroup {
  final bool foregroundColor;
  final bool highlightColor;

  const SmartColorButtons({
    this.foregroundColor = true,
    this.highlightColor = true,
  });
}
