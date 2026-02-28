import 'package:flutter/material.dart';
import '../core/document.dart';
import '../core/document_controller.dart';
import '../core/html_serializer.dart';
import '../models/editor_settings.dart';
import '../models/scroll_settings.dart';
import '../models/keyboard_settings.dart';
import '../models/selection_settings.dart';
import '../models/style_settings.dart';
import '../models/callbacks.dart';
import 'block_widget.dart';
import 'package:super_clipboard/super_clipboard.dart';
import '../core/html_parser.dart';
import 'keyboard_done_overlay.dart';

/// The main editor widget that renders the document as a list of blocks.
///
/// It composes [BlockWidget]s in a scrollable column, manages focus
/// transitions between blocks, and coordinates with [DocumentController]
/// for text operations.
class SmartEditorWidget extends StatefulWidget {
  const SmartEditorWidget({
    super.key,
    required this.documentController,
    this.editorSettings = const SmartEditorSettings(),
    this.scrollSettings = const SmartScrollSettings(),
    this.keyboardSettings = const SmartKeyboardSettings(),
    this.selectionSettings = const SmartSelectionSettings(),
    this.styleSettings = const SmartStyleSettings(),
    this.callbacks = const SmartEditorCallbacks(),
    this.onFormatStateChanged,
  });

  final DocumentController documentController;
  final SmartEditorSettings editorSettings;
  final SmartScrollSettings scrollSettings;
  final SmartKeyboardSettings keyboardSettings;
  final SmartSelectionSettings selectionSettings;
  final SmartStyleSettings styleSettings;
  final SmartEditorCallbacks callbacks;

  /// Internal callback to update toolbar state when formatting changes
  final void Function(int blockIndex, Map<String, bool> formats)?
      onFormatStateChanged;

  @override
  State<SmartEditorWidget> createState() => SmartEditorWidgetState();
}

class SmartEditorWidgetState extends State<SmartEditorWidget> {
  final List<FocusNode> _focusNodes = [];
  final List<GlobalKey<BlockWidgetState>> _blockKeys = [];
  final SmartHtmlSerializer _serializer = SmartHtmlSerializer();
  int _focusedBlockIndex = 0;
  bool _initialized = false;

  /// Pending format state — set when user toggles formatting at cursor
  /// position (no text selected). Applied to the next text input.
  TextFormatSpan? _pendingFormat;

  DocumentController get _docController => widget.documentController;
  Document get _document => _docController.document;

