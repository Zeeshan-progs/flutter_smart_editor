import 'package:flutter/material.dart';
import '../../models/enums.dart';
import '../../models/editor_settings.dart';
import '../../core/document/document.dart';

/// A widget that renders the bullet or number indicator for a [ListItemNode].
class ListItemIndicator extends StatelessWidget {
  const ListItemIndicator({
    super.key,
    required this.item,
    required this.orderedCount,
    required this.editorSettings,
    this.isDarkMode = false,
  });

  final ListItemNode item;
  final int orderedCount;
  final SmartEditorSettings editorSettings;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final defaultColor = isDarkMode ? Colors.white : Colors.black87;
    final fontSize = editorSettings.defaultFontSize;

    if (item.listType == SmartListType.ordered) {
      final label = _orderedLabel(orderedCount, item.depth);
      return Text(
        label,
        style: TextStyle(fontSize: fontSize, color: defaultColor),
        textAlign: TextAlign.right,
      );
    }

    // Bullet
    final bulletStyle = item.bulletStyle ?? editorSettings.defaultBulletStyle;
    final symbol = _bulletSymbol(bulletStyle);
    return Text(
      symbol,
      style: TextStyle(fontSize: fontSize, color: defaultColor),
      textAlign: TextAlign.center,
    );
  }

  String _orderedLabel(int count, int depth) {
    switch (depth % 4) {
      case 0:
        return '$count.';
      case 1:
        return '${String.fromCharCode(96 + count)}.';
      case 2:
        return '${_toRoman(count)}.';
      case 3:
        return '${String.fromCharCode(64 + count)}.';
      default:
        return '$count.';
    }
  }

  String _toRoman(int n) {
    if (n <= 0) return '';
    const vals = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    const syms = [
      'm', 'cm', 'd', 'cd', 'c', 'xc', 'l', 'xl', 'x', 'ix', 'v', 'iv', 'i'
    ];
    final buf = StringBuffer();
    var num = n;
    for (var i = 0; i < vals.length; i++) {
      while (num >= vals[i]) {
        buf.write(syms[i]);
        num -= vals[i];
      }
    }
    return buf.toString();
  }

  String _bulletSymbol(SmartBulletStyle style) {
    switch (style) {
      case SmartBulletStyle.filledCircle:
        return '\u2022';
      case SmartBulletStyle.hollowCircle:
        return '\u25e6';
      case SmartBulletStyle.filledSquare:
        return '\u25aa';
      case SmartBulletStyle.hollowSquare:
        return '\u25a1';
      case SmartBulletStyle.diamond:
        return '\u25c6';
      case SmartBulletStyle.hollowDiamond:
        return '\u25c7';
      case SmartBulletStyle.arrow:
        return '\u2192';
      case SmartBulletStyle.doubleArrow:
        return '\u00bb';
      case SmartBulletStyle.dash:
        return '\u2013';
      case SmartBulletStyle.star:
        return '\u2605';
      case SmartBulletStyle.hollowStar:
        return '\u2606';
      case SmartBulletStyle.checkmark:
        return '\u2713';
      case SmartBulletStyle.triangle:
        return '\u25b6';
    }
  }
}
