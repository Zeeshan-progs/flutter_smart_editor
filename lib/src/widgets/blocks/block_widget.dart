import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/document/document.dart';
import '../../models/enums.dart';
import '../../models/editor_settings.dart';
import 'rich_text_controller.dart';
import 'list_indicator.dart';

// ─── Block Widget ───────────────────────────────────────────────────────
class BlockWidget extends StatefulWidget {
  const BlockWidget({
    super.key,
    required this.block,
    required this.blockIndex,
    required this.focusNode,
    required this.editorSettings,
    required this.onTextChanged,
    required this.onEnter,
    required this.onBackspaceAtStart,
    required this.onDeleteAtEnd,
    required this.onFocusChanged,
    required this.onSelectionChanged,
    required this.onPaste,
    this.pendingFontSize,
    this.readOnly = false,
    this.hint,
    this.isDarkMode = false,
    this.cursorColor,
    this.cursorWidth,
    this.cursorRadius,
    this.selectionColor,
    this.onIncreaseIndent,
    this.onDecreaseIndent,
    this.onHrTap,
    this.orderedCount = 1,
    this.showDragHandle = true,
    this.dragIndex,
  });

  final BlockNode block;
  final int blockIndex;
  final FocusNode focusNode;
  final SmartEditorSettings editorSettings;
  final void Function(int blockIndex, String newText) onTextChanged;
  final void Function(int blockIndex, int offset) onEnter;
  final void Function(int blockIndex) onBackspaceAtStart;
  final void Function(int blockIndex) onDeleteAtEnd;
  final void Function(int blockIndex, bool hasFocus) onFocusChanged;
  final void Function(int blockIndex, int baseOffset, int extentOffset)
      onSelectionChanged;
  final void Function(int blockIndex) onPaste;

  final double? pendingFontSize;
  final bool readOnly;
  final String? hint;
  final bool isDarkMode;
  final Color? cursorColor;
  final double? cursorWidth;
  final Radius? cursorRadius;
  final Color? selectionColor;

  /// The index within the ReorderableListView (may differ from blockIndex due to grouping).
  final int? dragIndex;

  /// Whether to show the drag handle (used for list grouping).
  final bool showDragHandle;

  // List-specific callbacks
  final VoidCallback? onIncreaseIndent;
  final VoidCallback? onDecreaseIndent;

  // HR-specific callbacks
  final void Function(int blockIndex)? onHrTap;

  /// Pre-computed ordered list counter (computed by smart_editor_widget.dart).
  final int orderedCount;

  @override
  State<BlockWidget> createState() => BlockWidgetState();
}

class BlockWidgetState extends State<BlockWidget> {
  late SmartTextEditingController _textController;
  static const String _zwsp = '\u200B';
  bool _isInternalUpdate = false;
  TextSelection _lastReportedSelection =
      const TextSelection.collapsed(offset: 1);

  @override
  void initState() {
    super.initState();
    _textController =
        SmartTextEditingController(text: _zwsp + widget.block.plainText);
    _syncFormatSpans();
    _textController.addListener(_onControllerChanged);
    
    // Initial selection should be at 1
    _textController.selection = const TextSelection.collapsed(offset: 1);
  }

  @override
  void didUpdateWidget(BlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFormatSpans();

    final newText = _zwsp + widget.block.plainText;
    if (_textController.text != newText && !_isInternalUpdate) {
      _isInternalUpdate = true;
      final cursorPos = _textController.selection.baseOffset;
      _textController.text = newText;
      if (cursorPos <= newText.length) {
        _textController.selection = TextSelection.collapsed(
          offset: cursorPos < 1 ? 1 : cursorPos,
        );
      }
      _isInternalUpdate = false;
    }
  }

  void _syncFormatSpans() {
    final defaultColor = widget.isDarkMode ? Colors.white : Colors.black;
    _textController.formatSpans = List.from(widget.block.spans);
    _textController.baseFontSize = _getBlockBaseFontSize();
    _textController.baseFontWeight = _getFontWeight();
    _textController.defaultColor = defaultColor;
    _textController.refresh();

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _textController.removeListener(_onControllerChanged);
    _textController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_isInternalUpdate) return;

    final currentText = _textController.text;

    // Detect backspace at start (ZWSP was deleted)
    if (!currentText.startsWith(_zwsp)) {
      _isInternalUpdate = true;
      // Re-add ZWSP and restore cursor
      _textController.text = _zwsp + currentText;
      _textController.selection = const TextSelection.collapsed(offset: 1);
      _isInternalUpdate = false;

      widget.onBackspaceAtStart(widget.blockIndex);
      return;
    }

    // Snap cursor to prevent moving before ZWSP
    if (_textController.selection.baseOffset == 0) {
      _isInternalUpdate = true;
      _textController.selection = const TextSelection.collapsed(offset: 1);
      _isInternalUpdate = false;
    }

    final plainText = currentText.substring(1); // Exclude ZWSP

