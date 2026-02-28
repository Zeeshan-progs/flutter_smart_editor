import '../core/document.dart';

/// Manages an undo/redo stack of [Document] snapshots.
///
/// Each time a meaningful change is made, call [pushState] with a deep copy
/// of the current document. Then [undo] and [redo] restore previous states.
class UndoRedoManager {
  final List<Document> _undoStack = [];
  final List<Document> _redoStack = [];
  final int _maxHistorySize;

  UndoRedoManager({int maxHistorySize = 100})
      : _maxHistorySize = maxHistorySize;

  /// Pushes a snapshot of the current document state onto the undo stack.
  /// Clears the redo stack (once you make a new change, you can't redo old undone changes).
  void pushState(Document document) {
    _undoStack.add(document.deepCopy());
    _redoStack.clear();

    // Limit the stack size to avoid memory issues
    if (_undoStack.length > _maxHistorySize) {
      _undoStack.removeAt(0);
    }
  }

  /// Undoes the last change, returning the previous document state.
  ///
  /// [currentDocument] is the document's current state, which will be
  /// pushed onto the redo stack.
  ///
  /// Returns `null` if there is nothing to undo.
  Document? undo(Document currentDocument) {
    if (_undoStack.isEmpty) return null;

    // Save current state to redo stack
    _redoStack.add(currentDocument.deepCopy());

    // Pop and return the previous state
    return _undoStack.removeLast();
  }

  /// Redoes the last undone change, returning the restored document state.
  ///
  /// [currentDocument] is the document's current state, which will be
  /// pushed onto the undo stack.
  ///
  /// Returns `null` if there is nothing to redo.
  Document? redo(Document currentDocument) {
    if (_redoStack.isEmpty) return null;

    // Save current state to undo stack
    _undoStack.add(currentDocument.deepCopy());

    // Pop and return the redone state
    return _redoStack.removeLast();
  }

  /// Whether there are any states to undo
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether there are any states to redo
  bool get canRedo => _redoStack.isNotEmpty;

  /// Clears both stacks
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
