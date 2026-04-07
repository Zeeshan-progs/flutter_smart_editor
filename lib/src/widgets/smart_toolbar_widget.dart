import 'package:flutter/material.dart';
import '../core/document_controller.dart';
import '../models/enums.dart';
import '../models/toolbar_settings.dart';
import '../models/toolbar_buttons.dart';
import 'toolbar/color_picker_button.dart';
import 'toolbar/font_size_picker_button.dart';
import 'toolbar/font_picker_button.dart';

/// A premium Material 3 toolbar for the flutter smart editor.
class SmartToolbar extends StatefulWidget {
  const SmartToolbar({
    super.key,
    required this.documentController,
    required this.settings,
    required this.getFocusedBlockIndex,
    required this.getSelection,
    this.onFormatApplied,
    this.onPendingFormatChanged,
    this.onFocusRequested,
    this.isDarkMode = false,
  });

  final DocumentController documentController;
  final SmartToolbarSettings settings;
  final int Function() getFocusedBlockIndex;
  final TextSelection? Function() getSelection;
  final VoidCallback? onFormatApplied;

  final ValueChanged<Map<String, dynamic>>? onPendingFormatChanged;
  final VoidCallback? onFocusRequested;

  final bool isDarkMode;

  @override
  State<SmartToolbar> createState() => SmartToolbarState();
}

class SmartToolbarState extends State<SmartToolbar> {
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  bool _isStrikethrough = false;
  Color? _foregroundColor;
  Color? _backgroundColor;
  double _fontSize = 12;
  String? _fontFamily;
  SmartTextAlign _currentTextAlign = SmartTextAlign.left;
  BlockType _currentBlockType = BlockType.paragraph;
  bool _enabled = true;
  bool _expanded = false;

  TextSelection? _cachedSelection;
  int? _cachedBlockIndex;

  @override
  void initState() {
    super.initState();
    _expanded = widget.settings.initiallyExpanded;
  }

  void updateFormatState(int blockIndex, Map<String, dynamic> formats) {
    if (!mounted) return;
    setState(() {
      final currentSelection = widget.getSelection();
      if (blockIndex >= 0) {
        _cachedBlockIndex = blockIndex;
      }
      if (currentSelection != null && currentSelection.isValid) {
        if (!currentSelection.isCollapsed) {
          _cachedSelection = currentSelection;
        } else if (_cachedSelection == null || _cachedSelection!.isCollapsed) {
          _cachedSelection = currentSelection;
        }
      }

      _isBold = formats['bold'] == true;
      _isItalic = formats['italic'] == true;
      _isUnderline = formats['underline'] == true;
      _isStrikethrough = formats['strikethrough'] == true;
      _foregroundColor = formats['foregroundColor'] as Color?;
      _backgroundColor = formats['backgroundColor'] as Color?;
      _fontSize = formats['fontSize'] as double? ?? 12;
      _fontFamily = formats['fontFamily'] as String?;
      _currentTextAlign =
          formats['alignment'] as SmartTextAlign? ?? SmartTextAlign.left;

      if (blockIndex >= 0 &&
          blockIndex < widget.documentController.document.blocks.length) {
        _currentBlockType =
            widget.documentController.document.blocks[blockIndex].blockType;
      }
    });
  }

