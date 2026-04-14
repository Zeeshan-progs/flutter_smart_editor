import 'package:flutter/material.dart';
import '../../../models/enums.dart';
import '../../../models/toolbar/toolbar_index.dart';
import '../inputs/color_picker_button.dart';

class ColorButtonGroup extends StatelessWidget {
  const ColorButtonGroup({
    super.key,
    required this.group,
    required this.activeFormats,
    required this.onAction,
    required this.onSurface,
    required this.activeColor,
    required this.activeBg,
    required this.disabledColor,
    required this.enabled,
  });

  final SmartColorButtons group;
  final Map<SmartButtonType, dynamic> activeFormats;
  final Function(SmartButtonType type, {dynamic value}) onAction;
  final Color onSurface;
  final Color activeColor;
  final Color activeBg;
  final Color disabledColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];
    
    if (group.foregroundColor) {
      buttons.add(ColorPickerButton(
        icon: Icons.format_color_text,
        currentColor: activeFormats[SmartButtonType.foregroundColor] as Color?,
        tooltip: 'Text Color',
        enabled: enabled,
        onColorChanged: (color) =>
            onAction(SmartButtonType.foregroundColor, value: color),
      ));
    }
    
    if (group.highlightColor) {
      buttons.add(ColorPickerButton(
        icon: Icons.color_lens,
        currentColor: activeFormats[SmartButtonType.highlightColor] as Color?,
        tooltip: 'Highlight Color',
        enabled: enabled,
        onColorChanged: (color) =>
            onAction(SmartButtonType.highlightColor, value: color),
      ));
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: buttons,
    );
  }
}
