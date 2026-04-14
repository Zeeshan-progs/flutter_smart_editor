
import 'package:flutter/material.dart';

class ToolbarChip extends StatelessWidget {
  const ToolbarChip({
    super.key,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onSurface,
    required this.disabledColor,
    required this.enabled,
    required this.height,
    required this.width,
    this.showDropdownArrow = false,
    this.showBorder = true,
  });

  final String label;
  final bool isActive;
  final Color activeColor;
  final Color onSurface;
  final Color disabledColor;
  final bool enabled;
  final double height;
  final double width;
  final bool showDropdownArrow;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height - 8,
      width: width,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: showBorder
            ? Border.all(
                color:
                    isActive ? activeColor : onSurface.withValues(alpha: 0.1),
                width: 1)
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: !enabled ? disabledColor : onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis)),
          if (showDropdownArrow)
            Icon(Icons.arrow_drop_down,
                size: 18,
                color: !enabled
                    ? disabledColor
                    : (isActive ? activeColor : onSurface)),
        ],
      ),
    );
  }
}
