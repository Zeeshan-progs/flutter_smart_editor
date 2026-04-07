import 'package:flutter/material.dart';

class FontSizePickerButton extends StatelessWidget {
  final double currentSize;
  final ValueChanged<double?> onSizeChanged;
  final String tooltip;
  final Color? activeColor;
  const FontSizePickerButton(
      {super.key,
      this.currentSize = 12,
      required this.onSizeChanged,
      this.tooltip = 'Font Size',
      this.enabled = true,
      this.activeColor});

  final bool enabled;

  static const List<double> defaultSizes = [
    10,
    11,
    12,
    14,
    16,
    18,
    20,
    24,
    28,
    32,
    36,
    48,
    72
  ];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      enabled: enabled,
      tooltip: tooltip,
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: onSizeChanged,
      itemBuilder: (context) => defaultSizes.map((size) {
        final isSelected = size == currentSize;
        return PopupMenuItem<double>(
          value: size,
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? activeColor?.withValues(alpha: 0.12) : null,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(
                      color: activeColor ?? Colors.transparent, width: 1)
                  : null,
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Text(
                  size.toInt().toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    color: isSelected ? activeColor : null,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Row(
          children: [
            Text(
              currentSize.toInt().toString(),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down_rounded, size: 18)
          ],
        ),
      ),
    );
  }
}