  @override
  void initState() {
    super.initState();
    _syncFocusNodes();

    // Fire onInit after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialized) {
        _initialized = true;
        widget.callbacks.onInit?.call();

        if (widget.keyboardSettings.autofocus && _focusNodes.isNotEmpty) {
          _focusNodes[0].requestFocus();
        }
      }
    });
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// Synchronizes the focus nodes and block keys with the document blocks
  void _syncFocusNodes() {
    while (_focusNodes.length < _document.blocks.length) {
      _focusNodes.add(FocusNode());
      _blockKeys.add(GlobalKey<BlockWidgetState>());
    }
    while (_focusNodes.length > _document.blocks.length) {
      _focusNodes.removeLast().dispose();
      _blockKeys.removeLast();
    }
  }

  /// Notifies the content change callback
  void _notifyContentChanged() {
    final html = _serializer.serialize(_document);
    widget.callbacks.onChangeContent?.call(html);
  }

  /// Called when text in a block changes.
  /// Uses smart diffing to preserve inline formatting.
  void _onTextChanged(int blockIndex, String newText) {
    if (blockIndex < 0 || blockIndex >= _document.blocks.length) return;

    final oldText = _document.blocks[blockIndex].plainText;

    // Use smart diffing to preserve formatting
    _docController.updateBlockText(
      blockIndex,
      oldText,
      newText,
      pendingFormat: _pendingFormat,
    );

    // Clear pending format after it's been applied
    // (but keep it if no text was actually inserted)
    if (_pendingFormat != null && newText.length > oldText.length) {
      _pendingFormat = null;
    }

    setState(() {});
    _notifyContentChanged();
  }

  /// Called when Enter is pressed in a block
  void _onEnter(int blockIndex, int offset) {
    widget.callbacks.onEnter?.call();

    final newBlockIndex = _docController.splitBlock(blockIndex, offset);

    // Clear pending format on Enter
    _pendingFormat = null;

    setState(() {
      _syncFocusNodes();
    });

    // Focus the new block after rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (newBlockIndex < _focusNodes.length) {
        _focusNodes[newBlockIndex].requestFocus();
        _blockKeys[newBlockIndex].currentState?.setCursorPosition(0);
      }
    });

    _notifyContentChanged();
  }

  /// Called when Backspace is pressed at the start of a block
  void _onBackspaceAtStart(int blockIndex) {
    if (blockIndex <= 0) return;

    final cursorOffset = _docController.mergeWithPrevious(blockIndex);
    final targetIndex = blockIndex - 1;

    // Clear pending format on merge
    _pendingFormat = null;

    setState(() {
      _syncFocusNodes();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (targetIndex < _focusNodes.length) {
        _focusNodes[targetIndex].requestFocus();
        _blockKeys[targetIndex].currentState?.setCursorPosition(cursorOffset);
      }
    });

    _notifyContentChanged();
  }

  /// Called when Delete is pressed at the end of a block
  void _onDeleteAtEnd(int blockIndex) {
    if (blockIndex >= _document.blocks.length - 1) return;

    final cursorOffset = _document.blocks[blockIndex].textLength;
    _docController.mergeWithPrevious(blockIndex + 1);

    setState(() {
      _syncFocusNodes();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (blockIndex < _focusNodes.length) {
        _focusNodes[blockIndex].requestFocus();
        _blockKeys[blockIndex].currentState?.setCursorPosition(cursorOffset);
      }
    });

    _notifyContentChanged();
  }

  /// Handles paste events from the BlockWidget
  void _onPaste(int blockIndex) async {
    try {
      final reader = await SystemClipboard.instance?.read();
      debugPrint('PASTE: reader: $reader');
      if (reader != null && reader.canProvide(Formats.htmlText)) {
        final html = await reader.readValue(Formats.htmlText);
        debugPrint('PASTE HTML:\n$html');
        if (html != null && html.isNotEmpty) {
          final parser = SmartHtmlParser();
          final parsed = parser.parse(html);
          if (parsed.blocks.isNotEmpty) {
            _docController.insertParsedDocument(
              blockIndex,
              _blockKeys[blockIndex].currentState?.cursorOffset ?? 0,
              parsed,
            );
            rebuild();
            return;
          }
        }
      }

      // Fallback: Check if there is plain text, maybe it's a URL or just text
      if (reader != null && reader.canProvide(Formats.plainText)) {
        final text = await reader.readValue(Formats.plainText);
        debugPrint('PASTE PLAIN TEXT:\n$text');
        if (text != null && text.isNotEmpty) {
          // If the text looks like raw HTML and processInputHtml is enabled, parse it
          final isLikelyHtml =
              RegExp(r'<[a-z][\s\S]*>', caseSensitive: false).hasMatch(text);
          if (widget.editorSettings.processInputHtml && isLikelyHtml) {
            final parser = SmartHtmlParser();
            final parsed = parser.parse(text);
            if (parsed.blocks.isNotEmpty) {
              _docController.insertParsedDocument(
                blockIndex,
                _blockKeys[blockIndex].currentState?.cursorOffset ?? 0,
                parsed,
              );
              rebuild();
              return;
            }
          }

          _docController.insertText(
            blockIndex,
            _blockKeys[blockIndex].currentState?.cursorOffset ?? 0,
            text,
          );
          rebuild();
        }
      }
    } catch (e) {
      debugPrint('Paste error: $e');
    }
  }

  /// Called when focus changes on a block
  void _onFocusChanged(int blockIndex, bool hasFocus) {
    if (hasFocus) {
      _focusedBlockIndex = blockIndex;
      widget.callbacks.onFocus?.call();

      KeyboardDoneOverlay.show(context);

      // Clear pending format when changing blocks
      _pendingFormat = null;

      // Report current formatting at the cursor
      final formats = _docController.getFormatAt(blockIndex, 0);
      widget.callbacks.onChangeSelection?.call(formats);
      widget.onFormatStateChanged?.call(blockIndex, formats);
    } else {
      widget.callbacks.onBlur?.call();

      // Delay hiding slightly to prevent flickering when moving between blocks
      Future.delayed(const Duration(milliseconds: 50), () {
        final anyFocused = _focusNodes.any((node) => node.hasFocus);
        if (!anyFocused) {
          KeyboardDoneOverlay.hide();
        }
      });
    }
  }

  /// Called when selection changes in a block (from tap or keyboard navigation)
  void _onSelectionChanged(int blockIndex, int baseOffset, int extentOffset) {
    _focusedBlockIndex = blockIndex;

    // Clear pending format when cursor moves
    _pendingFormat = null;

    final formats = _docController.getFormatAt(blockIndex, baseOffset);
    widget.callbacks.onChangeSelection?.call(formats);
    widget.onFormatStateChanged?.call(blockIndex, formats);
  }

  /// Sets a pending format for the next typed character.
  /// Called by the toolbar when user toggles Bold/Italic/etc at cursor position.
  void setPendingFormat(Map<String, bool> formats) {
    final blockIndex = _focusedBlockIndex;

    // Get the current span's format at cursor position as a base
    final block = _document.blocks[blockIndex];
    final cursorOffset = _blockKeys[blockIndex].currentState?.cursorOffset ?? 0;
    final loc = block.getSpanAt(cursorOffset);
    final baseSpan = block.spans[loc.spanIndex];

    _pendingFormat = baseSpan.copyWith(
      text: '', // text will be set when applied
      isBold: formats['bold'] ?? baseSpan.isBold,
      isItalic: formats['italic'] ?? baseSpan.isItalic,
      isUnderline: formats['underline'] ?? baseSpan.isUnderline,
      isStrikethrough: formats['strikethrough'] ?? baseSpan.isStrikethrough,
    );
  }

  /// Determines if dark mode is active
  bool _isDarkMode() {
    final darkMode = widget.editorSettings.darkMode;
    if (darkMode != null) return darkMode;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  /// Returns the currently focused block index
  int get focusedBlockIndex => _focusedBlockIndex;

  /// Returns the cursor offset in the focused block
  int? get cursorOffset =>
      _blockKeys[_focusedBlockIndex].currentState?.cursorOffset;

  /// Returns the selection in the focused block
  TextSelection? get selection =>
      _blockKeys[_focusedBlockIndex].currentState?.selection;

  /// Forces a rebuild of all blocks
  void rebuild() {
    setState(() {
      _syncFocusNodes();
    });
    _notifyContentChanged();

    // After rebuild, report updated formatting to the toolbar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final blockIndex = _focusedBlockIndex;
      if (blockIndex < _document.blocks.length) {
        final offset = _blockKeys[blockIndex].currentState?.cursorOffset ?? 0;
        final formats = _docController.getFormatAt(blockIndex, offset);
        widget.onFormatStateChanged?.call(blockIndex, formats);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDarkMode();
    final bgColor = widget.styleSettings.editorBackgroundColor ??
        (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final cursorColor = widget.selectionSettings.cursorColor ??
        Theme.of(context).colorScheme.primary;

    return Container(
      decoration: widget.styleSettings.editorDecoration ??
          BoxDecoration(color: bgColor),
      child: SingleChildScrollView(
        physics: widget.scrollSettings.scrollPhysics,
        child: Padding(
          padding: widget.styleSettings.editorPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(_document.blocks.length, (index) {
              return BlockWidget(
                key: _blockKeys[index],
                block: _document.blocks[index],
                blockIndex: index,
                focusNode: _focusNodes[index],
                onTextChanged: _onTextChanged,
                onEnter: _onEnter,
                onBackspaceAtStart: _onBackspaceAtStart,
                onDeleteAtEnd: _onDeleteAtEnd,
                onFocusChanged: _onFocusChanged,
                onSelectionChanged: _onSelectionChanged,
                onPaste: _onPaste,
                readOnly: widget.editorSettings.disabled ||
                    widget.editorSettings.readOnly,
                hint: index == 0 ? widget.editorSettings.hint : null,
                cursorColor: cursorColor,
                cursorWidth: widget.selectionSettings.cursorWidth,
                cursorRadius: widget.selectionSettings.cursorRadius,
                selectionColor: widget.selectionSettings.selectionColor,
                isDarkMode: isDark,
              );
            }),
          ),
        ),
      ),
    );
  }
}
