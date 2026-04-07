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

    return TextSpan(style: style, children: children);
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
    _syncFormatSpans();

    final newText = widget.block.plainText;
    if (_textController.text != newText && !_isInternalUpdate) {
      _isInternalUpdate = true;
      final cursorPos = _textController.selection.baseOffset;
      _textController.text = newText;
      if (cursorPos <= newText.length) {
        _textController.selection = TextSelection.collapsed(offset: cursorPos);
      }
      _isInternalUpdate = false;
    }
  }

  void _syncFormatSpans() {
    final defaultColor = widget.isDarkMode ? Colors.white : Colors.black;
    _textController.formatSpans = List.from(widget.block.spans);
    _textController.baseFontSize = _getFontSize();
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
    if (currentText != widget.block.plainText) {
      if (currentText.isEmpty && widget.block.plainText.isEmpty) {
        widget.onBackspaceAtStart(widget.blockIndex);
        return;
      }

      if (currentText.contains('\n')) {
        final indexOfNewline = currentText.indexOf('\n');
        final cleanedText = currentText.replaceAll('\n', '');

        _isInternalUpdate = true;
        _textController.text = widget.block.plainText;
        _textController.selection =
            TextSelection.collapsed(offset: indexOfNewline);
        _isInternalUpdate = false;

        if (cleanedText != widget.block.plainText) {
          widget.onTextChanged(widget.blockIndex, cleanedText);
        }

        widget.onEnter(widget.blockIndex, indexOfNewline);
        return;
      }

      _isInternalUpdate = true;
      widget.onTextChanged(widget.blockIndex, currentText);
      _isInternalUpdate = false;
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

  double _getFontSize() {
    if (widget.pendingFontSize != null) return widget.pendingFontSize!;

    if (_textController.selection.isCollapsed) {
      final offset = _textController.selection.baseOffset;
      final loc = widget.block.getSpanAt(offset);
      final span = widget.block.spans[loc.spanIndex];
      if (span.fontSize != null) return span.fontSize!;
    }

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

  FontWeight _getFontWeight() {
    return (widget.block is HeadingNode) ? FontWeight.bold : FontWeight.normal;
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
      fontSize: _getFontSize(),
      fontWeight: _getFontWeight(),
      height: 1.2,
      color: defaultColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultColor = widget.isDarkMode ? Colors.white : Colors.black;
    final hintColor = widget.isDarkMode ? Colors.grey[600] : Colors.grey[400];

    return Focus(
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
            strutStyle: StrutStyle(
              fontSize: _getFontSize(),
              height: 1.2,
              forceStrutHeight: true,
            ),
            style: _getTextStyle(
                widget.editorSettings.defaultFontSize, defaultColor),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              hintText: widget.hint,
              hintStyle: TextStyle(
                fontSize: _getFontSize(),
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
  }
}
