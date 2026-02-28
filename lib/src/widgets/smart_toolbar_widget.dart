import 'package:flutter/material.dart';
import '../core/document_controller.dart';
import '../models/enums.dart';
import '../models/toolbar_settings.dart';
import '../models/toolbar_buttons.dart';

/// A premium Material 3 toolbar for the flutter smart editor.
///
/// Displays formatting buttons (Bold, Italic, Underline, etc.) and
/// dropdowns (heading style). Communicates with the [DocumentController]
/// to apply formatting.
class SmartToolbar extends StatefulWidget {
  const SmartToolbar({
    super.key,
    required this.documentController,
    required this.settings,
    required this.getFocusedBlockIndex,
    required this.getSelection,
    this.onFormatApplied,
    this.onPendingFormatChanged,
    this.isDarkMode = false,
  });

  final DocumentController documentController;
  final SmartToolbarSettings settings;
  final int Function() getFocusedBlockIndex;
  final TextSelection? Function() getSelection;
  final VoidCallback? onFormatApplied;

  /// Called when user toggles formatting at cursor (no selection).
  /// Provides the full pending format state to the editor.
  final void Function(Map<String, bool> formats)? onPendingFormatChanged;

  final bool isDarkMode;

  @override
  State<SmartToolbar> createState() => SmartToolbarState();
}

