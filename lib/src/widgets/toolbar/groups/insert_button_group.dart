import 'package:flutter/material.dart';
import '../../../models/enums.dart';
import '../../../models/toolbar/toolbar_index.dart';
import '../inputs/table_grid_picker.dart';

/// Toolbar button group for inserting elements (Hyperlinks, Tables, etc.).
class InsertButtonGroup extends StatelessWidget {
  const InsertButtonGroup({
    super.key,
    required this.group,
    required this.onAction,
    required this.onSurface,
    required this.activeColor,
    required this.activeBg,
    required this.disabledColor,
    required this.enabled,
    this.isInsideTable = false,
    this.isLinkActive = false,
    this.itemHeight = 40.0,
    this.buttonIconSize = 18.0,
    this.isDarkMode = false,
  });

  final SmartInsertButtons group;
  final Function(SmartButtonType type, {dynamic value}) onAction;
  final Color onSurface;
  final Color activeColor;
  final Color activeBg;
  final Color disabledColor;
  final bool enabled;
  final bool isInsideTable;
  final bool isLinkActive;
  final double itemHeight;
  final double buttonIconSize;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];

    // ── Insert Link ──
    if (group.link) {
      buttons.add(_InsertLinkButton(
        onAction: onAction,
        onSurface: onSurface,
        activeColor: activeColor,
        activeBg: activeBg,
        disabledColor: disabledColor,
        enabled: enabled,
        isActive: isLinkActive,
        itemHeight: itemHeight,
        buttonIconSize: buttonIconSize,
      ));
    }

    // ── Insert Table ──
    if (group.table) {
      buttons.add(_InsertTableButton(
        onAction: onAction,
        onSurface: onSurface,
        disabledColor: disabledColor,
        enabled: enabled,
        itemHeight: itemHeight,
        buttonIconSize: buttonIconSize,
        isDarkMode: isDarkMode,
      ));

      if (isInsideTable) {
        buttons.add(_TableMoreMenu(
          onAction: onAction,
          onSurface: onSurface,
          disabledColor: disabledColor,
          enabled: enabled,
          itemHeight: itemHeight,
          buttonIconSize: buttonIconSize,
          isDarkMode: isDarkMode,
        ));
      }
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Row(mainAxisSize: MainAxisSize.min, children: buttons);
  }
}

/// The "Insert Link" button.
class _InsertLinkButton extends StatelessWidget {
  const _InsertLinkButton({
    required this.onAction,
    required this.onSurface,
    required this.activeColor,
    required this.activeBg,
    required this.disabledColor,
    required this.enabled,
    required this.isActive,
    required this.itemHeight,
    required this.buttonIconSize,
  });

  final Function(SmartButtonType type, {dynamic value}) onAction;
  final Color onSurface;
  final Color activeColor;
  final Color activeBg;
  final Color disabledColor;
  final bool enabled;
  final bool isActive;
  final double itemHeight;
  final double buttonIconSize;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? (isActive ? activeColor : onSurface)
        : disabledColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Tooltip(
        message: isActive ? 'Edit Link' : 'Insert Link',
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: enabled ? () => onAction(SmartButtonType.insertLink) : null,
          child: Container(
            width: itemHeight,
            height: itemHeight,
            decoration: BoxDecoration(
              color: isActive ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.link,
              size: buttonIconSize,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Insert Table" button that opens a bottom sheet grid picker.
class _InsertTableButton extends StatelessWidget {
  const _InsertTableButton({
    required this.onAction,
    required this.onSurface,
    required this.disabledColor,
    required this.enabled,
    required this.itemHeight,
    required this.buttonIconSize,
    required this.isDarkMode,
  });

  final Function(SmartButtonType type, {dynamic value}) onAction;
  final Color onSurface;
  final Color disabledColor;
  final bool enabled;
  final double itemHeight;
  final double buttonIconSize;
  final bool isDarkMode;

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => TableGridPicker(
        onSelect: (rows, cols) {
          onAction(SmartButtonType.insertTable, value: {'rows': rows, 'cols': cols});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Tooltip(
        message: 'Insert Table',
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: enabled ? () => _showPicker(context) : null,
          child: SizedBox(
            width: itemHeight,
            height: itemHeight,
            child: Icon(
              Icons.table_chart_outlined,
              size: buttonIconSize,
              color: enabled ? onSurface : disabledColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// The "⋯" More menu for table-specific operations.
class _TableMoreMenu extends StatelessWidget {
  const _TableMoreMenu({
    required this.onAction,
    required this.onSurface,
    required this.disabledColor,
    required this.enabled,
    required this.itemHeight,
    required this.buttonIconSize,
    required this.isDarkMode,
  });

  final Function(SmartButtonType type, {dynamic value}) onAction;
  final Color onSurface;
  final Color disabledColor;
  final bool enabled;
  final double itemHeight;
  final double buttonIconSize;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: PopupMenuButton<SmartButtonType>(
        tooltip: 'Table Options',
        enabled: enabled,
        icon: Icon(
          Icons.more_horiz,
          size: buttonIconSize,
          color: enabled ? onSurface : disabledColor,
        ),
        onSelected: (type) {
          if (type == SmartButtonType.deleteTable) {
            _confirmDeleteTable(context);
          } else {
            onAction(type);
          }
        },
        itemBuilder: (ctx) => [
          PopupMenuItem(
            value: SmartButtonType.addRowAbove,
            child: Row(
              children: [
                Icon(Icons.arrow_upward, size: 18, color: onSurface),
                const SizedBox(width: 10),
                const Text('Insert Row Above'),
              ],
            ),
          ),
          PopupMenuItem(
            value: SmartButtonType.addRowBelow,
            child: Row(
              children: [
                Icon(Icons.arrow_downward, size: 18, color: onSurface),
                const SizedBox(width: 10),
                const Text('Insert Row Below'),
              ],
            ),
          ),
          PopupMenuItem(
            value: SmartButtonType.addColumnLeft,
            child: Row(
              children: [
                Icon(Icons.arrow_back, size: 18, color: onSurface),
                const SizedBox(width: 10),
                const Text('Insert Column Left'),
              ],
            ),
          ),
          PopupMenuItem(
            value: SmartButtonType.addColumnRight,
            child: Row(
              children: [
                Icon(Icons.arrow_forward, size: 18, color: onSurface),
                const SizedBox(width: 10),
                const Text('Insert Column Right'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: SmartButtonType.deleteRow,
            child: Row(
              children: [
                Icon(Icons.remove_circle_outline, size: 18, color: onSurface),
                const SizedBox(width: 10),
                const Text('Delete Row'),
              ],
            ),
          ),
          PopupMenuItem(
            value: SmartButtonType.deleteColumn,
            child: Row(
              children: [
                Icon(Icons.remove_circle_outline, size: 18, color: onSurface),
                const SizedBox(width: 10),
                const Text('Delete Column'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: SmartButtonType.deleteTable,
            child: Row(
              children: [
                Icon(Icons.delete_forever_outlined,
                    size: 18, color: Colors.red.shade400),
                const SizedBox(width: 10),
                Text('Delete Table',
                    style: TextStyle(color: Colors.red.shade400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTable(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Delete Table?'),
        content: const Text(
            'This will remove the entire table and all its content.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onAction(SmartButtonType.deleteTable);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Backwards-compatibility alias for TableButtonGroup.
typedef TableButtonGroup = InsertButtonGroup;
