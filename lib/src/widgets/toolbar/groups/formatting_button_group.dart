import 'package:flutter/material.dart';
import '../../../models/enums.dart';
import '../../../models/toolbar/toolbar_index.dart';
import '../../shared/toolbar_button.dart';
import '../inputs/font_size_picker_button.dart';

class FormattingButtonGroup extends StatelessWidget {
  const FormattingButtonGroup({
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

  final SmartFontButtons group;
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
    
    if (group.bold) {
      buttons.add(ToolbarButton(
          icon: Icons.format_bold,
          isActive: activeFormats[SmartButtonType.bold] == true,
          onPressed: () => onAction(SmartButtonType.bold),
          activeColor: activeColor,
          activeBg: activeBg,
          onSurface: onSurface,
          disabledColor: disabledColor,
          enabled: enabled,
          size: itemHeight,
          iconSize: buttonIconSize,
          tooltip: 'Bold'));
    }
    
    if (group.italic) {
      buttons.add(ToolbarButton(
          icon: Icons.format_italic,
          isActive: activeFormats[SmartButtonType.italic] == true,
          onPressed: () => onAction(SmartButtonType.italic),
          activeColor: activeColor,
          activeBg: activeBg,
          onSurface: onSurface,
          disabledColor: disabledColor,
          enabled: enabled,
          size: itemHeight,
          iconSize: buttonIconSize,
          tooltip: 'Italic'));
    }
    
    if (group.underline) {
      buttons.add(ToolbarButton(
          icon: Icons.format_underlined,
          isActive: activeFormats[SmartButtonType.underline] == true,
          onPressed: () => onAction(SmartButtonType.underline),
          activeColor: activeColor,
          activeBg: activeBg,
          onSurface: onSurface,
          disabledColor: disabledColor,
          enabled: enabled,
          size: itemHeight,
          iconSize: buttonIconSize,
          tooltip: 'Underline'));
    }
    
    if (group.strikethrough) {
      buttons.add(ToolbarButton(
          icon: Icons.format_strikethrough,
          isActive: activeFormats[SmartButtonType.strikethrough] == true,
          onPressed: () => onAction(SmartButtonType.strikethrough),
          activeColor: activeColor,
          activeBg: activeBg,
          onSurface: onSurface,
          disabledColor: disabledColor,
          enabled: enabled,
          size: itemHeight,
          iconSize: buttonIconSize,
          tooltip: 'Strikethrough'));
    }
    
    if (group.fontSize) {
      buttons.add(FontSizePickerButton(
        currentSize: activeFormats[SmartButtonType.fontSize] as double? ?? 12,
        enabled: enabled,
        activeColor: activeColor,
        tooltip: "Font Size",
        onSizeChanged: (size) => onAction(SmartButtonType.fontSize, value: size),
      ));
    }
    
    if (group.clearAll) {
      buttons.add(ToolbarButton(
          icon: Icons.format_clear,
          isActive: false,
          onPressed: () => onAction(SmartButtonType.clearFormatting),
          activeColor: activeColor,
          activeBg: activeBg,
          onSurface: onSurface,
          disabledColor: disabledColor,
          enabled: enabled,
          size: itemHeight,
          iconSize: buttonIconSize,
          tooltip: 'Clear Formatting'));
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: buttons,
    );
  }
}