class SmartToolbarState extends State<SmartToolbar> {
  // Formatting state tracked by the toolbar
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  bool _isStrikethrough = false;
  BlockType _currentBlockType = BlockType.paragraph;
  bool _enabled = true;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.settings.initiallyExpanded;
  }

  /// Update the toolbar's formatting state from outside
  void updateFormatState(int blockIndex, Map<String, bool> formats) {
    if (!mounted) return;
    setState(() {
      _isBold = formats['bold'] ?? false;
      _isItalic = formats['italic'] ?? false;
      _isUnderline = formats['underline'] ?? false;
      _isStrikethrough = formats['strikethrough'] ?? false;

      // Update block type
      if (blockIndex >= 0 &&
          blockIndex < widget.documentController.document.blocks.length) {
        _currentBlockType =
            widget.documentController.document.blocks[blockIndex].blockType;
      }
    });
  }

  /// Enable or disable the toolbar
  void setEnabled(bool enabled) {
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
    });
  }

  /// Applies a format toggle — works with both selections and cursor positions
  void _toggleFormat(String format) {
    if (!_enabled) return;

    final blockIndex = widget.getFocusedBlockIndex();
    final selection = widget.getSelection();
    if (selection == null) return;

    if (selection.isCollapsed) {
      // Cursor with no selection — toggle the format state visually
      // and notify the editor of the pending format
      setState(() {
        switch (format) {
          case 'bold':
            _isBold = !_isBold;
            break;
          case 'italic':
            _isItalic = !_isItalic;
            break;
          case 'underline':
            _isUnderline = !_isUnderline;
            break;
          case 'strikethrough':
            _isStrikethrough = !_isStrikethrough;
            break;
        }
      });

      // Notify editor of the full pending format state
      widget.onPendingFormatChanged?.call({
        'bold': _isBold,
        'italic': _isItalic,
        'underline': _isUnderline,
        'strikethrough': _isStrikethrough,
      });
      return;
    }

    // Has a selection — apply format to the selected range
    final start = selection.start;
    final end = selection.end;

    widget.documentController.toggleFormat(blockIndex, start, end, format);
    widget.onFormatApplied?.call();

    // Update local state from the document
    final formats = widget.documentController.getFormatAt(blockIndex, start);
    updateFormatState(blockIndex, formats);
  }

  /// Changes the block type
  void _changeBlockType(BlockType newType) {
    if (!_enabled) return;

    final blockIndex = widget.getFocusedBlockIndex();
    widget.documentController.changeBlockType(blockIndex, newType);
    widget.onFormatApplied?.call();

    setState(() {
      _currentBlockType = newType;
    });
  }

  /// Gets the display name for a block type
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Adaptive colors
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
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
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

  /// Builds the list of toolbar widgets based on settings
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

      // Add separator between groups
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
      }
    }

    return items;
  }

  /// Builds a vertical separator
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

  /// Builds the heading/paragraph style chip selector
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
              border:
                  isSelected ? Border.all(color: activeColor, width: 1) : null,
            ),
            child: Row(
              children: [
                // if (isSelected)
                //   Icon(Icons.check, size: 16, color: activeColor)
                // else
                //   const SizedBox(width: 16),
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
                            : type == BlockType.heading3
                                ? 15
                                : 14,
                    color: isSelected ? activeColor : null,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
      child: _ToolbarChip(
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

  /// Builds font formatting buttons (Bold, Italic, Underline, etc.)
  List<Widget> _buildFontButtons(
    SmartFontButtons group,
    Color onSurface,
    Color activeColor,
    Color activeBg,
    Color disabledColor,
  ) {
    final buttons = <Widget>[];

    if (group.bold) {
      buttons.add(_ToolbarButton(
        icon: Icons.format_bold,
        isActive: _isBold,
        onPressed: () => _toggleFormat('bold'),
        activeColor: activeColor,
        activeBg: activeBg,
        onSurface: onSurface,
        disabledColor: disabledColor,
        enabled: _enabled,
        size: widget.settings.itemHeight,
        iconSize: widget.settings.buttonIconSize,
        tooltip: 'Bold',
      ));
    }
    if (group.italic) {
      buttons.add(_ToolbarButton(
        icon: Icons.format_italic,
        isActive: _isItalic,
        onPressed: () => _toggleFormat('italic'),
        activeColor: activeColor,
        activeBg: activeBg,
        onSurface: onSurface,
        disabledColor: disabledColor,
        enabled: _enabled,
        size: widget.settings.itemHeight,
        iconSize: widget.settings.buttonIconSize,
        tooltip: 'Italic',
      ));
    }
    if (group.underline) {
      buttons.add(_ToolbarButton(
        icon: Icons.format_underlined,
        isActive: _isUnderline,
        onPressed: () => _toggleFormat('underline'),
        activeColor: activeColor,
        activeBg: activeBg,
        onSurface: onSurface,
        disabledColor: disabledColor,
        enabled: _enabled,
        size: widget.settings.itemHeight,
        iconSize: widget.settings.buttonIconSize,
        tooltip: 'Underline',
      ));
    }
    if (group.strikethrough) {
      buttons.add(_ToolbarButton(
        icon: Icons.format_strikethrough,
        isActive: _isStrikethrough,
        onPressed: () => _toggleFormat('strikethrough'),
        activeColor: activeColor,
        activeBg: activeBg,
        onSurface: onSurface,
        disabledColor: disabledColor,
        enabled: _enabled,
        size: widget.settings.itemHeight,
        iconSize: widget.settings.buttonIconSize,
        tooltip: 'Strikethrough',
      ));
    }

    return buttons;
  }

  /// Builds undo/redo and other buttons
  List<Widget> _buildOtherButtons(
    SmartOtherButtons group,
    Color onSurface,
    Color activeColor,
    Color activeBg,
    Color disabledColor,
  ) {
    final buttons = <Widget>[];

    if (group.undo) {
      buttons.add(_ToolbarButton(
        icon: Icons.undo_rounded,
        isActive: false,
        onPressed: () {
          widget.documentController.undo();
          widget.onFormatApplied?.call();
        },
        activeColor: activeColor,
        activeBg: activeBg,
        onSurface: onSurface,
        disabledColor: disabledColor,
        enabled: _enabled,
        size: widget.settings.itemHeight,
        iconSize: widget.settings.buttonIconSize,
        tooltip: 'Undo',
      ));
    }
    if (group.redo) {
      buttons.add(_ToolbarButton(
        icon: Icons.redo_rounded,
        isActive: false,
        onPressed: () {
          widget.documentController.redo();
          widget.onFormatApplied?.call();
        },
        activeColor: activeColor,
        activeBg: activeBg,
        onSurface: onSurface,
        disabledColor: disabledColor,
        enabled: _enabled,
        size: widget.settings.itemHeight,
        iconSize: widget.settings.buttonIconSize,
        tooltip: 'Redo',
      ));
    }

    return buttons;
  }
}

// ─── Premium Toolbar Button Widget ──────────────────────────────────────

/// A single toolbar toggle button with Material 3 styling.
///
/// Shows a rounded, elevated container with icon. Active state uses
/// the primary color fill with a subtle background tint.
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
    this.tooltip,
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
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = !enabled
        ? disabledColor
        : isActive
            ? activeColor
            : onSurface.withValues(alpha: 0.7);

    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      width: size,
      height: size,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: isActive && enabled ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(8),
          splashColor: activeColor.withValues(alpha: 0.15),
          highlightColor: activeColor.withValues(alpha: 0.08),
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: effectiveColor,
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(
        message: tooltip!,
        preferBelow: false,
        child: button,
      );
    }

    return button;
  }
}

// ─── Toolbar Chip (for dropdown triggers) ───────────────────────────────

/// A chip-style button used as a dropdown trigger (e.g. paragraph style).
class _ToolbarChip extends StatelessWidget {
  const _ToolbarChip({
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onSurface,
    required this.disabledColor,
    required this.enabled,
    required this.height,
    this.width,
    this.showDropdownArrow = false,
  });

  final String label;
  final bool isActive;
  final Color activeColor;
  final Color onSurface;
  final Color disabledColor;
  final bool enabled;
  final double height;
  final double? width;
  final bool showDropdownArrow;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = !enabled
        ? disabledColor
        : isActive
            ? activeColor
            : onSurface.withValues(alpha: 0.75);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: height,
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: isActive && enabled
            ? activeColor.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: effectiveColor,
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
          if (showDropdownArrow) ...[
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: effectiveColor,
            ),
          ],
        ],
      ),
    );
  }
}
