import 'package:flutter/material.dart';
import '../core/document.dart';
import '../core/document_controller.dart';
import '../core/html_serializer.dart';
import '../models/editor_settings.dart';
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
    this.onFormatStateChanged,
  });

  final DocumentController documentController;
  final SmartEditorSettings editorSettings;

  /// Internal callback to update toolbar state when formatting changes
  final void Function(int blockIndex, Map<String, dynamic> formats)?
      onFormatStateChanged;

  @override
  State<SmartEditorWidget> createState() => SmartEditorWidgetState();
}

class SmartEditorWidgetState extends State<SmartEditorWidget> {
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, GlobalKey<BlockWidgetState>> _blockKeys = {};
  final SmartHtmlSerializer _serializer = SmartHtmlSerializer();
  int _focusedBlockIndex = 0;
  bool _initialized = false;

  /// Pending format state — set when user toggles formatting at cursor
  /// position (no text selected). Applied to the next text input.
  TextFormatSpan? _pendingFormat;
  int? _pendingFormatOffset;
  int? _pendingFormatBlockIndex;

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
        widget.editorSettings.onInit?.call();

        if (widget.editorSettings.autofocus && _document.blocks.isNotEmpty) {
          _focusNodes[_document.blocks[0].id]?.requestFocus();
        }
      }
    });
  }

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  /// Synchronizes the focus nodes and block keys with the document blocks
  void _syncFocusNodes() {
    final currentIds = _document.blocks.map((b) => b.id).toSet();

    // Add new ones
    for (final block in _document.blocks) {
      if (!_focusNodes.containsKey(block.id)) {
        _focusNodes[block.id] = FocusNode();
        _blockKeys[block.id] =
            GlobalKey<BlockWidgetState>(debugLabel: block.id);
      }
    }

    // Remove old ones
    final toRemove =
        _focusNodes.keys.where((id) => !currentIds.contains(id)).toList();
    for (final id in toRemove) {
      _focusNodes.remove(id)?.dispose();
      _blockKeys.remove(id);
    }
  }

  /// Notifies the content change callback
  void _notifyContentChanged() {
    final html = _serializer.serialize(_document);
    widget.editorSettings.onChangeContent?.call(html);
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
    widget.editorSettings.onEnter?.call();

    final newBlockIndex = _docController.splitBlock(
      blockIndex,
      offset,
      pendingFormat: _pendingFormat,
    );

    // Clear pending format on Enter
    _pendingFormat = null;

    setState(() {
      _syncFocusNodes();
    });

    // Focus the new block after rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (newBlockIndex < _document.blocks.length) {
        final id = _document.blocks[newBlockIndex].id;
        _focusNodes[id]?.requestFocus();
        _blockKeys[id]?.currentState?.setCursorPosition(0);
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
      if (targetIndex < _document.blocks.length) {
        final id = _document.blocks[targetIndex].id;
        _focusNodes[id]?.requestFocus();
        _blockKeys[id]?.currentState?.setCursorPosition(cursorOffset);
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
      if (blockIndex < _document.blocks.length) {
        final id = _document.blocks[blockIndex].id;
        _focusNodes[id]?.requestFocus();
        _blockKeys[id]?.currentState?.setCursorPosition(cursorOffset);
      }
    });

    _notifyContentChanged();
  }

  /// Handles paste events from the BlockWidget
  void _onPaste(int blockIndex) async {
    try {
      final reader = await SystemClipboard.instance?.read();
      if (reader != null && reader.canProvide(Formats.htmlText)) {
        final html = await reader.readValue(Formats.htmlText);
        if (html != null && html.isNotEmpty) {
          final parser = SmartHtmlParser();
          final parsed = parser.parse(html);
          if (parsed.blocks.isNotEmpty) {
            _docController.insertParsedDocument(
              blockIndex,
              _blockKeys[_document.blocks[blockIndex].id]
                      ?.currentState
                      ?.cursorOffset ??
                  0,
              parsed,
            );
            rebuild();
            return;
          }
        }
      }

      // Fallback: Check if there is plain text
      if (reader != null && reader.canProvide(Formats.plainText)) {
        final text = await reader.readValue(Formats.plainText);
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
                _blockKeys[_document.blocks[blockIndex].id]
                        ?.currentState
                        ?.cursorOffset ??
                    0,
                parsed,
              );
              rebuild();
              return;
            }
          }

          _docController.insertText(
            blockIndex,
            _blockKeys[_document.blocks[blockIndex].id]
                    ?.currentState
                    ?.cursorOffset ??
                0,
            text,
          );
          rebuild();
        }
      }
      widget.editorSettings.onPaste?.call();
    } catch (e) {
      debugPrint('Paste error: $e');
    }
  }

  /// Called when focus changes on a block
  void _onFocusChanged(int blockIndex, bool hasFocus) {
    if (hasFocus) {
      _focusedBlockIndex = blockIndex;
      widget.editorSettings.onFocus?.call();

      KeyboardDoneOverlay.show(context);

      // Clear pending format when changing blocks
      if (blockIndex != _pendingFormatBlockIndex) {
        _pendingFormat = null;
        _pendingFormatOffset = null;
        _pendingFormatBlockIndex = null;
      }

      // Report current formatting at the cursor
      final formats = _getMergedFormats(blockIndex, 0);
      widget.editorSettings.onChangeSelection?.call(formats);
      widget.onFormatStateChanged?.call(blockIndex, formats);
    } else {
      widget.editorSettings.onBlur?.call();

      // Delay hiding slightly to prevent flickering when moving between blocks
      Future.delayed(const Duration(milliseconds: 50), () {
        final anyFocused = _focusNodes.values.any((node) => node.hasFocus);
        if (!anyFocused) {
          KeyboardDoneOverlay.hide();
        }
      });
    }
  }

  /// Called when selection changes in a block (from tap or keyboard navigation)
  void _onSelectionChanged(int blockIndex, int baseOffset, int extentOffset) {
    _focusedBlockIndex = blockIndex;

    // Clear pending format when cursor moves significantly
    if (baseOffset != _pendingFormatOffset || blockIndex != _pendingFormatBlockIndex) {
      _pendingFormat = null;
      _pendingFormatOffset = null;
      _pendingFormatBlockIndex = null;
    }

    final formats = _getMergedFormats(blockIndex, baseOffset);
    widget.editorSettings.onChangeSelection?.call(formats);
    widget.onFormatStateChanged?.call(blockIndex, formats);
  }

  /// Sets a pending format for the next typed character.
  /// Called by the toolbar when user toggles Bold/Italic/etc at cursor position.
  void setPendingFormat(Map<String, dynamic> formats) {
    final blockIndex = _focusedBlockIndex;

    // Get the current span's format at cursor position as a base
    final block = _document.blocks[blockIndex];
    final cursorOffset = _blockKeys[block.id]?.currentState?.cursorOffset ?? 0;
    final loc = block.getSpanAt(cursorOffset);
    final baseSpan = block.spans[loc.spanIndex];

    _pendingFormat = baseSpan.copyWith(
      text: '', // text will be set when applied
      isBold: (formats['bold'] as bool?) ?? baseSpan.isBold,
      isItalic: (formats['italic'] as bool?) ?? baseSpan.isItalic,
      isUnderline: (formats['underline'] as bool?) ?? baseSpan.isUnderline,
      isStrikethrough:
          (formats['strikethrough'] as bool?) ?? baseSpan.isStrikethrough,
      fontFamily: formats.containsKey('fontFamily')
          ? (formats['fontFamily'] as String?)
          : baseSpan.fontFamily,
      fontSize: formats.containsKey('fontSize')
          ? (formats['fontSize'] as double?)
          : baseSpan.fontSize,
      foregroundColor: formats.containsKey('foregroundColor')
          ? (formats['foregroundColor'] as Color?)
          : baseSpan.foregroundColor,
      backgroundColor: formats.containsKey('backgroundColor')
          ? (formats['backgroundColor'] as Color?)
          : baseSpan.backgroundColor,
    );
    _pendingFormatOffset = cursorOffset;
    _pendingFormatBlockIndex = blockIndex;
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
  int? get cursorOffset {
    if (_focusedBlockIndex >= _document.blocks.length) return null;
    return _blockKeys[_document.blocks[_focusedBlockIndex].id]
        ?.currentState
        ?.cursorOffset;
  }

  /// Returns the selection in the focused block
  TextSelection? get selection {
    if (_focusedBlockIndex >= _document.blocks.length) return null;
    return _blockKeys[_document.blocks[_focusedBlockIndex].id]
        ?.currentState
        ?.selection;
  }

  /// Requests focus back to the currently focused block
  void requestEditorFocus() {
    if (_focusedBlockIndex >= 0 && _focusedBlockIndex < _document.blocks.length) {
      final id = _document.blocks[_focusedBlockIndex].id;
      _focusNodes[id]?.requestFocus();
    }
  }

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
        final offset = _blockKeys[_document.blocks[blockIndex].id]
                ?.currentState
                ?.cursorOffset ??
            0;
        final formats = _getMergedFormats(blockIndex, offset);
        widget.onFormatStateChanged?.call(blockIndex, formats);
      }
    });
  }

  /// Merges pending format into the state at the given offset
  Map<String, dynamic> _getMergedFormats(int blockIndex, int offset) {
    var formats = _docController.getFormatAt(blockIndex, offset);

    // Merge pending format if it exists.
    if (_pendingFormat != null) {
      formats['bold'] = _pendingFormat!.isBold;
      formats['italic'] = _pendingFormat!.isItalic;
      formats['underline'] = _pendingFormat!.isUnderline;
      formats['strikethrough'] = _pendingFormat!.isStrikethrough;

      if (_pendingFormat!.foregroundColor != null) {
        formats['foregroundColor'] = _pendingFormat!.foregroundColor;
      }
      if (_pendingFormat!.backgroundColor != null) {
        formats['backgroundColor'] = _pendingFormat!.backgroundColor;
      }
      if (_pendingFormat!.fontSize != null) {
        formats['fontSize'] = _pendingFormat!.fontSize;
      }
      if (_pendingFormat!.fontFamily != null) {
        formats['fontFamily'] = _pendingFormat!.fontFamily;
      }
    }
    return formats;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDarkMode();
    final bgColor = widget.editorSettings.editorBackgroundColor ??
        (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final cursorColor = widget.editorSettings.cursorColor ??
        Theme.of(context).colorScheme.primary;

    return Container(
      decoration: widget.editorSettings.editorDecoration ??
          BoxDecoration(color: bgColor),
      child: SingleChildScrollView(
        physics: widget.editorSettings.scrollPhysics,
        child: Padding(
          padding: widget.editorSettings.editorPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(_document.blocks.length, (index) {
              final block = _document.blocks[index];
              return BlockWidget(
                key: _blockKeys[block.id],
                block: block,
                blockIndex: index,
                focusNode: _focusNodes[block.id]!,
                editorSettings: widget.editorSettings,
                pendingFontSize: (index == _focusedBlockIndex)
                    ? _pendingFormat?.fontSize
                    : null,
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
                cursorWidth: widget.editorSettings.cursorWidth,
                cursorRadius: widget.editorSettings.cursorRadius,
                selectionColor: widget.editorSettings.selectionColor,
                isDarkMode: isDark,
              );
            }),
          ),
        ),
      ),
    );
  }
}
