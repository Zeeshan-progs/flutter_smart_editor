import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_smart_editor/src/core/document/document.dart';
import '../../infra/html_serializer.dart';
import '../undo_redo_manager.dart';

/// Base controller managing the [Document] state, undo/redo history, and lifecycle.
class BaseDocumentController extends ChangeNotifier {
  Document document;
  final UndoRedoManager undoRedoManager;

  BaseDocumentController({
    Document? document,
    UndoRedoManager? undoRedoManager,
  })  : document = document ?? Document(),
        undoRedoManager = undoRedoManager ?? UndoRedoManager();

  /// Callback for providing user feedback (e.g., SnackBars).
  void Function(String message)? onMessage;

  /// Gets the HTML for a specific selection range within a block.
  String getSelectedHtml(int blockIndex, TextSelection selection) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return '';
    final block = document.blocks[blockIndex];
    if (selection.isCollapsed) return '';

    final start = selection.start;
    final end = selection.end;

    // Create a temporary block to serialize just the selection
    final tempBlock = block.deepCopy();
    _deleteRangeFromBlock(tempBlock, end, tempBlock.textLength - end);
    _deleteRangeFromBlock(tempBlock, 0, start);

    final tempDoc = Document(blocks: [tempBlock]);
    return SmartHtmlSerializer().serialize(tempDoc);
  }

  /// Internal span deletion helper used for selection extraction.
  void _deleteRangeFromBlock(BlockNode block, int offset, int length) {
    if (length <= 0) return;
    final delStart = offset;
    final delEnd = offset + length;
    var current = 0;

    for (var i = 0; i < block.spans.length; i++) {
      final span = block.spans[i];
      final origLen = span.text.length;
      final spanEnd = current + origLen;

      if (spanEnd > delStart && current < delEnd) {
        final localStart = (delStart - current).clamp(0, origLen);
        final localEnd = (delEnd - current).clamp(0, origLen);
        if (localEnd > localStart) {
          span.text = span.text.substring(0, localStart) +
              span.text.substring(localEnd);
          if (span.text.isEmpty) {
            block.spans.removeAt(i);
            i--;
          }
        }
      }
      current = spanEnd;
    }

    if (block.spans.isEmpty) {
      block.spans.add(TextFormatSpan.plain(''));
    }
  }

  /// Gets the plain text for a specific selection range within a block.
  String getSelectedPlainText(int blockIndex, TextSelection selection) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return '';
    final block = document.blocks[blockIndex];
    if (selection.isCollapsed) return '';
    return block.plainText.substring(selection.start, selection.end);
  }

  /// Saves the current state before making a change.
  @protected
  void saveState() {
    undoRedoManager.pushState(document);
  }

  /// Notifies listeners that the document changed.
  @protected
  void notifyChanged() {
    document.normalize();
    notifyListeners();
  }

  /// Manually triggers logic that depends on document changes (e.g. selection updates).
  void refresh() {
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }

  /// Restoration method for undo/redo.
  @protected
  void restoreState(Document state) {
    document = state;
    notifyChanged();
  }

  // ─── History Operations ───────────────────────────────────────

  bool get canUndo => undoRedoManager.canUndo;
  bool get canRedo => undoRedoManager.canRedo;

  void undo() {
    final state = undoRedoManager.undo(document);
    if (state != null) {
      restoreState(state);
    }
  }

  void redo() {
    final state = undoRedoManager.redo(document);
    if (state != null) {
      restoreState(state);
    }
  }

  /// Replaces the current document with [newDoc].
  void setDocument(Document newDoc) {
    saveState();
    document = newDoc;
    notifyChanged();
  }

  /// Clears the document to an empty initial state.
  void clear() {
    saveState();
    document = Document();
    notifyChanged();
  }
}
