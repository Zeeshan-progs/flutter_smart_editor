import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/document.dart';
import '../models/enums.dart';
import '../models/editor_settings.dart';

// ─── Rich Text Controller ───────────────────────────────────────────────

class _RichTextEditingController extends TextEditingController {
  _RichTextEditingController({super.text});

  void refresh() => notifyListeners();

  List<TextFormatSpan> formatSpans = [];
  double baseFontSize = 16.0;
  FontWeight baseFontWeight = FontWeight.normal;
  Color defaultColor = Colors.black;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (formatSpans.isEmpty || text.isEmpty) {
      return TextSpan(
        text: text,
        style: style?.copyWith(
          fontSize: baseFontSize,
          fontWeight: baseFontWeight,
          color: defaultColor,
        ),
      );
    }

    final children = <TextSpan>[];
    var textOffset = 0;

    for (final span in formatSpans) {
      if (textOffset >= text.length) break;

      final spanLength = span.text.length.clamp(0, text.length - textOffset);
      if (spanLength <= 0) continue;

      final spanText = text.substring(textOffset, textOffset + spanLength);

      children.add(TextSpan(
        text: spanText,
        style: _buildSpanStyle(span),
      ));

      textOffset += spanLength;
    }

    if (textOffset < text.length) {
      final lastSpan =
          formatSpans.isNotEmpty ? formatSpans.last : TextFormatSpan.plain('');

      children.add(TextSpan(
        text: text.substring(textOffset),
        style: _buildSpanStyle(lastSpan),
      ));
    }

    // Ensure children inherit the base alignment and other non-inline styles,
    // but the inline styles (color, weight, etc.) from _buildSpanStyle should win.
    return TextSpan(
      style: style,
      children: children,
    );
  }

  TextStyle _buildSpanStyle(TextFormatSpan span) {
    final decorations = <TextDecoration>[];
    if (span.isUnderline) decorations.add(TextDecoration.underline);
    if (span.isStrikethrough) decorations.add(TextDecoration.lineThrough);

    return TextStyle(
      fontWeight: span.isBold || baseFontWeight == FontWeight.bold
          ? FontWeight.bold
          : FontWeight.normal,
      fontStyle: span.isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: decorations.isEmpty
          ? TextDecoration.none
          : TextDecoration.combine(decorations),
      fontSize: span.fontSize ?? baseFontSize,
      color: span.foregroundColor ?? defaultColor,
      backgroundColor: span.backgroundColor,
      fontFamily: span.fontFamily,
    );
  }
}

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
  late _RichTextEditingController _textController;
  static const String _zwsp = '\u200B';
  bool _isInternalUpdate = false;
  TextSelection _lastReportedSelection =
      const TextSelection.collapsed(offset: 1);

  @override
  void initState() {
    super.initState();
    _textController =
        _RichTextEditingController(text: _zwsp + widget.block.plainText);
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
        // This case is usually handled by ZWSP deletion above,
        // but kept for safety.
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
  /// This is used as the foundational size for the whole block.
  double _getBlockBaseFontSize() {
    if (widget.block is HeadingNode) {
      final heading = (widget.block as HeadingNode);
      switch (heading.level) {
        case 1:
          return 32;
        case 2:
          return 28;
        case 3:
          return 24;
        case 4:
          return 20;
        case 5:
          return 18;
        case 6:
          return 16;
        default:
          return widget.editorSettings.defaultFontSize;
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
      case SmartTextAlign.left:
        return TextAlign.left;
      case SmartTextAlign.center:
        return TextAlign.center;
      case SmartTextAlign.right:
        return TextAlign.right;
      case SmartTextAlign.justify:
        return TextAlign.justify;
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
    // ─── Horizontal Rule ─────────────────────────────────────────────────
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
          // Tab / Shift+Tab for list indent
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
                ? StrutStyle(
                    fontSize: widget.pendingFontSize,
                  )
                : StrutStyle(
                    fontSize: _getCursorFontSize(),
                  ),
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

    // Only apply the horizontal handle space if:
    // 1. This specific block has a drag handle visible (isDraggable).
    // 2. This is a list item and lists are draggable (to maintain alignment
    //    with the first item in the list).
    final needsHandleSpace =
        isDraggable || (widget.block is ListItemNode && isBlockTypeDraggable);

    if (!needsHandleSpace) {
      return content;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Always reserve the same width for the drag handle area
        // to maintain symmetric alignment across all blocks.
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

  /// Builds the list item wrapper with depth indent and bullet/number indicator.
  Widget _buildListItemWrapper(BuildContext context, Widget textField) {
    final item = widget.block as ListItemNode;
    final depth = item.depth.clamp(0, 3);
    final indent = depth * 24.0;
    final indicator = _buildIndicator(context, item);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: indent),
        SizedBox(
          width: 28,
          child: Padding(
            padding: const EdgeInsets.only(top: 3.0),
            child: indicator,
          ),
        ),
        Expanded(child: textField),
      ],
    );
  }

  /// Builds the bullet or number indicator for a list item.
  Widget _buildIndicator(BuildContext context, ListItemNode item) {
    final defaultColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final fontSize = widget.editorSettings.defaultFontSize;

    if (item.listType == SmartListType.ordered) {
      final label = _orderedLabel(widget.orderedCount, item.depth);
      return Text(label,
          style: TextStyle(fontSize: fontSize, color: defaultColor),
          textAlign: TextAlign.right);
    }

    // Bullet
    final bulletStyle =
        item.bulletStyle ?? widget.editorSettings.defaultBulletStyle;
    final symbol = _bulletSymbol(bulletStyle);
    return Text(symbol,
        style: TextStyle(fontSize: fontSize, color: defaultColor),
        textAlign: TextAlign.center);
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
      'm',
      'cm',
      'd',
      'cd',
      'c',
      'xc',
      'l',
      'xl',
      'x',
      'ix',
      'v',
      'iv',
      'i'
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
    // If no explicit style, use depth-based default
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

  /// Builds the horizontal rule divider widget.
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

    if (!isDraggable) {
      return divider;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildDragHandle(),
        Expanded(child: divider),
      ],
    );
  }
}
