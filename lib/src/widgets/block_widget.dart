import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/document.dart';
import '../models/enums.dart';

// ─── Rich Text Controller ───────────────────────────────────────────────

/// A custom [TextEditingController] that renders inline formatting
/// (bold, italic, underline, strikethrough) by building a styled
/// [TextSpan] tree from the block's [TextFormatSpan] list.
class _RichTextEditingController extends TextEditingController {
  _RichTextEditingController({super.text});

  /// The block's formatted spans — set externally whenever the
  /// document model changes.
  List<TextFormatSpan> formatSpans = [];

  /// Base font size (determined by block type: heading vs paragraph)
  double baseFontSize = 16.0;

  /// Base font weight (headings are bold)
  FontWeight baseFontWeight = FontWeight.normal;

  /// Default text color
  Color defaultColor = Colors.black;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // If no format spans or text is empty, use default
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

    // Build children from format spans
    final children = <TextSpan>[];
    var textOffset = 0;

    for (final span in formatSpans) {
      if (textOffset >= text.length) break;

      // Clamp span length to remaining text
      final spanLength = span.text.length.clamp(0, text.length - textOffset);
      if (spanLength <= 0) continue;

      final spanText = text.substring(textOffset, textOffset + spanLength);

      children.add(TextSpan(
        text: spanText,
        style: _buildSpanStyle(span),
      ));

      textOffset += spanLength;
    }

    // If there's remaining text not covered by spans (can happen during typing)
    if (textOffset < text.length) {
      // Use the format of the last span for continuation
      final lastSpan =
          formatSpans.isNotEmpty ? formatSpans.last : TextFormatSpan.plain('');

      children.add(TextSpan(
        text: text.substring(textOffset),
        style: _buildSpanStyle(lastSpan),
      ));
    }

    return TextSpan(style: style, children: children);
  }

  /// Builds a TextStyle from a TextFormatSpan
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
      fontSize: baseFontSize,
      color: span.foregroundColor ?? defaultColor,
      backgroundColor: span.backgroundColor,
      fontFamily: span.fontFamily,
    );
  }
}

// ─── Block Widget ───────────────────────────────────────────────────────

/// Renders a single block (paragraph or heading) as an editable text field
/// with full inline formatting support.
class BlockWidget extends StatefulWidget {
  const BlockWidget({
    super.key,
    required this.block,
    required this.blockIndex,
    required this.focusNode,
    required this.onTextChanged,
    required this.onEnter,
    required this.onBackspaceAtStart,
    required this.onDeleteAtEnd,
    required this.onFocusChanged,
    required this.onSelectionChanged,
    required this.onPaste,
    this.readOnly = false,
    this.hint,
    this.padding = const EdgeInsets.symmetric(vertical: 2),
    this.cursorColor,
    this.cursorWidth = 2.0,
    this.cursorRadius,
    this.selectionColor,
    this.isDarkMode = false,
  });

  final BlockNode block;
  final int blockIndex;
  final FocusNode focusNode;
  final void Function(int blockIndex, String newText) onTextChanged;
  final void Function(int blockIndex, int offset) onEnter;
  final void Function(int blockIndex) onBackspaceAtStart;
  final void Function(int blockIndex) onDeleteAtEnd;
  final void Function(int blockIndex, bool hasFocus) onFocusChanged;
  final void Function(int blockIndex, int baseOffset, int extentOffset)
      onSelectionChanged;
  final void Function(int blockIndex) onPaste;
  final bool readOnly;
  final String? hint;
  final EdgeInsets padding;
  final Color? cursorColor;
  final double cursorWidth;
  final Radius? cursorRadius;
  final Color? selectionColor;
  final bool isDarkMode;

  @override
  State<BlockWidget> createState() => BlockWidgetState();
}

class BlockWidgetState extends State<BlockWidget> {
  late _RichTextEditingController _textController;
  bool _isInternalUpdate = false;
  TextSelection _lastReportedSelection =
      const TextSelection.collapsed(offset: 0);

