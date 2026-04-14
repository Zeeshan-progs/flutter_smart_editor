import 'package:flutter/material.dart';
import '../../../models/enums.dart';
import '../../../models/toolbar/toolbar_index.dart';
import '../../shared/toolbar_chip.dart';

class StylePickerButton extends StatelessWidget {
  const StylePickerButton({
    super.key,
    required this.group,
    required this.currentBlockType,
    required this.onStyleChanged,
    required this.onSurface,
    required this.activeColor,
    required this.disabledColor,
    required this.enabled,
    required this.itemHeight,
  });

  final SmartStyleButtons group;
  final BlockType currentBlockType;
  final ValueChanged<BlockType> onStyleChanged;
  final Color onSurface;
  final Color activeColor;
  final Color disabledColor;
  final bool enabled;
  final double itemHeight;

  static const _styleOnlyTypes = {
    BlockType.paragraph,
    BlockType.heading1,
    BlockType.heading2,
    BlockType.heading3,
    BlockType.heading4,
    BlockType.heading5,
    BlockType.heading6,
  };

  String _blockTypeLabel(BlockType type) {
    switch (type) {
      case BlockType.paragraph:
        return 'Normal';
      case BlockType.heading1:
        return 'Heading 1';
      case BlockType.heading2:
        return 'Heading 2';
      case BlockType.heading3:
        return 'Heading 3';
      case BlockType.heading4:
        return 'Heading 4';
      case BlockType.heading5:
        return 'Heading 5';
      case BlockType.heading6:
        return 'Heading 6';
      case BlockType.bulletList:
        return 'Bullet List';
      case BlockType.orderedList:
        return 'Ordered List';
      case BlockType.horizontalRule:
        return 'Divider';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHeading = _styleOnlyTypes.contains(currentBlockType) &&
        currentBlockType != BlockType.paragraph;
    
    final chipLabel = _styleOnlyTypes.contains(currentBlockType)
        ? _blockTypeLabel(currentBlockType)
        : 'Normal';

    return PopupMenuButton<BlockType>(
      enabled: enabled,
      tooltip: 'Paragraph style',
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: onStyleChanged,
      itemBuilder: (context) =>
          group.options.where((t) => _styleOnlyTypes.contains(t)).map((type) {
        final isSelected = type == currentBlockType;
        return PopupMenuItem<BlockType>(
          value: type,
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? activeColor.withValues(alpha: 0.12) : null,
              borderRadius: BorderRadius.circular(8),
              border:
                  isSelected ? Border.all(color: activeColor, width: 1) : null,
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Text(
                  _blockTypeLabel(type),
                  style: TextStyle(
                    fontWeight: type != BlockType.paragraph
                        ? FontWeight.w600
                        : FontWeight.w400,
                    fontSize: type == BlockType.heading1
                        ? 18
                        : type == BlockType.heading2
                            ? 16
                            : 14,
                    color: isSelected ? activeColor : null,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
      child: ToolbarChip(
        label: chipLabel,
        isActive: isHeading,
        activeColor: activeColor,
        onSurface: onSurface,
        disabledColor: disabledColor,
        enabled: enabled,
        height: itemHeight,
        width: 120,
        showDropdownArrow: true,
        showBorder: false,
      ),
    );
  }
}
