import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/document_controller.dart';
import '../core/html_parser.dart';
import '../models/enums.dart';
import '../models/pending_inline_format.dart';
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
    this.getMergedFormatsForToolbar,
    this.isDarkMode = false,
  });

  final DocumentController documentController;
  final SmartToolbarSettings settings;
  final int Function() getFocusedBlockIndex;
  final TextSelection? Function() getSelection;
  final VoidCallback? onFormatApplied;

  final ValueChanged<PendingInlineFormat>? onPendingFormatChanged;
  final VoidCallback? onFocusRequested;

  /// Merges document + pending (same as the editor toolbar map).
  final Map<SmartButtonType, dynamic> Function()? getMergedFormatsForToolbar;

  final bool isDarkMode;

  @override
  State<SmartToolbar> createState() => SmartToolbarState();
}

class SmartToolbarState extends State<SmartToolbar> {
  // Centralized state map for all formatting
  Map<SmartButtonType, dynamic> _activeFormats = {};

  bool _enabled = true;
  bool _expanded = false;

  TextSelection? _cachedSelection;
  int? _cachedBlockIndex;

  TextSelection? _pointerSnapshotSelection;
  int? _pointerSnapshotBlockIndex;

  bool _inheritForegroundColor = true;
  bool _inheritBackgroundColor = true;
  bool _inheritFontSize = true;
  bool _inheritFontFamily = true;

  @override
  void initState() {
    super.initState();
    _expanded = widget.settings.initiallyExpanded;
  }

  void updateFormatState(
      int blockIndex, Map<SmartButtonType, dynamic> formats) {
    if (!mounted) return;

    setState(() {
      _activeFormats = Map.from(formats);
      _cachedSelection = widget.getSelection();
      _cachedBlockIndex = blockIndex;
      _inheritForegroundColor = true;
      _inheritBackgroundColor = true;
      _inheritFontSize = true;
      _inheritFontFamily = true;
    });
  }

