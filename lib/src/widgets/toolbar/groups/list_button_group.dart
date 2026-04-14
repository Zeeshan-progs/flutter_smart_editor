import 'package:flutter/material.dart';
import '../../../core/document/document_controller.dart';
import '../../../models/enums.dart';
import '../../../models/toolbar/toolbar_index.dart';
import '../../shared/toolbar_button.dart';
import 'bullet_style_picker.dart';

class ListButtonGroup extends StatelessWidget {
  const ListButtonGroup({
    super.key,
    required this.group,
    required this.isBulletList,
    required this.isOrderedList,
    required this.onAction,
    required this.onSurface,
    required this.activeColor,
    required this.activeBg,
    required this.disabledColor,
    required this.enabled,
    required this.itemHeight,
    required this.buttonIconSize,
    required this.documentController,
    required this.getFocusedBlockIndex,
    this.onFormatApplied,
  });

  final SmartListButtons group;
  final bool isBulletList;
  final bool isOrderedList;
  final Function(SmartButtonType type, {dynamic value}) onAction;
  final Color onSurface;
  final Color activeColor;
  final Color activeBg;
  final Color disabledColor;
  final bool enabled;
  final double itemHeight;
  final double buttonIconSize;
  
  final DocumentController documentController;
  final int Function() getFocusedBlockIndex;
  final VoidCallback? onFormatApplied;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];
    
    if (group.ul) {
      buttons.add(ToolbarButton(
        icon: Icons.format_list_bulleted,
        isActive: isBulletList,
        onPressed: () => onAction(SmartButtonType.bulletList),
        activeColor: activeColor,
        activeBg: activeBg,
        onSurface: onSurface,
        disabledColor: disabledColor,
        enabled: enabled,
        size: itemHeight,
        iconSize: buttonIconSize,
        tooltip: 'Bullet List',
      ));
    }

    if (group.listStyles && isBulletList) {
      buttons.add(ToolbarButton(
        icon: Icons.expand_circle_down_outlined,
        isActive: false,
        onPressed: () => BulletStylePicker.show(
          context,
          group: group,
          activeColor: activeColor,
          documentController: documentController,
          getFocusedBlockIndex: getFocusedBlockIndex,
          onFormatApplied: onFormatApplied,
        ),
        activeColor: activeColor,
        activeBg: activeBg,
        onSurface: onSurface,
        disabledColor: disabledColor,
        enabled: enabled,
        size: itemHeight,
        iconSize: buttonIconSize - 2,
        tooltip: 'Bullet Style',
      ));
    }

    if (group.ol) {
      buttons.add(ToolbarButton(
        icon: Icons.format_list_numbered,
        isActive: isOrderedList,
        onPressed: () => onAction(SmartButtonType.orderedList),
        activeColor: activeColor,
        activeBg: activeBg,
        onSurface: onSurface,
        disabledColor: disabledColor,
        enabled: enabled,
        size: itemHeight,
        iconSize: buttonIconSize,
        tooltip: 'Ordered List',
      ));
    }

    if (group.hr) {
      buttons.add(ToolbarButton(
        icon: Icons.horizontal_rule_rounded,
        isActive: false,
        onPressed: () => onAction(SmartButtonType.horizontalRule),
        activeColor: activeColor,
        activeBg: activeBg,
        onSurface: onSurface,
        disabledColor: disabledColor,
        enabled: enabled,
        size: itemHeight,
        iconSize: buttonIconSize,
        tooltip: 'Insert Divider',
      ));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: buttons,
    );
  }
}
