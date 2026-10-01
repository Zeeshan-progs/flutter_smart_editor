import 'package:flutter/material.dart';
import 'package:super_clipboard/super_clipboard.dart';
import '../../../core/document/document.dart';
import '../../../core/infra/html_parser.dart';
import 'base_editor_state.dart';

/// Mixin handling text input, diffing, and clipboard paste operations for standard blocks.
mixin TextEditorMixin on BaseEditorState {
  /// Called when text in a block changes. Uses smart diffing to preserve inline formatting.
  @protected
  void onTextChanged(int blockIndex, String newText) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;

    isTyping = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) isTyping = false;
    });

    final oldText = document.blocks[blockIndex].plainText;

    final insertAt = BaseEditorState.insertOffsetInOldText(oldText, newText);
    TextFormatSpan? pendingSpan;
    if (pendingInline != null) {
      pendingSpan = pendingInline!.resolveForInsert(
        document.blocks[blockIndex],
        insertAt,
      );
    }

    docController.updateBlockText(
      blockIndex,
      oldText,
      newText,
      pendingFormat: pendingSpan,
    );

    if (pendingInline != null) {
      pendingFormatOffset = insertAt + (newText.length - oldText.length);
      pendingFormatBlockIndex = blockIndex;
    }

    if (toolbarRangeBlockIndex == blockIndex) {
      toolbarRangeSelection = null;
      toolbarRangeBlockIndex = null;
    }

    setState(() {});
    notifyContentChanged();
  }

  /// Handles paste events from the BlockWidget
  @override
  @protected
  void onPaste(int blockIndex) async {
    try {
      final reader = await SystemClipboard.instance?.read();
      if (reader != null && reader.canProvide(Formats.htmlText)) {
        final html = await reader.readValue(Formats.htmlText);
        if (html != null && html.isNotEmpty) {
          final parser = SmartHtmlParser();
          final parsed = parser.parse(html);
          if (parsed.blocks.isNotEmpty) {
            docController.insertParsedDocument(
              blockIndex,
              blockKeys[document.blocks[blockIndex].id]
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
          final isLikelyHtml =
              RegExp(r'<[a-z][\s\S]*>', caseSensitive: false).hasMatch(text);
          if (widget.editorSettings.processInputHtml && isLikelyHtml) {
            final parser = SmartHtmlParser();
            final parsed = parser.parse(text);
            if (parsed.blocks.isNotEmpty) {
              docController.insertParsedDocument(
                blockIndex,
                blockKeys[document.blocks[blockIndex].id]
                        ?.currentState
                        ?.cursorOffset ??
                    0,
                parsed,
              );
              rebuild();
              return;
            }
          }

          docController.insertText(
            blockIndex,
            blockKeys[document.blocks[blockIndex].id]
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
}

/// Backwards-compatibility alias for [TextEditorMixin].
typedef TextEditorState = TextEditorMixin;
