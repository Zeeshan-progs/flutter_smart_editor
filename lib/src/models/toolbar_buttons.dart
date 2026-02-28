import 'package:flutter/material.dart';
import 'enums.dart';

/// Abstract base for toolbar button groups
abstract class SmartToolbarGroup {
  const SmartToolbarGroup();
}

/// Style dropdown group (paragraph style: H1, H2, ..., Normal)
class SmartStyleButtons extends SmartToolbarGroup {
  final bool style;
  final List<BlockType> options;

  const SmartStyleButtons({
    this.style = true,
    this.options = const [
      BlockType.heading1,
      BlockType.heading2,
      BlockType.heading3,
      BlockType.heading4,
      BlockType.heading5,
      BlockType.heading6,
      BlockType.paragraph,
    ],
  });
}

/// Font formatting buttons (Bold, Italic, Underline, Strikethrough, etc.)
class SmartFontButtons extends SmartToolbarGroup {
  final bool bold;
  final bool italic;
  final bool underline;
  final bool clearAll;
  final bool strikethrough;
  final bool superscript;
  final bool subscript;

  const SmartFontButtons({
    this.bold = true,
    this.italic = true,
    this.underline = true,
    this.clearAll = true,
    this.strikethrough = true,
    this.superscript = true,
    this.subscript = true,
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
    if (superscript) icons.add(Icons.superscript);
    if (subscript) icons.add(Icons.subscript);
    return icons;
  }
}

/// Color picker buttons (Text color, Highlight color)
class SmartColorButtons extends SmartToolbarGroup {
  final bool foregroundColor;
  final bool highlightColor;

  const SmartColorButtons({
    this.foregroundColor = true,
    this.highlightColor = true,
  });
}

/// List buttons (Bullet list, Numbered list)
class SmartListButtons extends SmartToolbarGroup {
  final bool ul;
  final bool ol;
  final bool listStyles;

  const SmartListButtons({
    this.ul = true,
    this.ol = true,
    this.listStyles = true,
  });
}

/// Paragraph/Alignment buttons
class SmartParagraphButtons extends SmartToolbarGroup {
  final bool alignLeft;
  final bool alignCenter;
  final bool alignRight;
  final bool alignJustify;
  final bool increaseIndent;
  final bool decreaseIndent;
  final bool textDirection;
  final bool lineHeight;
  final bool caseConverter;

  const SmartParagraphButtons({
    this.alignLeft = true,
    this.alignCenter = true,
    this.alignRight = true,
    this.alignJustify = true,
    this.increaseIndent = true,
    this.decreaseIndent = true,
    this.textDirection = true,
    this.lineHeight = true,
    this.caseConverter = true,
  });
}

/// Insert buttons (Link, Image, Table, HR, etc.)
class SmartInsertButtons extends SmartToolbarGroup {
  final bool link;
  final bool picture;
  final bool audio;
  final bool video;
  final bool otherFile;
  final bool table;
  final bool hr;

  const SmartInsertButtons({
    this.link = true,
    this.picture = true,
    this.audio = true,
    this.video = true,
    this.otherFile = false,
    this.table = true,
    this.hr = true,
  });
}

/// Miscellaneous buttons (Undo, Redo, Code view, Fullscreen, etc.)
class SmartOtherButtons extends SmartToolbarGroup {
  final bool fullscreen;
  final bool codeview;
  final bool undo;
  final bool redo;
  final bool help;
  final bool copy;
  final bool paste;

  const SmartOtherButtons({
    this.fullscreen = true,
    this.codeview = true,
    this.undo = true,
    this.redo = true,
    this.help = true,
    this.copy = true,
    this.paste = true,
  });
}