  void setEnabled(bool enabled) {
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
    });
  }

  void _toggleFormat(String format) {
    if (!_enabled) return;

    var blockIndex = widget.getFocusedBlockIndex();
    var selection = widget.getSelection();

    if (selection == null || !selection.isValid || blockIndex < 0) {
      if (_cachedSelection != null && _cachedBlockIndex != null) {
        selection = _cachedSelection;
        blockIndex = _cachedBlockIndex!;
      }
    } else if (selection.isCollapsed &&
        _cachedSelection != null &&
        !_cachedSelection!.isCollapsed &&
        _cachedBlockIndex == blockIndex) {
      selection = _cachedSelection;
    }

    if (selection == null) return;

    if (selection.isCollapsed) {
      setState(() {
        switch (format) {
          case 'bold': _isBold = !_isBold; break;
          case 'italic': _isItalic = !_isItalic; break;
          case 'underline': _isUnderline = !_isUnderline; break;
          case 'strikethrough': _isStrikethrough = !_isStrikethrough; break;
        }
      });

      widget.onPendingFormatChanged?.call({
        'bold': _isBold,
        'italic': _isItalic,
        'underline': _isUnderline,
        'strikethrough': _isStrikethrough,
        'foregroundColor': _foregroundColor,
        'backgroundColor': _backgroundColor,
        'fontSize': _fontSize,
        'fontFamily': _fontFamily,
      });
      return;
    }

    final start = selection.start;
    final end = selection.end;

    widget.documentController.toggleFormat(blockIndex, start, end, format);
    widget.onFormatApplied?.call();

    final formats = widget.documentController.getFormatAt(blockIndex, start);
    updateFormatState(blockIndex, formats);
  }

  void _applyValueFormat(String format, dynamic value) {
    if (!_enabled) return;

    var blockIndex = widget.getFocusedBlockIndex();
    var selection = widget.getSelection();

    if (selection == null || !selection.isValid || blockIndex < 0) {
      if (_cachedSelection != null && _cachedBlockIndex != null) {
        selection = _cachedSelection;
        blockIndex = _cachedBlockIndex!;
      }
    } else if (selection.isCollapsed &&
        _cachedSelection != null &&
        !_cachedSelection!.isCollapsed &&
        _cachedBlockIndex == blockIndex) {
      selection = _cachedSelection;
    }

    if (selection == null) return;

    if (selection.isCollapsed) {
      setState(() {
        if (format == 'foregroundColor') {
          _foregroundColor = value as Color?;
        } else if (format == 'backgroundColor') {
          _backgroundColor = value as Color?;
        } else if (format == 'fontSize') {
          _fontSize = value as double? ?? 12;
        } else if (format == 'fontFamily') {
          _fontFamily = value as String?;
        }
      });
      widget.onPendingFormatChanged?.call({
        'bold': _isBold,
        'italic': _isItalic,
        'underline': _isUnderline,
        'strikethrough': _isStrikethrough,
        'foregroundColor': _foregroundColor,
        'backgroundColor': _backgroundColor,
        'fontSize': _fontSize,
        'fontFamily': _fontFamily,
      });
      widget.onFocusRequested?.call();
      return;
    }

    final start = selection.start;
    final end = selection.end;
    widget.documentController
        .applyFormat(blockIndex, start, end, format, value);
    widget.onFormatApplied?.call();

    final formats = widget.documentController.getFormatAt(blockIndex, start);
    updateFormatState(blockIndex, formats);
    widget.onFocusRequested?.call();
  }

  void _clearAll() {
    if (!_enabled) return;
    final blockIndex = widget.getFocusedBlockIndex();
    final selection = widget.getSelection();
    if (selection == null || selection.isCollapsed) return;

    widget.documentController.clearFormat(
        blockIndex, selection.start, selection.end - selection.start);
    widget.onFormatApplied?.call();

    final formats =
        widget.documentController.getFormatAt(blockIndex, selection.start);
    updateFormatState(blockIndex, formats);
  }

  void _changeBlockType(BlockType newType) {
    if (!_enabled) return;

    final blockIndex = widget.getFocusedBlockIndex();
    widget.documentController.changeBlockType(blockIndex, newType);
    widget.onFormatApplied?.call();

    setState(() {
      _currentBlockType = newType;
    });
  }

  void _changeAlignment(SmartTextAlign alignment) {
    if (!_enabled) return;

    final blockIndex = widget.getFocusedBlockIndex();
    widget.documentController.setAlignment(blockIndex, alignment);
    widget.onFormatApplied?.call();

    setState(() {
      _currentTextAlign = alignment;
    });
  }

  String _blockTypeLabel(BlockType type) {
    switch (type) {
      case BlockType.paragraph: return 'Normal';
      case BlockType.heading1: return 'Heading 1';
      case BlockType.heading2: return 'Heading 2';
      case BlockType.heading3: return 'Heading 3';
      case BlockType.heading4: return 'Heading 4';
      case BlockType.heading5: return 'Heading 5';
      case BlockType.heading6: return 'Heading 6';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final surfaceColor = widget.isDarkMode
        ? colorScheme.surfaceContainerHigh
        : colorScheme.surfaceContainerLow;
    final onSurface = widget.isDarkMode ? colorScheme.onSurface : colorScheme.onSurface;
    final activeColor = widget.settings.buttonSelectedColor ?? colorScheme.primary;
    final activeBg = activeColor.withValues(alpha: 0.12);
    final disabledColor = onSurface.withValues(alpha: 0.3);
    final dividerColor = widget.isDarkMode
        ? Colors.white12
        : Colors.black.withValues(alpha: 0.08);

    final toolbarItems = _buildToolbarItems(
      onSurface: onSurface,
      activeColor: activeColor,
      activeBg: activeBg,
      disabledColor: disabledColor,
      dividerColor: dividerColor,
    );

    Widget content;
    switch (widget.settings.toolbarType) {
      case SmartToolbarType.scrollable:
        content = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: toolbarItems,
          ),
        );
        break;
      case SmartToolbarType.grid:
        content = Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Wrap(
            spacing: widget.settings.gridSpacingH,
            runSpacing: widget.settings.gridSpacingV,
            children: toolbarItems,
          ),
        );
        break;
      case SmartToolbarType.expandable:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  ...toolbarItems,
                  IconButton(
                    icon: Icon(_expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down),
                    onPressed: () {
                      setState(() {
                        _expanded = !_expanded;
                      });
                    },
                  ),
                ],
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Wrap(
                  spacing: widget.settings.gridSpacingH,
                  runSpacing: widget.settings.gridSpacingV,
                  children: toolbarItems,
                ),
              ),
          ],
        );
        break;
    }

    return Container(
      width: double.infinity,
      padding: widget.settings.padding ?? EdgeInsets.zero,
      decoration: widget.settings.decoration ?? BoxDecoration(
        color: surfaceColor,
        border: widget.settings.showBorder
            ? Border(
                bottom: widget.settings.toolbarPosition ==
                        SmartToolbarPosition.above
                    ? BorderSide(color: dividerColor, width: 1)
                    : BorderSide.none,
                top: widget.settings.toolbarPosition ==
                        SmartToolbarPosition.below
                    ? BorderSide(color: dividerColor, width: 1)
                    : BorderSide.none,
              )
            : null,
      ),
      child: content,
    );
  }

  List<Widget> _buildToolbarItems({
    required Color onSurface,
    required Color activeColor,
    required Color activeBg,
    required Color disabledColor,
    required Color dividerColor,
  }) {
    final items = <Widget>[];

    for (var i = 0; i < widget.settings.defaultButtons.length; i++) {
      final group = widget.settings.defaultButtons[i];

      if (items.isNotEmpty && widget.settings.showSeparators) {
        items.add(_buildSeparator(dividerColor));
      }

      if (group is SmartStyleButtons && group.style) {
        items.add(_buildStyleChip(group, onSurface, activeColor, disabledColor));
      } else if (group is SmartFontButtons) {
        items.addAll(_buildFontButtons(group, onSurface, activeColor, activeBg, disabledColor));
      } else if (group is SmartOtherButtons) {
        items.addAll(_buildOtherButtons(group, onSurface, activeColor, activeBg, disabledColor));
      } else if (group is SmartColorButtons) {
        items.addAll(_buildColorButtons(group, onSurface, activeColor, activeBg, disabledColor));
      } else if (group is SmartFontSizeButtons && group.fontSize) {
        items.add(FontSizePickerButton(
          currentSize: _fontSize,
          enabled: _enabled,
          activeColor: activeColor,
          tooltip: "Font Size",
          onSizeChanged: (size) => _applyValueFormat('fontSize', size),
        ));
      } else if (group is SmartFontFamilyButtons && group.fontFamily) {
        items.add(FontPickerButton(
          currentFont: _fontFamily,
          enabled: _enabled,
          onFontChanged: (font) => _applyValueFormat('fontFamily', font),
        ));
      } else if (group is SmartParagraphButtons) {
        items.addAll(_buildParagraphButtons(group, onSurface, activeColor, activeBg, disabledColor));
      }
    }

    return items;
  }

  Widget _buildSeparator(Color dividerColor) {
    return widget.settings.separatorWidget ??
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            height: widget.settings.itemHeight - 8,
            child: VerticalDivider(
              width: 1,
              thickness: 1,
              color: dividerColor,
            ),
          ),
        );
  }

  Widget _buildStyleChip(SmartStyleButtons group, Color onSurface,
      Color activeColor, Color disabledColor) {
    final isHeading = _currentBlockType != BlockType.paragraph;

    return PopupMenuButton<BlockType>(
      enabled: _enabled,
      tooltip: 'Paragraph style',
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: _changeBlockType,
      itemBuilder: (context) => group.options.map((type) {
        final isSelected = type == _currentBlockType;
        return PopupMenuItem<BlockType>(
          value: type,
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? activeColor.withValues(alpha: 0.12) : null,
              borderRadius: BorderRadius.circular(8),
              border: isSelected ? Border.all(color: activeColor, width: 1) : null,
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Text(
                  _blockTypeLabel(type),
                  style: TextStyle(
                    fontWeight: type != BlockType.paragraph ? FontWeight.w600 : FontWeight.w400,
                    fontSize: type == BlockType.heading1 ? 18 : type == BlockType.heading2 ? 16 : 14,
                    color: isSelected ? activeColor : null,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
      child: ToolbarChip(
        label: _blockTypeLabel(_currentBlockType),
        isActive: isHeading,
        activeColor: activeColor,
        onSurface: onSurface,
        disabledColor: disabledColor,
        enabled: _enabled,
        height: widget.settings.itemHeight,
        width: 120,
        showDropdownArrow: true,
      ),
    );
  }

  List<Widget> _buildFontButtons(SmartFontButtons group, Color onSurface, Color activeColor, Color activeBg, Color disabledColor) {
    final buttons = <Widget>[];
    if (group.bold) {
      buttons.add(_ToolbarButton(icon: Icons.format_bold, isActive: _isBold, onPressed: () => _toggleFormat('bold'), activeColor: activeColor, activeBg: activeBg, onSurface: onSurface, disabledColor: disabledColor, enabled: _enabled, size: widget.settings.itemHeight, iconSize: widget.settings.buttonIconSize, tooltip: 'Bold'));
    }
    if (group.italic) {
      buttons.add(_ToolbarButton(icon: Icons.format_italic, isActive: _isItalic, onPressed: () => _toggleFormat('italic'), activeColor: activeColor, activeBg: activeBg, onSurface: onSurface, disabledColor: disabledColor, enabled: _enabled, size: widget.settings.itemHeight, iconSize: widget.settings.buttonIconSize, tooltip: 'Italic'));
    }
    if (group.underline) {
      buttons.add(_ToolbarButton(icon: Icons.format_underlined, isActive: _isUnderline, onPressed: () => _toggleFormat('underline'), activeColor: activeColor, activeBg: activeBg, onSurface: onSurface, disabledColor: disabledColor, enabled: _enabled, size: widget.settings.itemHeight, iconSize: widget.settings.buttonIconSize, tooltip: 'Underline'));
    }
    if (group.strikethrough) {
      buttons.add(_ToolbarButton(icon: Icons.format_strikethrough, isActive: _isStrikethrough, onPressed: () => _toggleFormat('strikethrough'), activeColor: activeColor, activeBg: activeBg, onSurface: onSurface, disabledColor: disabledColor, enabled: _enabled, size: widget.settings.itemHeight, iconSize: widget.settings.buttonIconSize, tooltip: 'Strikethrough'));
    }
    if (group.clearAll) {
      buttons.add(_ToolbarButton(icon: Icons.format_clear, isActive: false, onPressed: _clearAll, activeColor: activeColor, activeBg: activeBg, onSurface: onSurface, disabledColor: disabledColor, enabled: _enabled, size: widget.settings.itemHeight, iconSize: widget.settings.buttonIconSize, tooltip: 'Clear Formatting'));
    }
    return buttons;
  }

  List<Widget> _buildOtherButtons(SmartOtherButtons group, Color onSurface, Color activeColor, Color activeBg, Color disabledColor) {
    final buttons = <Widget>[];
    if (group.undo) {
      buttons.add(_ToolbarButton(icon: Icons.undo_rounded, isActive: false, onPressed: () { widget.documentController.undo(); widget.onFormatApplied?.call(); }, activeColor: activeColor, activeBg: activeBg, onSurface: onSurface, disabledColor: disabledColor, enabled: _enabled, size: widget.settings.itemHeight, iconSize: widget.settings.buttonIconSize, tooltip: 'Undo'));
    }
    if (group.redo) {
      buttons.add(_ToolbarButton(icon: Icons.redo_rounded, isActive: false, onPressed: () { widget.documentController.redo(); widget.onFormatApplied?.call(); }, activeColor: activeColor, activeBg: activeBg, onSurface: onSurface, disabledColor: disabledColor, enabled: _enabled, size: widget.settings.itemHeight, iconSize: widget.settings.buttonIconSize, tooltip: 'Redo'));
    }
    return buttons;
  }

  List<Widget> _buildColorButtons(SmartColorButtons group, Color onSurface, Color activeColor, Color activeBg, Color disabledColor) {
    final buttons = <Widget>[];
    if (group.foregroundColor) {
      buttons.add(ColorPickerButton(icon: Icons.format_color_text, currentColor: _foregroundColor, tooltip: 'Text Color', enabled: _enabled, onColorChanged: (color) => _applyValueFormat('foregroundColor', color)));
    }
    if (group.highlightColor) {
      buttons.add(ColorPickerButton(icon: Icons.color_lens, currentColor: _backgroundColor, tooltip: 'Highlight Color', enabled: _enabled, onColorChanged: (color) => _applyValueFormat('backgroundColor', color)));
    }
    return buttons;
  }

  List<Widget> _buildParagraphButtons(SmartParagraphButtons group, Color onSurface, Color activeColor, Color activeBg, Color disabledColor) {
    final buttons = <Widget>[];
    if (group.alignLeft) {
      buttons.add(_ToolbarButton(icon: Icons.format_align_left, isActive: _currentTextAlign == SmartTextAlign.left, onPressed: () => _changeAlignment(SmartTextAlign.left), activeColor: activeColor, activeBg: activeBg, onSurface: onSurface, disabledColor: disabledColor, enabled: _enabled, size: widget.settings.itemHeight, iconSize: widget.settings.buttonIconSize, tooltip: 'Align Left'));
    }
    if (group.alignCenter) {
      buttons.add(_ToolbarButton(icon: Icons.format_align_center, isActive: _currentTextAlign == SmartTextAlign.center, onPressed: () => _changeAlignment(SmartTextAlign.center), activeColor: activeColor, activeBg: activeBg, onSurface: onSurface, disabledColor: disabledColor, enabled: _enabled, size: widget.settings.itemHeight, iconSize: widget.settings.buttonIconSize, tooltip: 'Align Center'));
    }
    if (group.alignRight) {
      buttons.add(_ToolbarButton(icon: Icons.format_align_right, isActive: _currentTextAlign == SmartTextAlign.right, onPressed: () => _changeAlignment(SmartTextAlign.right), activeColor: activeColor, activeBg: activeBg, onSurface: onSurface, disabledColor: disabledColor, enabled: _enabled, size: widget.settings.itemHeight, iconSize: widget.settings.buttonIconSize, tooltip: 'Align Right'));
    }
    if (group.alignJustify) {
      buttons.add(_ToolbarButton(icon: Icons.format_align_justify, isActive: _currentTextAlign == SmartTextAlign.justify, onPressed: () => _changeAlignment(SmartTextAlign.justify), activeColor: activeColor, activeBg: activeBg, onSurface: onSurface, disabledColor: disabledColor, enabled: _enabled, size: widget.settings.itemHeight, iconSize: widget.settings.buttonIconSize, tooltip: 'Align Justify'));
    }
    return buttons;
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
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
      icon: Icon(icon, color: !enabled ? disabledColor : (isActive ? activeColor : onSurface), size: iconSize),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height - 8,
      width: width,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isActive ? activeColor.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isActive ? activeColor : onSurface.withValues(alpha: 0.1), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: TextStyle(color: !enabled ? disabledColor : (isActive ? activeColor : onSurface), fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
          if (showDropdownArrow) Icon(Icons.arrow_drop_down, size: 18, color: !enabled ? disabledColor : (isActive ? activeColor : onSurface)),
        ],
      ),
    );
  }
}
