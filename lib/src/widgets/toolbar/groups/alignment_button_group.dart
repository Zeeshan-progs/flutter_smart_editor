import 'package:flutter/material.dart';
import '../../../models/enums.dart';
import '../../../models/toolbar/toolbar_index.dart';
import '../../shared/toolbar_button.dart';

class AlignmentButtonGroup extends StatelessWidget {
  const AlignmentButtonGroup({
    super.key,
    required this.group,
    required this.activeFormats,
    required this.onAction,
    required this.onSurface,
    required this.activeColor,
    required this.activeBg,
    required this.disabledColor,
    required this.enabled,
    required this.itemHeight,
    required this.buttonIconSize,
  });

  final SmartParagraphButtons group;
  final Map<SmartButtonType, dynamic> activeFormats;
  final Function(SmartButtonType type, {dynamic value}) onAction;
  final Color onSurface;
  final Color activeColor;
  final Color activeBg;
  final Color disabledColor;
  final bool enabled;
  final double itemHeight;
  final double buttonIconSize;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];
    
    if (group.alignLeft) {
      buttons.add(ToolbarButton(
          icon: Icons.format_align_left,
          isActive: activeFormats[SmartButtonType.alignLeft] == true,
          onPressed: () => onAction(SmartButtonType.alignLeft,
              value: SmartTextAlign.left),
          activeColor: activeColor,
          activeBg: activeBg,
          onSurface: onSurface,
          disabledColor: disabledColor,
          enabled: enabled,
          size: itemHeight,
          iconSize: buttonIconSize,
          tooltip: 'Align Left'));
    }
    
    if (group.alignCenter) {
      buttons.add(ToolbarButton(
          icon: Icons.format_align_center,
          isActive: activeFormats[SmartButtonType.alignCenter] == true,
          onPressed: () => onAction(SmartButtonType.alignCenter,
              value: SmartTextAlign.center),
          activeColor: activeColor,
          activeBg: activeBg,
          onSurface: onSurface,
          disabledColor: disabledColor,
          enabled: enabled,
          size: itemHeight,
          iconSize: buttonIconSize,
          tooltip: 'Align Center'));
    }
    
    if (group.alignRight) {
      buttons.add(ToolbarButton(
          icon: Icons.format_align_right,
          isActive: activeFormats[SmartButtonType.alignRight] == true,
          onPressed: () => onAction(SmartButtonType.alignRight,
              value: SmartTextAlign.right),
          activeColor: activeColor,
          activeBg: activeBg,
          onSurface: onSurface,
          disabledColor: disabledColor,
          enabled: enabled,
          size: itemHeight,
          iconSize: buttonIconSize,
          tooltip: 'Align Right'));
    }
    
    if (group.alignJustify) {
      buttons.add(ToolbarButton(
          icon: Icons.format_align_justify,
          isActive: activeFormats[SmartButtonType.alignJustify] == true,
          onPressed: () => onAction(SmartButtonType.alignJustify,
              value: SmartTextAlign.justify),
          activeColor: activeColor,
          activeBg: activeBg,
          onSurface: onSurface,
          disabledColor: disabledColor,
          enabled: enabled,
          size: itemHeight,
          iconSize: buttonIconSize,
          tooltip: 'Align Justify'));
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: buttons,
    );
  }
}