    if (plainText != widget.block.plainText) {
      if (plainText.isEmpty && widget.block.plainText.isEmpty) {
        return;
      }

      if (plainText.contains('\n')) {
        final indexOfNewline = plainText.indexOf('\n');
        final cleanedText = plainText.replaceAll('\n', '');

        _isInternalUpdate = true;
        _textController.text = _zwsp + widget.block.plainText;
        _textController.selection =
            TextSelection.collapsed(offset: indexOfNewline + 1);
        _isInternalUpdate = false;

        if (cleanedText != widget.block.plainText) {
          widget.onTextChanged(widget.blockIndex, cleanedText);
        }

        widget.onEnter(widget.blockIndex, indexOfNewline);
        return;
      }

      _isInternalUpdate = true;
      widget.onTextChanged(widget.blockIndex, plainText);
      _isInternalUpdate = false;

      _syncFormatSpans();
    }

    final currentSelection = _textController.selection;
    if (currentSelection != _lastReportedSelection &&
        currentSelection.isValid) {
      _lastReportedSelection = currentSelection;
      widget.onSelectionChanged(
        widget.blockIndex,
        currentSelection.baseOffset,
        currentSelection.extentOffset,
      );
    }
  }

  void setCursorPosition(int offset) {
    final clamped = offset.clamp(0, _textController.text.length);
    _isInternalUpdate = true;
    _textController.selection = TextSelection.collapsed(offset: clamped);
    _lastReportedSelection = _textController.selection;
    _isInternalUpdate = false;
  }

  int get cursorOffset => _textController.selection.baseOffset;
  TextSelection get selection => _textController.selection;
  int get textLength => _textController.text.length;

  void setTextSilently(String text, {int? cursorOffset}) {
    _isInternalUpdate = true;
    _textController.text = text;
    if (cursorOffset != null) {
      _textController.selection =
          TextSelection.collapsed(offset: cursorOffset.clamp(0, text.length));
    }
    _isInternalUpdate = false;
  }

  void refreshFormatting() {
    _syncFormatSpans();
    setState(() {});
  }

  /// Returns the inherent base font size for the block (paragraphs vs headings).
  double _getBlockBaseFontSize() {
    if (widget.block is HeadingNode) {
      final heading = (widget.block as HeadingNode);
      switch (heading.level) {
        case 1: return 32;
        case 2: return 28;
        case 3: return 24;
        case 4: return 20;
        case 5: return 18;
        case 6: return 16;
        default: return widget.editorSettings.defaultFontSize;
      }
    }
    return widget.editorSettings.defaultFontSize;
  }

  /// Returns the font size specifically for the cursor/strut position.
  double _getCursorFontSize() {
    if (_textController.selection.isCollapsed) {
      final offset = _textController.selection.baseOffset;
      final loc = widget.block.getSpanAt(offset);
      final span = widget.block.spans[loc.spanIndex];
      if (span.fontSize != null) return span.fontSize!;
    }
    return _getBlockBaseFontSize();
  }

  FontWeight _getFontWeight() {
    return (widget.block is HeadingNode) ? FontWeight.bold : FontWeight.normal;
  }

  double _getEffectiveCursorHeight() {
    return widget.editorSettings.cursorHeight ??
        (widget.pendingFontSize ?? _getCursorFontSize());
  }

  TextAlign _getTextAlign() {
    switch (widget.block.alignment) {
      case SmartTextAlign.left: return TextAlign.left;
      case SmartTextAlign.center: return TextAlign.center;
      case SmartTextAlign.right: return TextAlign.right;
      case SmartTextAlign.justify: return TextAlign.justify;
    }
  }

  TextStyle _getTextStyle(double defaultFontSize, Color defaultColor) {
    return TextStyle(
      fontSize: _getBlockBaseFontSize(),
      fontWeight: _getFontWeight(),
      height: 1.2,
      color: defaultColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.block is HorizontalRuleNode) {
      return _buildHrWidget(context);
    }

    final defaultColor = widget.isDarkMode ? Colors.white : Colors.black;
    final hintColor = widget.isDarkMode ? Colors.grey[600] : Colors.grey[400];

    final textField = Focus(
      onFocusChange: (hasFocus) {
        widget.onFocusChanged(widget.blockIndex, hasFocus);
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final isCmdPressed = HardwareKeyboard.instance.isMetaPressed;
          final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
          if ((isCmdPressed || isCtrlPressed) &&
              event.logicalKey == LogicalKeyboardKey.keyV) {
            widget.onPaste(widget.blockIndex);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.tab &&
              widget.block is ListItemNode) {
            if (HardwareKeyboard.instance.isShiftPressed) {
              widget.onDecreaseIndent?.call();
            } else {
              widget.onIncreaseIndent?.call();
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is! KeyDownEvent) return;

          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            if (HardwareKeyboard.instance.logicalKeysPressed
                .contains(LogicalKeyboardKey.enter)) {
              widget.onEnter(
                  widget.blockIndex, _textController.selection.baseOffset);
            }
          } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
            if (_textController.selection.baseOffset == 0 &&
                _textController.selection.extentOffset == 0) {
              widget.onBackspaceAtStart(widget.blockIndex);
            }
          } else if (event.logicalKey == LogicalKeyboardKey.delete) {
            if (_textController.selection.baseOffset ==
                _textController.text.length) {
              widget.onDeleteAtEnd(widget.blockIndex);
            }
          }
        },
        child: Theme(
          data: Theme.of(context).copyWith(
            textSelectionTheme: TextSelectionThemeData(
              selectionColor: widget.selectionColor,
              cursorColor: widget.cursorColor,
              selectionHandleColor: widget.editorSettings.selectionHandleColor,
            ),
          ),
          child: TextField(
            controller: _textController,
            focusNode: widget.focusNode,
            readOnly: widget.readOnly,
            maxLines: null,
            textAlign: _getTextAlign(),
            cursorColor: widget.cursorColor,
            cursorWidth: widget.cursorWidth ?? 2.0,
            cursorRadius: widget.cursorRadius,
            cursorHeight: _getEffectiveCursorHeight(),
            strutStyle: widget.pendingFontSize != null
                ? StrutStyle(fontSize: widget.pendingFontSize)
                : StrutStyle(fontSize: _getCursorFontSize()),
            style: _getTextStyle(
                widget.editorSettings.defaultFontSize, defaultColor),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              hintText: widget.hint,
              hintStyle: TextStyle(
                fontSize: _getBlockBaseFontSize(),
                fontWeight: _getFontWeight(),
                color: hintColor,
                height: 1.2,
              ),
            ),
            onTap: () {
              final sel = _textController.selection;
              widget.onSelectionChanged(
                widget.blockIndex,
                sel.baseOffset,
                sel.extentOffset,
              );
            },
            contextMenuBuilder: (context, editableTextState) {
              return AdaptiveTextSelectionToolbar.buttonItems(
                anchors: editableTextState.contextMenuAnchors,
                buttonItems:
                    editableTextState.contextMenuButtonItems.map((item) {
                  if (item.type == ContextMenuButtonType.paste) {
                    return ContextMenuButtonItem(
                      onPressed: () {
                        editableTextState.hideToolbar();
                        widget.onPaste(widget.blockIndex);
                      },
                      type: ContextMenuButtonType.paste,
                    );
                  }
                  return item;
                }).toList(),
              );
            },
          ),
        ),
      ),
    );

    Widget content;
    if (widget.block is ListItemNode) {
      content = _buildListItemWrapper(context, textField);
    } else {
      content = textField;
    }

    final isBlockTypeDraggable = widget.editorSettings.draggableBlockTypes
            ?.contains(widget.block.blockType) ??
        false;

    final isDraggable = widget.showDragHandle && isBlockTypeDraggable;
    final needsHandleSpace =
        isDraggable || (widget.block is ListItemNode && isBlockTypeDraggable);

    if (!needsHandleSpace) {
      return content;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          child: isDraggable ? _buildDragHandle() : const SizedBox.shrink(),
        ),
        Expanded(child: content),
      ],
    );
  }

  Widget _buildDragHandle() {
    return ReorderableDragStartListener(
      index: widget.dragIndex ?? widget.blockIndex,
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Icon(
          Icons.drag_indicator,
          size: 18,
          color: widget.isDarkMode ? Colors.white38 : Colors.black26,
        ),
      ),
    );
  }

  Widget _buildListItemWrapper(BuildContext context, Widget textField) {
    final item = widget.block as ListItemNode;
    final depth = item.depth.clamp(0, 3);
    final indent = depth * 24.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: indent),
        SizedBox(
          width: 28,
          child: Padding(
            padding: const EdgeInsets.only(top: 3.0),
            child: ListItemIndicator(
              item: item,
              orderedCount: widget.orderedCount,
              editorSettings: widget.editorSettings,
              isDarkMode: widget.isDarkMode,
            ),
          ),
        ),
        Expanded(child: textField),
      ],
    );
  }

  Widget _buildHrWidget(BuildContext context) {
    final hrStyle = widget.editorSettings.hrStyle;
    final defaultColor = widget.isDarkMode
        ? Colors.white24
        : Colors.black.withValues(alpha: 0.15);
    final dividerColor = hrStyle.color ?? defaultColor;

    final divider = GestureDetector(
      onTap: () => widget.onHrTap?.call(widget.blockIndex),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: hrStyle.verticalSpacing),
        child: Container(
          height: hrStyle.thickness,
          decoration: BoxDecoration(
            color: dividerColor,
            borderRadius: hrStyle.borderRadius,
          ),
        ),
      ),
    );

    final isDraggable = widget.editorSettings.draggableBlockTypes
            ?.contains(BlockType.horizontalRule) ??
        false;

    if (!isDraggable) return divider;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildDragHandle(),
        Expanded(child: divider),
      ],
    );
  }
}
