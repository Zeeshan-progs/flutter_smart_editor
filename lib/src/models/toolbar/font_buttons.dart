import 'package:flutter/material.dart';
import 'toolbar_group.dart';

/// Font formatting buttons (Bold, Italic, Underline, Strikethrough, etc.)
class SmartFontButtons extends SmartToolbarGroup {
  final bool bold;
  final bool italic;
  final bool underline;
  final bool clearAll;
  final bool strikethrough;
  final bool fontSize;

  const SmartFontButtons({
    this.bold = true,
    this.italic = true,
    this.underline = true,
    this.clearAll = true,
    this.strikethrough = true,
    this.fontSize = true,
  });

  /// Returns the icons for the primary font formatting buttons
  List<IconData> getIcons1() {
    final icons = <IconData>[];
    if (bold) icons.add(Icons.format_bold);
    if (italic) icons.add(Icons.format_italic);
    if (underline) icons.add(Icons.format_underline);
    if (clearAll) icons.add(Icons.format_clear);
    return icons;
  }

  /// Returns the icons for the secondary font formatting buttons
  List<IconData> getIcons2() {
    final icons = <IconData>[];
    if (strikethrough) icons.add(Icons.format_strikethrough);
    return icons;
  }
}
