
import 'package:flutter/material.dart';

class ToolbarButton extends StatelessWidget {
  const ToolbarButton({
    required this.icon,
    required this.isActive,
    required this.onPressed,
    required this.activeColor,
    required this.activeBg,
    required this.onSurface,
    required this.disabledColor,
    required this.enabled,
    required this.size,
    required this.iconSize,
    required this.tooltip,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;
  final Color activeColor;
  final Color activeBg;
  final Color onSurface;
  final Color disabledColor;
  final bool enabled;
  final double size;
  final double iconSize;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon,
          color:
              !enabled ? disabledColor : (isActive ? activeColor : onSurface),
          size: iconSize),
      onPressed: enabled ? onPressed : null,
      tooltip: tooltip,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      style: IconButton.styleFrom(
        backgroundColor: isActive ? activeBg : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