  @override
  void initState() {
    super.initState();
    _textController = _RichTextEditingController(text: widget.block.plainText);
    _syncFormatSpans();
    _textController.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(BlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Always sync format spans so styling updates are visible
    _syncFormatSpans();

    // Update text if it changed externally
    final newText = widget.block.plainText;
    if (_textController.text != newText && !_isInternalUpdate) {
      _isInternalUpdate = true;
      final cursorPos = _textController.selection.baseOffset;
      _textController.text = newText;
      // Try to preserve cursor position
      if (cursorPos <= newText.length) {
        _textController.selection = TextSelection.collapsed(offset: cursorPos);
      }
      _isInternalUpdate = false;
    }
  }

  /// Syncs the format spans from the document model to the controller
  void _syncFormatSpans() {
    final defaultColor = widget.isDarkMode ? Colors.white : Colors.black;
    _textController.formatSpans = List.from(widget.block.spans);
    _textController.baseFontSize = _getFontSize();
    _textController.baseFontWeight = _getFontWeight();
    _textController.defaultColor = defaultColor;
  }

  @override
  void dispose() {
    _textController.removeListener(_onControllerChanged);
    _textController.dispose();
    super.dispose();
  }

  /// Unified listener for both text changes and selection changes
  void _onControllerChanged() {
    if (_isInternalUpdate) return;

    // Check for text changes
    final currentText = _textController.text;
    if (currentText != widget.block.plainText) {
      _isInternalUpdate = true;
      widget.onTextChanged(widget.blockIndex, currentText);
      _isInternalUpdate = false;
    }

    // Check for selection changes (cursor movement via keyboard arrows, etc.)
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

  /// Sets the cursor position from outside
  void setCursorPosition(int offset) {
    final clamped = offset.clamp(0, _textController.text.length);
    _isInternalUpdate = true;
    _textController.selection = TextSelection.collapsed(offset: clamped);
    _lastReportedSelection = _textController.selection;
    _isInternalUpdate = false;
  }

  /// Gets the current cursor offset
  int get cursorOffset => _textController.selection.baseOffset;

  /// Gets the current selection
  TextSelection get selection => _textController.selection;

  /// Returns the text length
  int get textLength => _textController.text.length;

  /// Sets the text without triggering the change callback
  void setTextSilently(String text, {int? cursorOffset}) {
    _isInternalUpdate = true;
    _textController.text = text;
    if (cursorOffset != null) {
      _textController.selection =
          TextSelection.collapsed(offset: cursorOffset.clamp(0, text.length));
    }
    _isInternalUpdate = false;
  }

  /// Forces a visual refresh of the formatting
  void refreshFormatting() {
    _syncFormatSpans();
    // Force the controller to rebuild its text span
    setState(() {});
  }

  /// Gets the font size for the current block type
  double _getFontSize() {
    if (widget.block is HeadingNode) {
      final level = (widget.block as HeadingNode).level;
      switch (level) {
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
          return 16;
      }
    }
    return 16;
  }

  /// Gets the font weight for the current block type
  FontWeight _getFontWeight() {
    if (widget.block is HeadingNode) {
      return FontWeight.bold;
    }
    return FontWeight.normal;
  }

  /// Gets the text alignment for the block
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

  @override
  Widget build(BuildContext context) {
    final defaultColor = widget.isDarkMode ? Colors.white : Colors.black;
    final hintColor = widget.isDarkMode ? Colors.grey[600] : Colors.grey[400];

    return Padding(
      padding: widget.padding,
      child: Focus(
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
          }
          return KeyEventResult.ignored;
        },
        child: KeyboardListener(
          focusNode: FocusNode(),
          onKeyEvent: (event) {
            if (event is! KeyDownEvent) return;

            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter) {
              widget.onEnter(
                  widget.blockIndex, _textController.selection.baseOffset);
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
          child: TextField(
            controller: _textController,
            focusNode: widget.focusNode,
            readOnly: widget.readOnly,
            maxLines: null,
            textAlign: _getTextAlign(),
            cursorColor: widget.cursorColor,
            cursorWidth: widget.cursorWidth,
            cursorRadius: widget.cursorRadius,
            style: TextStyle(
              fontSize: _getFontSize(),
              fontWeight: _getFontWeight(),
              color: defaultColor,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              hintText: widget.blockIndex == 0 ? widget.hint : null,
              hintStyle: TextStyle(
                fontSize: _getFontSize(),
                fontWeight: _getFontWeight(),
                color: hintColor,
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
  }
}
