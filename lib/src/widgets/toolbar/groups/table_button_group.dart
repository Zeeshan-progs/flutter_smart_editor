import 'package:flutter/material.dart';
import '../../../models/enums.dart';
import '../../../models/toolbar/toolbar_index.dart';
import '../inputs/table_grid_picker.dart';

/// Toolbar button group for table operations.
///
/// - When NOT inside a table: only shows "Insert Table" (grid picker).
/// - When INSIDE a table: shows "Insert Row ↓", "Insert Column →",
///   and a "more" menu with Delete Row / Delete Column / Delete Table.
class TableButtonGroup extends StatelessWidget {
  const TableButtonGroup({
    super.key,
    required this.group,
    required this.onAction,
    required this.onSurface,
    required this.activeColor,
    required this.activeBg,
    required this.disabledColor,
    required this.enabled,
    this.isInsideTable = false,
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
  final double itemHeight;
  final double buttonIconSize;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    if (!group.table) return const SizedBox.shrink();

    final buttons = <Widget>[];

    // ── Always visible: Insert Table (grid picker) ──
    buttons.add(_InsertTableButton(
      onAction: onAction,
      onSurface: onSurface,
      disabledColor: disabledColor,
      enabled: enabled,
      itemHeight: itemHeight,
      buttonIconSize: buttonIconSize,
      isDarkMode: isDarkMode,
    ));

    // ── Only when inside a table ──
    if (isInsideTable) {
      // More menu (Delete Row / Delete Column / Delete Table)
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

    return Row(mainAxisSize: MainAxisSize.min, children: buttons);
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
      builder: (ctx) {
        return SafeArea(
          child: TableGridPicker(
            isDarkMode: isDarkMode,
            onSelect: (rows, cols) {
              Navigator.of(ctx).pop();
              onAction(SmartButtonType.insertTable,
                  value: {'rows': rows, 'cols': cols});
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: itemHeight,
      height: itemHeight,
      child: IconButton(
        icon: Icon(Icons.grid_on,
            size: buttonIconSize, color: enabled ? onSurface : disabledColor),
        tooltip: 'Insert Table',
        onPressed: enabled ? () => _showPicker(context) : null,
        constraints:
            BoxConstraints.tightFor(width: itemHeight, height: itemHeight),
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

/// A "more" popup menu for delete operations inside a table.
/// Groups destructive actions behind a single button to keep
/// the toolbar clean.
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
    return SizedBox(
      width: itemHeight,
      height: itemHeight,
      child: PopupMenuButton<SmartButtonType>(
        icon: Icon(
          Icons.more_vert,
          size: buttonIconSize,
          color: enabled ? onSurface : disabledColor,
        ),
        tooltip: 'Table Options',
        enabled: enabled,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
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
            value: SmartButtonType.insertRow,
            child: Row(
              children: [
                Icon(Icons.add_box_outlined, size: 18, color: onSurface),
                const SizedBox(width: 10),
                const Text('Add Row Below'),
              ],
            ),
          ),
          PopupMenuItem(
            value: SmartButtonType.insertColumn,
            child: Row(
              children: [
                Icon(Icons.add_chart, size: 18, color: onSurface),
                const SizedBox(width: 10),
                const Text('Add Column Right'),
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
