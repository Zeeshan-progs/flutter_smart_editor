import 'package:flutter/material.dart';
import '../../../core/document/document_controller.dart';
import '../../../models/enums.dart';
import '../../../models/toolbar/toolbar_index.dart';
import '../../shared/toolbar_button.dart';

class HistoryButtonGroup extends StatelessWidget {
  const HistoryButtonGroup({
    super.key,
    required this.group,
    required this.onAction,
    required this.onSurface,
    required this.activeColor,
    required this.activeBg,
    required this.disabledColor,
    required this.enabled,
    required this.itemHeight,
    required this.buttonIconSize,
    required this.documentController,
  });

  final SmartOtherButtons group;
  final Function(SmartButtonType type, {dynamic value}) onAction;
  final Color onSurface;
  final Color activeColor;
  final Color activeBg;
  final Color disabledColor;
  final bool enabled;
  final double itemHeight;
  final double buttonIconSize;
  
  final DocumentController documentController;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];

    if (group.undo) {
      buttons.add(ToolbarButton(
        icon: Icons.undo_rounded,
        isActive: false,
        onPressed: () => onAction(SmartButtonType.undo),
        activeColor: activeColor,
        activeBg: activeBg,
        onSurface: onSurface,
        disabledColor: disabledColor,
        enabled: enabled && documentController.canUndo,
        size: itemHeight,
        iconSize: buttonIconSize,
        tooltip: 'Undo',
      ));
    }

    if (group.redo) {
      buttons.add(ToolbarButton(
        icon: Icons.redo_rounded,
        isActive: false,
        onPressed: () => onAction(SmartButtonType.redo),
        activeColor: activeColor,
        activeBg: activeBg,
        onSurface: onSurface,
        disabledColor: disabledColor,
        enabled: enabled && documentController.canRedo,
        size: itemHeight,
        iconSize: buttonIconSize,
        tooltip: 'Redo',
      ));
    }

    if (group.copy) {
      buttons.add(ToolbarButton(
        icon: Icons.content_copy_rounded,
        isActive: false,
        onPressed: () => onAction(SmartButtonType.copy),
        activeColor: activeColor,
        activeBg: activeBg,
        onSurface: onSurface,
        disabledColor: disabledColor,
        enabled: enabled,
        size: itemHeight,
        iconSize: buttonIconSize - 2,
        tooltip: 'Copy',
      ));
    }

    if (group.paste) {
      buttons.add(ToolbarButton(
        icon: Icons.content_paste_rounded,
        isActive: false,
        onPressed: () => onAction(SmartButtonType.paste),
        activeColor: activeColor,
        activeBg: activeBg,
        onSurface: onSurface,
        disabledColor: disabledColor,
        enabled: enabled,
        size: itemHeight,
        iconSize: buttonIconSize - 2,
        tooltip: 'Paste',
      ));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: buttons,
    );
  }
}
