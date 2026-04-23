import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../smart_editor_controller.dart';
import '../../core/document/document_controller.dart';
import '../../models/enums.dart';
import '../../models/pending_inline_format.dart';
import '../../models/toolbar_settings.dart';
import '../../models/toolbar/toolbar_index.dart';
import 'inputs/font_picker_button.dart';
import 'groups/style_picker_button.dart';
import 'groups/formatting_button_group.dart';
import 'groups/alignment_button_group.dart';
import 'groups/list_button_group.dart';
import 'groups/history_button_group.dart';
import 'groups/color_button_group.dart';

/// A premium Material 3 toolbar for the flutter smart editor.
class SmartToolbar extends StatefulWidget {
  const SmartToolbar({
    super.key,
    required this.documentController,
    required this.controller,
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
  final SmartEditorController controller;
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
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    _safeSetState(() {
      // Rebuild to reflect canCopy / canPaste
    });
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
    } else {
      setState(fn);
    }
  }

  void updateFormatState(
      int blockIndex, Map<SmartButtonType, dynamic> formats) {
    if (!mounted) return;

    _safeSetState(() {
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
      widget.controller.copySelection();
      _finishToolbarAction();
      return;
    }

    if (type == SmartButtonType.paste) {
      widget.controller.pasteContent();
      _syncToolbarAfterDocumentChange();
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
        items.add(StylePickerButton(
          group: group,
          currentBlockType:
              _activeFormats[SmartButtonType.blockType] as BlockType? ??
                  BlockType.paragraph,
          onStyleChanged: (type) =>
              _onToolbarAction(SmartButtonType.blockType, value: type),
          onSurface: onSurface,
          activeColor: activeColor,
          disabledColor: disabledColor,
          enabled: _enabled,
          itemHeight: widget.settings.itemHeight,
        ));
      } else if (group is SmartFontButtons) {
        items.add(FormattingButtonGroup(
          group: group,
          activeFormats: _activeFormats,
          onAction: _onToolbarAction,
          onSurface: onSurface,
          activeColor: activeColor,
          activeBg: activeBg,
          disabledColor: disabledColor,
          enabled: _enabled,
          itemHeight: widget.settings.itemHeight,
          buttonIconSize: widget.settings.buttonIconSize,
        ));
      } else if (group is SmartOtherButtons) {
        items.add(HistoryButtonGroup(
          group: group,
          onAction: _onToolbarAction,
          onSurface: onSurface,
          activeColor: activeColor,
          activeBg: activeBg,
          disabledColor: disabledColor,
          enabled: _enabled,
          itemHeight: widget.settings.itemHeight,
          buttonIconSize: widget.settings.buttonIconSize,
          documentController: widget.documentController,
          editorController: widget.controller,
        ));
      } else if (group is SmartColorButtons) {
        items.add(ColorButtonGroup(
          group: group,
          activeFormats: _activeFormats,
          onAction: _onToolbarAction,
          onSurface: onSurface,
          activeColor: activeColor,
          activeBg: activeBg,
          disabledColor: disabledColor,
          enabled: _enabled,
        ));
      } else if (group is SmartFontFamilyButtons && group.fontFamily) {
        items.add(FontPickerButton(
          currentFont: _activeFormats[SmartButtonType.fontName] as String?,
          enabled: _enabled,
          onFontChanged: (font) =>
              _onToolbarAction(SmartButtonType.fontName, value: font),
        ));
      } else if (group is SmartParagraphButtons) {
        items.add(AlignmentButtonGroup(
          group: group,
          activeFormats: _activeFormats,
          onAction: _onToolbarAction,
          onSurface: onSurface,
          activeColor: activeColor,
          activeBg: activeBg,
          disabledColor: disabledColor,
          enabled: _enabled,
          itemHeight: widget.settings.itemHeight,
          buttonIconSize: widget.settings.buttonIconSize,
        ));
      } else if (group is SmartListButtons) {
        items.add(ListButtonGroup(
          group: group,
          isBulletList: _isBulletList,
          isOrderedList: _isOrderedList,
          onAction: _onToolbarAction,
          onSurface: onSurface,
          activeColor: activeColor,
          activeBg: activeBg,
          disabledColor: disabledColor,
          enabled: _enabled,
          itemHeight: widget.settings.itemHeight,
          buttonIconSize: widget.settings.buttonIconSize,
          documentController: widget.documentController,
          getFocusedBlockIndex: widget.getFocusedBlockIndex,
          onFormatApplied: widget.onFormatApplied,
        ));
      } else if (group is SmartInsertButtons) {
        // Placeholder for future expansion
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

}