  void setEnabled(bool enabled) {
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
    });
  }

  static bool _isBoolToggleType(SmartButtonType type) {
    return type == SmartButtonType.bold ||
        type == SmartButtonType.italic ||
        type == SmartButtonType.underline ||
        type == SmartButtonType.strikethrough;
  }

  void _clearPointerSnapshot() {
    _pointerSnapshotSelection = null;
    _pointerSnapshotBlockIndex = null;
  }

  void _onToolbarPointerDown(PointerDownEvent event) {
    final sel = widget.getSelection();
    final bi = widget.getFocusedBlockIndex();
    if (sel != null && sel.isValid && !sel.isCollapsed) {
      _pointerSnapshotSelection = sel;
      _pointerSnapshotBlockIndex = bi;
    }
  }

  void _finishToolbarAction() {
    _clearPointerSnapshot();
    widget.onFocusRequested?.call();
  }

  PendingInlineFormat _buildPendingInlineFormat() {
    return PendingInlineFormat(
      isBold: _activeFormats[SmartButtonType.bold] == true,
      isItalic: _activeFormats[SmartButtonType.italic] == true,
      isUnderline: _activeFormats[SmartButtonType.underline] == true,
      isStrikethrough: _activeFormats[SmartButtonType.strikethrough] == true,
      inheritForegroundColor: _inheritForegroundColor,
      foregroundColor:
          _activeFormats[SmartButtonType.foregroundColor] as Color?,
      inheritBackgroundColor: _inheritBackgroundColor,
      backgroundColor: _activeFormats[SmartButtonType.highlightColor] as Color?,
      inheritFontSize: _inheritFontSize,
      fontSize: _activeFormats[SmartButtonType.fontSize] as double?,
      inheritFontFamily: _inheritFontFamily,
      fontFamily: _activeFormats[SmartButtonType.fontName] as String?,
    );
  }

  void _syncToolbarAfterDocumentChange() {
    final merged = widget.getMergedFormatsForToolbar?.call();
    final (blockIndex, _) = _getEffectiveSelection();
    if (merged != null && merged.isNotEmpty) {
      updateFormatState(blockIndex, merged);
    } else {
      final sel = _getEffectiveSelection().$2;
      if (sel != null && blockIndex >= 0) {
        final formats =
            widget.documentController.getFormatAt(blockIndex, sel.start);
        updateFormatState(blockIndex, formats);
      }
    }
  }

  /// Unified handler for all toolbar actions.
  void _onToolbarAction(SmartButtonType type, {dynamic value}) {
    if (!_enabled) return;

    final (blockIndex, selection) = _getEffectiveSelection();

    if (type == SmartButtonType.blockType) {
      final newType = value as BlockType;
      widget.documentController.changeBlockType(blockIndex, newType);
      widget.onFormatApplied?.call();
      _syncToolbarAfterDocumentChange();
      _finishToolbarAction();
      return;
    }

    if (type == SmartButtonType.alignLeft ||
        type == SmartButtonType.alignCenter ||
        type == SmartButtonType.alignRight ||
        type == SmartButtonType.alignJustify) {
      final alignment = value as SmartTextAlign;
      widget.documentController.setAlignment(blockIndex, alignment);
      widget.onFormatApplied?.call();
      _syncToolbarAfterDocumentChange();
      _finishToolbarAction();
      return;
    }

    if (type == SmartButtonType.ul || type == SmartButtonType.bulletList) {
      widget.documentController.toggleList(blockIndex, SmartListType.bullet);
      widget.onFormatApplied?.call();
      _syncToolbarAfterDocumentChange();
      _finishToolbarAction();
      return;
    }
    if (type == SmartButtonType.ol || type == SmartButtonType.orderedList) {
      widget.documentController.toggleList(blockIndex, SmartListType.ordered);
      widget.onFormatApplied?.call();
      _syncToolbarAfterDocumentChange();
      _finishToolbarAction();
      return;
    }
    if (type == SmartButtonType.horizontalRule) {
      widget.documentController.insertHorizontalRule(blockIndex);
      widget.onFormatApplied?.call();
      _syncToolbarAfterDocumentChange();
      _finishToolbarAction();
      return;
    }

    if (type == SmartButtonType.undo) {
      widget.documentController.undo();
      widget.onFormatApplied?.call();
      _syncToolbarAfterDocumentChange();
      _finishToolbarAction();
      return;
    }
    if (type == SmartButtonType.redo) {
      widget.documentController.redo();
      widget.onFormatApplied?.call();
      _syncToolbarAfterDocumentChange();
      _finishToolbarAction();
      return;
    }

    if (type == SmartButtonType.copy) {
      if (selection != null && !selection.isCollapsed) {
        final html =
            widget.documentController.getSelectedHtml(blockIndex, selection);
        if (html.isNotEmpty) {
          Clipboard.setData(ClipboardData(text: html));
        }
      }
      _finishToolbarAction();
      return;
    }

    if (type == SmartButtonType.paste) {
      Clipboard.getData(Clipboard.kTextPlain).then((data) {
        final text = data?.text;
        if (text != null && text.isNotEmpty) {
          widget.documentController.pasteHtml(
            blockIndex,
            selection?.start ?? 0,
            text,
            parser: SmartHtmlParser(),
          );
          widget.onFormatApplied?.call();
          _syncToolbarAfterDocumentChange();
        }
      });
      _finishToolbarAction();
      return;
    }

    if (type == SmartButtonType.clearFormatting) {
      if (selection != null && !selection.isCollapsed) {
        widget.documentController.toggleFormat(
          blockIndex,
          selection.start,
          selection.end,
          SmartButtonType.clearFormatting,
        );
        widget.onFormatApplied?.call();
      }
      _syncToolbarAfterDocumentChange();
      _finishToolbarAction();
      return;
    }

    if (selection == null || selection.isCollapsed) {
      setState(() {
        if (_isBoolToggleType(type)) {
          final current = _activeFormats[type];
          _activeFormats[type] = !(current == true);
        } else if (type == SmartButtonType.foregroundColor) {
          _inheritForegroundColor = false;
          _activeFormats[type] = value;
        } else if (type == SmartButtonType.highlightColor) {
          _inheritBackgroundColor = false;
          _activeFormats[type] = value;
        } else if (type == SmartButtonType.fontSize) {
          _inheritFontSize = false;
          _activeFormats[type] = value;
        } else if (type == SmartButtonType.fontName) {
          _inheritFontFamily = false;
          _activeFormats[type] = value;
        }
      });
      widget.onPendingFormatChanged?.call(_buildPendingInlineFormat());
      _finishToolbarAction();
      return;
    }

    final start = selection.start;
    final end = selection.end;
    if (_isBoolToggleType(type) && value == null) {
      widget.documentController.toggleFormat(blockIndex, start, end, type);
    } else {
      widget.documentController.applyFormat(
        blockIndex,
        start,
        end,
        type,
        value,
      );
    }
    widget.onFormatApplied?.call();
    _syncToolbarAfterDocumentChange();
    _finishToolbarAction();
  }

  /// Returns the current selection or falls back to cached / pointer snapshot.
  (int, TextSelection?) _getEffectiveSelection() {
    if (_pointerSnapshotSelection != null &&
        _pointerSnapshotBlockIndex != null &&
        _pointerSnapshotSelection!.isValid &&
        !_pointerSnapshotSelection!.isCollapsed) {
      return (_pointerSnapshotBlockIndex!, _pointerSnapshotSelection);
    }

    var blockIndex = widget.getFocusedBlockIndex();
    var selection = widget.getSelection();

    if (selection == null || !selection.isValid || blockIndex < 0) {
      if (_cachedSelection != null && _cachedBlockIndex != null) {
        // Only fallback if the cached selection is collapsed.
        // If it's a range, it's safer to treat as null/collapsed than to re-apply to old text.
        if (_cachedSelection!.isCollapsed) {
          return (_cachedBlockIndex!, _cachedSelection);
        }
      }
    }
    return (blockIndex, selection);
  }

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

  // List state helpers
  bool get _isBulletList =>
      _activeFormats[SmartButtonType.blockType] == BlockType.bulletList;
  bool get _isOrderedList =>
      _activeFormats[SmartButtonType.blockType] == BlockType.orderedList;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final surfaceColor = widget.isDarkMode
        ? colorScheme.surfaceContainerHigh
        : colorScheme.surfaceContainerLow;
    final onSurface =
        widget.isDarkMode ? colorScheme.onSurface : colorScheme.onSurface;
    final activeColor =
        widget.settings.buttonSelectedColor ?? colorScheme.primary;
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
      decoration: widget.settings.decoration ??
          BoxDecoration(
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
      child: Focus(
        canRequestFocus: false,
        descendantsAreFocusable: false,
        child: Listener(
          onPointerDown: _onToolbarPointerDown,
          behavior: HitTestBehavior.translucent,
          child: content,
        ),
      ),
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
        items
            .add(_buildStyleChip(group, onSurface, activeColor, disabledColor));
      } else if (group is SmartFontButtons) {
        items.addAll(_buildFontButtons(
            group, onSurface, activeColor, activeBg, disabledColor));
      } else if (group is SmartOtherButtons) {
        items.addAll(_buildOtherButtons(
            group, onSurface, activeColor, activeBg, disabledColor));
      } else if (group is SmartColorButtons) {
        items.addAll(_buildColorButtons(
            group, onSurface, activeColor, activeBg, disabledColor));
      } else if (group is SmartFontFamilyButtons && group.fontFamily) {
        items.add(FontPickerButton(
          currentFont: _activeFormats[SmartButtonType.fontName] as String?,
          enabled: _enabled,
          onFontChanged: (font) =>
              _onToolbarAction(SmartButtonType.fontName, value: font),
        ));
      } else if (group is SmartParagraphButtons) {
        items.addAll(_buildParagraphButtons(
            group, onSurface, activeColor, activeBg, disabledColor));
      } else if (group is SmartListButtons) {
        items.addAll(_buildListButtons(
            group, onSurface, activeColor, activeBg, disabledColor));
      } else if (group is SmartInsertButtons) {
        items.addAll(_buildInsertButtons(
            group, onSurface, activeColor, activeBg, disabledColor));
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

  /// Filter: style chip should only show paragraph/heading types, NOT lists/HR
  static const _styleOnlyTypes = {
    BlockType.paragraph,
    BlockType.heading1,
    BlockType.heading2,
    BlockType.heading3,
    BlockType.heading4,
    BlockType.heading5,
    BlockType.heading6,
  };

  Widget _buildStyleChip(SmartStyleButtons group, Color onSurface,
      Color activeColor, Color disabledColor) {
    final currentBlockType =
        _activeFormats[SmartButtonType.blockType] as BlockType? ??
            BlockType.paragraph;
    // Only show as heading-active if NOT a list or HR
    final isHeading = _styleOnlyTypes.contains(currentBlockType) &&
        currentBlockType != BlockType.paragraph;
    // Label: if current block is list/HR, default to 'Normal'
    final chipLabel = _styleOnlyTypes.contains(currentBlockType)
        ? _blockTypeLabel(currentBlockType)
        : 'Normal';

    return PopupMenuButton<BlockType>(
      enabled: _enabled,
      tooltip: 'Paragraph style',
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (type) =>
          _onToolbarAction(SmartButtonType.blockType, value: type),
      // Only show paragraph + heading types, never bulletList/orderedList/horizontalRule
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
        enabled: _enabled,
        height: widget.settings.itemHeight,
        width: 120,
        showDropdownArrow: true,
        showBorder: false,
      ),
    );
  }

  List<Widget> _buildFontButtons(SmartFontButtons group, Color onSurface,
      Color activeColor, Color activeBg, Color disabledColor) {
    final buttons = <Widget>[];
    if (group.bold) {
      buttons.add(_ToolbarButton(
          icon: Icons.format_bold,
          isActive: _activeFormats[SmartButtonType.bold] == true,
          onPressed: () => _onToolbarAction(SmartButtonType.bold),
          activeColor: activeColor,
          activeBg: activeBg,
          onSurface: onSurface,
          disabledColor: disabledColor,
          enabled: _enabled,
          size: widget.settings.itemHeight,
          iconSize: widget.settings.buttonIconSize,
          tooltip: 'Bold'));
    }
    if (group.italic) {
      buttons.add(_ToolbarButton(
          icon: Icons.format_italic,
          isActive: _activeFormats[SmartButtonType.italic] == true,
          onPressed: () => _onToolbarAction(SmartButtonType.italic),
          activeColor: activeColor,
          activeBg: activeBg,
          onSurface: onSurface,
          disabledColor: disabledColor,
          enabled: _enabled,
          size: widget.settings.itemHeight,
          iconSize: widget.settings.buttonIconSize,
          tooltip: 'Italic'));
    }
    if (group.underline) {
      buttons.add(_ToolbarButton(
          icon: Icons.format_underlined,
          isActive: _activeFormats[SmartButtonType.underline] == true,
          onPressed: () => _onToolbarAction(SmartButtonType.underline),
          activeColor: activeColor,
          activeBg: activeBg,
          onSurface: onSurface,
          disabledColor: disabledColor,
          enabled: _enabled,
          size: widget.settings.itemHeight,
          iconSize: widget.settings.buttonIconSize,
          tooltip: 'Underline'));
    }
    if (group.strikethrough) {
      buttons.add(_ToolbarButton(
          icon: Icons.format_strikethrough,
          isActive: _activeFormats[SmartButtonType.strikethrough] == true,
          onPressed: () => _onToolbarAction(SmartButtonType.strikethrough),
          activeColor: activeColor,
          activeBg: activeBg,
          onSurface: onSurface,
          disabledColor: disabledColor,
          enabled: _enabled,
          size: widget.settings.itemHeight,
          iconSize: widget.settings.buttonIconSize,
          tooltip: 'Strikethrough'));
    }
    if (group.fontSize) {
      buttons.add(FontSizePickerButton(
        currentSize: _activeFormats[SmartButtonType.fontSize] as double? ?? 12,
        enabled: _enabled,
        activeColor: activeColor,
        tooltip: "Font Size",
        onSizeChanged: (size) =>
            _onToolbarAction(SmartButtonType.fontSize, value: size),
      ));
    }
    if (group.clearAll) {
      buttons.add(_ToolbarButton(
          icon: Icons.format_clear,
          isActive: false,
          onPressed: () => _onToolbarAction(SmartButtonType.clearFormatting),
          activeColor: activeColor,
          activeBg: activeBg,
          onSurface: onSurface,
          disabledColor: disabledColor,
          enabled: _enabled,
          size: widget.settings.itemHeight,
          iconSize: widget.settings.buttonIconSize,
          tooltip: 'Clear Formatting'));
    }
    return buttons;
  }

  List<Widget> _buildColorButtons(SmartColorButtons group, Color onSurface,
      Color activeColor, Color activeBg, Color disabledColor) {
    final buttons = <Widget>[];
    if (group.foregroundColor) {
      buttons.add(ColorPickerButton(
          icon: Icons.format_color_text,
          currentColor:
              _activeFormats[SmartButtonType.foregroundColor] as Color?,
          tooltip: 'Text Color',
          enabled: _enabled,
          onColorChanged: (color) =>
              _onToolbarAction(SmartButtonType.foregroundColor, value: color)));
    }
    if (group.highlightColor) {
      buttons.add(ColorPickerButton(
          icon: Icons.color_lens,
          currentColor:
              _activeFormats[SmartButtonType.highlightColor] as Color?,
          tooltip: 'Highlight Color',
          enabled: _enabled,
          onColorChanged: (color) =>
              _onToolbarAction(SmartButtonType.highlightColor, value: color)));
    }
    return buttons;
  }

  List<Widget> _buildParagraphButtons(SmartParagraphButtons group,
      Color onSurface, Color activeColor, Color activeBg, Color disabledColor) {
    final buttons = <Widget>[];
    if (group.alignLeft) {
      buttons.add(_ToolbarButton(
          icon: Icons.format_align_left,
          isActive: _activeFormats[SmartButtonType.alignLeft] == true,
          onPressed: () => _onToolbarAction(SmartButtonType.alignLeft,
              value: SmartTextAlign.left),
          activeColor: activeColor,
          activeBg: activeBg,
          onSurface: onSurface,
          disabledColor: disabledColor,
          enabled: _enabled,
          size: widget.settings.itemHeight,
          iconSize: widget.settings.buttonIconSize,
          tooltip: 'Align Left'));
    }
    if (group.alignCenter) {
      buttons.add(_ToolbarButton(
          icon: Icons.format_align_center,
          isActive: _activeFormats[SmartButtonType.alignCenter] == true,
          onPressed: () => _onToolbarAction(SmartButtonType.alignCenter,
              value: SmartTextAlign.center),
          activeColor: activeColor,
          activeBg: activeBg,
          onSurface: onSurface,
          disabledColor: disabledColor,
          enabled: _enabled,
          size: widget.settings.itemHeight,
          iconSize: widget.settings.buttonIconSize,
          tooltip: 'Align Center'));
    }
    if (group.alignRight) {
      buttons.add(_ToolbarButton(
          icon: Icons.format_align_right,
          isActive: _activeFormats[SmartButtonType.alignRight] == true,
          onPressed: () => _onToolbarAction(SmartButtonType.alignRight,
              value: SmartTextAlign.right),
          activeColor: activeColor,
          activeBg: activeBg,
          onSurface: onSurface,
          disabledColor: disabledColor,
          enabled: _enabled,
          size: widget.settings.itemHeight,
          iconSize: widget.settings.buttonIconSize,
          tooltip: 'Align Right'));
    }
    if (group.alignJustify) {
      buttons.add(_ToolbarButton(
          icon: Icons.format_align_justify,
          isActive: _activeFormats[SmartButtonType.alignJustify] == true,
          onPressed: () => _onToolbarAction(SmartButtonType.alignJustify,
              value: SmartTextAlign.justify),
          activeColor: activeColor,
          activeBg: activeBg,
          onSurface: onSurface,
          disabledColor: disabledColor,
          enabled: _enabled,
          size: widget.settings.itemHeight,
          iconSize: widget.settings.buttonIconSize,
          tooltip: 'Align Justify'));
    }
    return buttons;
  }

  // ─── List ──────────────────────────────────────────────────────────────

  void _showBulletStylePicker(
      BuildContext context, SmartListButtons group, Color activeColor) {
    if (!_enabled || !_isBulletList) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final styles = group.availableStyles ?? SmartBulletStyle.values;
        // Helper to get symbol for style
        String getSymbol(SmartBulletStyle style) {
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

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bullet Style',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(styles.length, (i) {
                  return GestureDetector(
                    onTap: () {
                      final blockIndex = widget.getFocusedBlockIndex();
                      widget.documentController
                          .setBulletStyle(blockIndex, styles[i]);
                      widget.onFormatApplied?.call();
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: activeColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: activeColor.withValues(alpha: 0.2)),
                      ),
                      child: Center(
                        child: Text(getSymbol(styles[i]),
                            style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildListButtons(SmartListButtons group, Color onSurface,
      Color activeColor, Color activeBg, Color disabledColor) {
    final buttons = <Widget>[];
    if (group.ul) {
      buttons.add(_ToolbarButton(
        icon: Icons.format_list_bulleted,
        isActive: _isBulletList,
        onPressed: () => _onToolbarAction(SmartButtonType.bulletList),
        activeColor: activeColor,
        activeBg: activeBg,
        onSurface: onSurface,
        disabledColor: disabledColor,
        enabled: _enabled,
        size: widget.settings.itemHeight,
        iconSize: widget.settings.buttonIconSize,
        tooltip: 'Bullet List',
      ));
    }

    if (group.listStyles && _isBulletList) {
      buttons.add(_ToolbarButton(
        icon: Icons.expand_circle_down_outlined,
        isActive: false,
        onPressed: () => _showBulletStylePicker(context, group, activeColor),
        activeColor: activeColor,
        activeBg: activeBg,
        onSurface: onSurface,
        disabledColor: disabledColor,
        enabled: _enabled,
        size: widget.settings.itemHeight,
        iconSize: widget.settings.buttonIconSize - 2,
        tooltip: 'Bullet Style',
      ));
    }

    if (group.ol) {
      buttons.add(_ToolbarButton(
        icon: Icons.format_list_numbered,
        isActive: _isOrderedList,
        onPressed: () => _onToolbarAction(SmartButtonType.orderedList),
        activeColor: activeColor,
        activeBg: activeBg,
        onSurface: onSurface,
        disabledColor: disabledColor,
        enabled: _enabled,
        size: widget.settings.itemHeight,
        iconSize: widget.settings.buttonIconSize,
        tooltip: 'Ordered List',
      ));
    }

    if (group.hr) {
      buttons.add(_ToolbarButton(
        icon: Icons.horizontal_rule_rounded,
        isActive: false,
        onPressed: () => _onToolbarAction(SmartButtonType.horizontalRule),
        activeColor: activeColor,
        activeBg: activeBg,
        onSurface: onSurface,
        disabledColor: disabledColor,
        enabled: _enabled,
        size: widget.settings.itemHeight,
        iconSize: widget.settings.buttonIconSize,
        tooltip: 'Insert Divider',
      ));
    }

    return buttons;
  }

  List<Widget> _buildInsertButtons(SmartInsertButtons group, Color onSurface,
      Color activeColor, Color activeBg, Color disabledColor) {
    final buttons = <Widget>[];
    // Future insert buttons (Link, Image, etc.) could go here
    return buttons;
  }

  List<Widget> _buildOtherButtons(SmartOtherButtons group, Color onSurface,
      Color activeColor, Color activeBg, Color disabledColor) {
    final buttons = <Widget>[];

    if (group.undo) {
      buttons.add(_ToolbarButton(
        icon: Icons.undo_rounded,
        isActive: false,
        onPressed: () => _onToolbarAction(SmartButtonType.undo),
        activeColor: activeColor,
        activeBg: activeBg,
        onSurface: onSurface,
        disabledColor: disabledColor,
        enabled: _enabled && widget.documentController.canUndo,
        size: widget.settings.itemHeight,
        iconSize: widget.settings.buttonIconSize,
        tooltip: 'Undo',
      ));
    }

    if (group.redo) {
      buttons.add(_ToolbarButton(
        icon: Icons.redo_rounded,
        isActive: false,
        onPressed: () => _onToolbarAction(SmartButtonType.redo),
        activeColor: activeColor,
        activeBg: activeBg,
        onSurface: onSurface,
        disabledColor: disabledColor,
        enabled: _enabled && widget.documentController.canRedo,
        size: widget.settings.itemHeight,
        iconSize: widget.settings.buttonIconSize,
        tooltip: 'Redo',
      ));
    }

    if (group.copy) {
      buttons.add(_ToolbarButton(
        icon: Icons.content_copy_rounded,
        isActive: false,
        onPressed: () => _onToolbarAction(SmartButtonType.copy),
        activeColor: activeColor,
        activeBg: activeBg,
        onSurface: onSurface,
        disabledColor: disabledColor,
        enabled: _enabled,
        size: widget.settings.itemHeight,
        iconSize: widget.settings.buttonIconSize - 2,
        tooltip: 'Copy',
      ));
    }

    if (group.paste) {
      buttons.add(_ToolbarButton(
        icon: Icons.content_paste_rounded,
        isActive: false,
        onPressed: () => _onToolbarAction(SmartButtonType.paste),
        activeColor: activeColor,
        activeBg: activeBg,
        onSurface: onSurface,
        disabledColor: disabledColor,
        enabled: _enabled,
        size: widget.settings.itemHeight,
        iconSize: widget.settings.buttonIconSize - 2,
        tooltip: 'Paste',
      ));
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
