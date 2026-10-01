import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'src/core/document/document.dart';
import 'src/core/document/document_controller.dart';
import 'src/core/infra/html_parser.dart';
import 'src/core/infra/html_serializer.dart';
import 'src/core/document/undo_redo_manager.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'src/models/enums.dart';
import 'src/models/search/search_index.dart';
import 'src/widgets/editor/smart_editor_widget.dart';
import 'src/widgets/toolbar/smart_toolbar_widget.dart';
import 'dart:async';

/// The public controller for [SmartEditor].
///
/// Create an instance and pass it to [SmartEditor]. Use it to
/// programmatically get/set content, apply formatting, manage
/// undo/redo, and more.
///
/// ```dart
/// final controller = SmartEditorController();
///
/// // Get HTML
/// String html = await controller.getText();
///
/// // Set HTML
/// controller.setText('<p>Hello <b>World</b></p>');
/// ```
class SmartEditorController extends ChangeNotifier {
  SmartEditorController({
    this.processInputHtml = true,
    this.processOutputHtml = true,
    this.processNewLineAsBr = false,
  }) {
    _documentController = DocumentController(
      undoRedoManager: _undoRedoManager,
    );
    _documentController.addListener(_onDocumentChanged);
    _documentController.onMessage = (msg) => onMessage?.call(msg);
    _initClipboardListener();
  }

  final bool processInputHtml;
  final bool processOutputHtml;
  final bool processNewLineAsBr;

  bool _canPaste = false;

  /// Callback for providing user feedback (e.g., SnackBars).
  void Function(String message)? onMessage;

  final UndoRedoManager _undoRedoManager = UndoRedoManager();
  late final DocumentController _documentController;
  final SmartHtmlSerializer _serializer = SmartHtmlSerializer();
  final SmartHtmlParser _parser = SmartHtmlParser();

  Timer? _clipboardTimer;

  /// Custom tag serialization callback.
  String? Function(
      SmartTagType type,
      String tag,
      Map<String, String> attributes,
      Map<String, String> styles,
      String content)? onTagSerialize;

  /// Internal references set by the widget
  SmartEditorWidgetState? _editorWidgetState;
  SmartToolbarState? _toolbarState;

  bool _disabled = false;

  /// Register the editor widget (called internally by SmartEditor)
  void attachEditor(SmartEditorWidgetState editor) {
    _editorWidgetState = editor;
  }

  /// Register the toolbar widget (called internally by SmartEditor)
  void attachToolbar(SmartToolbarState toolbar) {
    _toolbarState = toolbar;
  }

  /// The internal document controller
  DocumentController get documentController => _documentController;

  /// The current document
  Document get document => _documentController.document;

  void _onDocumentChanged() {
    _updatePasteState(); // Refresh clipboard state immediately on internal changes
    if (searchState.isBarVisible && searchState.query.isNotEmpty) {
      _performSearch(preferredIndex: searchState.currentMatchIndex);
    }
    _safeNotifyListeners();
  }

  void _safeNotifyListeners() {
    try {
      if (WidgetsBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
        return;
      }
    } catch (_) {
      // Fallback if binding is not initialized
    }
    notifyListeners();
  }

  // ─── Content Methods ──────────────────────────────────────────

  /// Gets the HTML content from the editor.
  Future<String> getText() async {
    _serializer.onTagSerialize = onTagSerialize;
    var html = _serializer.serialize(_documentController.document);

    if (processOutputHtml) {
      if (html == '<p></p>' || html == '<p><br></p>' || html.isEmpty) {
        html = '';
      }
    }

    return html;
  }

  /// Sets the editor content from an HTML string.
  void setText(String html) {
    if (processInputHtml) {
      html = _processInput(html);
    }

    final document = _parser.parse(html);
    _documentController.setDocument(document);
    _editorWidgetState?.rebuild();
  }

  /// Inserts plain text at the current cursor position.
  void insertText(String text) {
    final blockIndex = _editorWidgetState?.focusedBlockIndex ?? 0;
    final offset = _editorWidgetState?.cursorOffset ?? 0;
    final info = focusedTableInfo;
    if (info != null) {
      _documentController.insertCellText(
          info.blockIndex, info.row, info.col, offset, text);
    } else {
      _documentController.insertText(blockIndex, offset, text);
    }
    _editorWidgetState?.rebuild();
  }

  /// Inserts HTML at the current cursor position.
  /// Parses the HTML and inserts the resulting text content.
  void insertHtml(String html) {
    if (processInputHtml) {
      html = _processInput(html);
    }

    final parsed = _parser.parse(html);
    final blockIndex = _editorWidgetState?.focusedBlockIndex ?? 0;
    final offset = _editorWidgetState?.cursorOffset ?? 0;

    if (parsed.blocks.isNotEmpty) {
      final info = focusedTableInfo;
      if (info != null) {
        _documentController.insertCellParsedDocument(
            info.blockIndex, info.row, info.col, offset, parsed);
      } else {
        _documentController.insertParsedDocument(blockIndex, offset, parsed);
      }
      _editorWidgetState?.rebuild();
    }
  }

  /// Clears all content from the editor.
  void clear() {
    _documentController.clear();
    _editorWidgetState?.rebuild();
  }

  // ─── Formatting Methods ───────────────────────────────────────

  /// Toggles bold on the current selection.
  void toggleBold() => _toggleFormat(SmartButtonType.bold);

  /// Toggles italic on the current selection.
  void toggleItalic() => _toggleFormat(SmartButtonType.italic);

  /// Toggles underline on the current selection.
  void toggleUnderline() => _toggleFormat(SmartButtonType.underline);

  /// Toggles strikethrough on the current selection.
  void toggleStrikethrough() => _toggleFormat(SmartButtonType.strikethrough);

  void _toggleFormat(SmartButtonType format) {
    final blockIndex = _editorWidgetState?.focusedBlockIndex ?? 0;
    final selection = _editorWidgetState?.selection;
    if (selection == null || selection.isCollapsed) return;

    final start = selection.start;
    final end = selection.end;

    final info = focusedTableInfo;
    if (info != null) {
      _documentController.toggleCellFormat(
          info.blockIndex, info.row, info.col, start, end, format);
    } else {
      _documentController.toggleFormat(blockIndex, start, end, format);
    }
    _editorWidgetState?.rebuild();
  }

  /// Applies a specific format to the current selection.
  void applyFormat(SmartButtonType format, dynamic value) {
    final blockIndex = _editorWidgetState?.focusedBlockIndex ?? 0;
    final selection = _editorWidgetState?.selection;
    if (selection == null || selection.isCollapsed) return;

    final start = selection.start;
    final end = selection.end;

    final info = focusedTableInfo;
    if (info != null) {
      _documentController.applyCellFormat(
          info.blockIndex, info.row, info.col, start, end, format, value);
    } else {
      _documentController.applyFormat(blockIndex, start, end, format, value);
    }
    _editorWidgetState?.rebuild();
  }

  /// Sets alignment on the current block or table cell.
  void setAlignment(SmartTextAlign alignment) {
    final blockIndex = _editorWidgetState?.focusedBlockIndex ?? 0;
    final info = focusedTableInfo;
    if (info != null) {
      _documentController.setCellAlignment(
          info.blockIndex, info.row, info.col, alignment);
    } else {
      _documentController.setAlignment(blockIndex, alignment);
    }
    _editorWidgetState?.rebuild();
  }

  /// Clears formatting on the current selection.
  void clearFormatting() {
    final blockIndex = _editorWidgetState?.focusedBlockIndex ?? 0;
    final selection = _editorWidgetState?.selection;
    if (selection == null || selection.isCollapsed) return;

    final info = focusedTableInfo;
    if (info != null) {
      _documentController.clearCellFormat(
          info.blockIndex, info.row, info.col, selection.start, selection.end);
    } else {
      _documentController.clearFormat(
          blockIndex, selection.start, selection.end);
    }
    _editorWidgetState?.rebuild();
  }

  /// Returns existing link text and url for the current or specified selection.
  Map<String, String?> getLinkInfo(
      {int? blockIndex, TextSelection? selection}) {
    final effectiveBlockIndex =
        blockIndex ?? _editorWidgetState?.focusedBlockIndex ?? 0;
    final effectiveSelection =
        selection ?? _editorWidgetState?.selectionForToolbar;
    final info = focusedTableInfo;

    if (info != null) {
      if (effectiveSelection != null &&
          effectiveSelection.isValid &&
          !effectiveSelection.isCollapsed) {
        final cell = _documentController.document.blocks[info.blockIndex]
            as TableNode;
        final cellNode = cell.getCell(info.row, info.col);
        final text = cellNode.plainText;
        final selectedText = (effectiveSelection.start >= 0 &&
                effectiveSelection.end <= text.length)
            ? text.substring(effectiveSelection.start, effectiveSelection.end)
            : null;
        final linkInfo = _documentController.getCellLinkInfoAt(
            info.blockIndex, info.row, info.col, effectiveSelection.start);
        return {
          'text': selectedText ?? linkInfo['text'],
          'url': linkInfo['url'],
        };
      } else {
        final offset = effectiveSelection?.start ??
            _editorWidgetState?.cursorOffset ??
            0;
        return _documentController.getCellLinkInfoAt(
            info.blockIndex, info.row, info.col, offset);
      }
    } else {
      if (effectiveSelection != null &&
          effectiveSelection.isValid &&
          !effectiveSelection.isCollapsed) {
        if (effectiveBlockIndex >= 0 &&
            effectiveBlockIndex < _documentController.document.blocks.length) {
          final block =
              _documentController.document.blocks[effectiveBlockIndex];
          final text = block.plainText;
          final selectedText = (effectiveSelection.start >= 0 &&
                  effectiveSelection.end <= text.length)
              ? text.substring(
                  effectiveSelection.start, effectiveSelection.end)
              : null;
          final linkInfo = _documentController.getLinkInfoAt(
              effectiveBlockIndex, effectiveSelection.start);
          return {
            'text': selectedText ?? linkInfo['text'],
            'url': linkInfo['url'],
          };
        }
      } else {
        final offset =
            effectiveSelection?.start ?? _editorWidgetState?.cursorOffset ?? 0;
        return _documentController.getLinkInfoAt(effectiveBlockIndex, offset);
      }
    }
    return {'text': null, 'url': null};
  }

  /// Inserts or applies a hyperlink.
  /// If [selection] is a non-empty range, applies the link to the selection,
  /// or replaces the selected text if [displayText] was modified.
  /// If [selection] is collapsed, inserts a new link span at the cursor.
  void insertLink(
    String url,
    String displayText, {
    int? blockIndex,
    TextSelection? selection,
  }) {
    if (displayText.isEmpty) return;

    final effectiveBlockIndex =
        blockIndex ?? _editorWidgetState?.focusedBlockIndex ?? 0;
    final effectiveSelection =
        selection ?? _editorWidgetState?.selectionForToolbar;
    final info = focusedTableInfo;

    final isRange = effectiveSelection != null &&
        effectiveSelection.isValid &&
        !effectiveSelection.isCollapsed;

    if (info != null) {
      final start = isRange
          ? effectiveSelection.start
          : (effectiveSelection?.start ??
              _editorWidgetState?.cursorOffset ??
              0);
      final end = isRange ? effectiveSelection.end : start;

      final targetCursorOffset = _documentController.setCellLink(
        blockIndex: info.blockIndex,
        row: info.row,
        col: info.col,
        start: start,
        end: end,
        text: displayText,
        url: url,
      );

      _editorWidgetState?.setCursorPosition(
        info.blockIndex,
        targetCursorOffset,
        row: info.row,
        col: info.col,
      );
    } else {
      final start = isRange
          ? effectiveSelection.start
          : (effectiveSelection?.start ??
              _editorWidgetState?.cursorOffset ??
              0);
      final end = isRange ? effectiveSelection.end : start;

      final targetCursorOffset = _documentController.setLink(
        blockIndex: effectiveBlockIndex,
        start: start,
        end: end,
        text: displayText,
        url: url,
      );

      _editorWidgetState?.setCursorPosition(
        effectiveBlockIndex,
        targetCursorOffset,
      );
    }
    _editorWidgetState?.rebuild();
  }

  /// Removes the hyperlink from the current selection or active link span.
  void removeLink({int? blockIndex, TextSelection? selection}) {
    final effectiveBlockIndex =
        blockIndex ?? _editorWidgetState?.focusedBlockIndex ?? 0;
    final effectiveSelection =
        selection ?? _editorWidgetState?.selectionForToolbar;
    final info = focusedTableInfo;

    if (info != null) {
      if (effectiveSelection != null &&
          effectiveSelection.isValid &&
          !effectiveSelection.isCollapsed) {
        _documentController.applyCellLink(info.blockIndex, info.row,
            info.col, effectiveSelection.start, effectiveSelection.end, null);
      } else {
        final offset = effectiveSelection?.start ??
            _editorWidgetState?.cursorOffset ??
            0;
        final cell = _documentController.document.blocks[info.blockIndex]
            as TableNode;
        final cellNode = cell.getCell(info.row, info.col);
        final loc = cellNode.getSpanAt(offset);
        if (loc.spanIndex < cellNode.spans.length) {
          var spanStart = 0;
          for (var i = 0; i < loc.spanIndex; i++) {
            spanStart += cellNode.spans[i].text.length;
          }
          final spanEnd = spanStart + cellNode.spans[loc.spanIndex].text.length;
          _documentController.applyCellLink(info.blockIndex, info.row,
              info.col, spanStart, spanEnd, null);
        }
      }
    } else {
      if (effectiveSelection != null &&
          effectiveSelection.isValid &&
          !effectiveSelection.isCollapsed) {
        _documentController.applyLink(effectiveBlockIndex,
            effectiveSelection.start, effectiveSelection.end, null);
      } else {
        final offset = effectiveSelection?.start ??
            _editorWidgetState?.cursorOffset ??
            0;
        final block =
            _documentController.document.blocks[effectiveBlockIndex];
        final loc = block.getSpanAt(offset);
        if (loc.spanIndex < block.spans.length) {
          var spanStart = 0;
          for (var i = 0; i < loc.spanIndex; i++) {
            spanStart += block.spans[i].text.length;
          }
          final spanEnd = spanStart + block.spans[loc.spanIndex].text.length;
          _documentController.applyLink(
              effectiveBlockIndex, spanStart, spanEnd, null);
        }
      }
    }
    _editorWidgetState?.rebuild();
  }

  // ─── Block Type Methods ───────────────────────────────────────

  /// Changes the current block to a specific heading level (1-6)
  /// or back to paragraph.
  void setBlockType(BlockType type) {
    final blockIndex = _editorWidgetState?.focusedBlockIndex ?? 0;
    final info = focusedTableInfo;
    if (info != null) {
      _documentController.changeCellBlockType(
          info.blockIndex, info.row, info.col, type);
    } else {
      _documentController.changeBlockType(blockIndex, type);
    }
    _editorWidgetState?.rebuild();
  }

  // ─── Undo / Redo ──────────────────────────────────────────────

  /// Undoes the last action.
  void undo() {
    _documentController.undo();
    _editorWidgetState?.rebuild();
  }

  /// Redoes the last undone action.
  void redo() {
    _documentController.redo();
    _editorWidgetState?.rebuild();
  }

  /// Whether there are actions to undo.
  bool get canUndo => _undoRedoManager.canUndo;

  /// Whether there are actions to redo.
  bool get canRedo => _undoRedoManager.canRedo;

  // ─── Editor State ─────────────────────────────────────────────

  /// Enables the editor for editing.
  void enable() {
    _disabled = false;
    _toolbarState?.setEnabled(true);
    _editorWidgetState?.rebuild();
  }

  /// Disables the editor (read-only mode).
  void disable() {
    _disabled = true;
    _toolbarState?.setEnabled(false);
    _editorWidgetState?.rebuild();
  }

  /// Whether the editor is currently disabled.
  bool get isDisabled => _disabled;

  /// Sets focus to the editor.
  void setFocus() {
    _editorWidgetState?.rebuild();
  }

  /// Clears focus from the editor.
  void clearFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// Sets the hint/placeholder text.
  void setHint(String text) {
    // Hint is set via SmartEditorSettings — dynamic updates
    // will be supported in a future version.
  }

  // ─── Find & Replace ───────────────────────────────────────────

  /// Notifier exposing the current state of the Find & Replace overlay and matches.
  final ValueNotifier<SearchState> searchStateNotifier =
      ValueNotifier<SearchState>(SearchState.empty);

  /// Current find and replace state.
  SearchState get searchState => searchStateNotifier.value;

  /// Shows the Find (or Find & Replace) floating bar.
  void showFindReplace({bool showReplace = false}) {
    searchStateNotifier.value = searchState.copyWith(
      isBarVisible: true,
      isReplaceExpanded: showReplace,
    );
    if (searchState.query.isNotEmpty) {
      _performSearch();
    } else {
      _editorWidgetState?.rebuild();
    }
  }

  /// Closes the Find & Replace bar and clears match highlights.
  void hideFindReplace() {
    searchStateNotifier.value = SearchState.empty;
    _editorWidgetState?.rebuild();
    _editorWidgetState?.requestEditorFocus();
  }

  /// Closes any active link preview tooltip overlay.
  void hideLinkTooltip() {
    _editorWidgetState?.hideLinkTooltip();
  }

  /// Sets the active search query and searches the document.
  void setSearchQuery(String query) {
    searchStateNotifier.value = searchState.copyWith(
      query: query,
      clearError: true,
    );
    _performSearch();
  }

  /// Sets the replacement text.
  void setReplaceText(String text) {
    searchStateNotifier.value = searchState.copyWith(replaceText: text);
  }

  /// Updates the active search options and refreshes matches.
  void setSearchOptions(SearchOptions options) {
    searchStateNotifier.value = searchState.copyWith(
      options: options,
      clearError: true,
    );
    _performSearch();
  }

  /// Expands or collapses the Replace row in the overlay.
  void setReplaceExpanded(bool expanded) {
    searchStateNotifier.value =
        searchState.copyWith(isReplaceExpanded: expanded);
  }

  /// Navigates to the next search match.
  void findNext() {
    if (searchState.matches.isEmpty) return;
    final nextIndex =
        (searchState.currentMatchIndex + 1) % searchState.matches.length;
    _navigateToMatch(nextIndex);
  }

  /// Navigates to the previous search match.
  void findPrevious() {
    if (searchState.matches.isEmpty) return;
    final prevIndex = (searchState.currentMatchIndex -
            1 +
            searchState.matches.length) %
        searchState.matches.length;
    _navigateToMatch(prevIndex);
  }

  /// Replaces the currently focused match with [SearchState.replaceText].
  void replaceCurrent() {
    final current = searchState.currentMatch;
    if (current == null) return;

    _documentController.replaceMatch(
      current,
      searchState.replaceText,
      preserveLink: searchState.options.preserveLinkOnReplace,
    );

    _performSearch(preferredIndex: searchState.currentMatchIndex);
  }

  /// Replaces all found occurrences across the document in a single atomic undo step.
  /// Returns the number of occurrences replaced.
  int replaceAll() {
    if (searchState.matches.isEmpty) return 0;

    final count = _documentController.replaceAllMatches(
      searchState.matches,
      searchState.replaceText,
      preserveLinks: searchState.options.preserveLinkOnReplace,
    );

    _performSearch();
    return count;
  }

  void _performSearch({int? preferredIndex}) {
    final query = searchState.query;
    if (query.isEmpty) {
      searchStateNotifier.value = searchState.copyWith(
        matches: const [],
        currentMatchIndex: -1,
        clearError: true,
      );
      _editorWidgetState?.rebuild();
      return;
    }

    try {
      final matches =
          _documentController.findMatches(query, searchState.options);

      int activeIndex = -1;
      if (matches.isNotEmpty) {
        if (preferredIndex != null) {
          activeIndex = preferredIndex.clamp(0, matches.length - 1);
        } else {
          activeIndex = 0;
        }
      }

      searchStateNotifier.value = searchState.copyWith(
        matches: matches,
        currentMatchIndex: activeIndex,
        clearError: true,
      );

      if (activeIndex >= 0 && activeIndex < matches.length) {
        final match = matches[activeIndex];
        _editorWidgetState?.scrollToMatch(match);
        _editorWidgetState?.selectMatch(match);
      }

      _editorWidgetState?.rebuild();
    } on FormatException catch (e) {
      searchStateNotifier.value = searchState.copyWith(
        matches: const [],
        currentMatchIndex: -1,
        errorMessage: e.message,
      );
      _editorWidgetState?.rebuild();
    }
  }

  void _navigateToMatch(int index) {
    if (index < 0 || index >= searchState.matches.length) return;

    searchStateNotifier.value = searchState.copyWith(currentMatchIndex: index);
    final match = searchState.matches[index];
    _editorWidgetState?.scrollToMatch(match);
    _editorWidgetState?.selectMatch(match);
    _editorWidgetState?.rebuild();
  }

  // ─── Character Count ──────────────────────────────────────────

  /// Returns the current character count.
  int get characterCount => _documentController.document.totalLength;

  // ─── Selection / Cursor Getters ───────────────────────────────

  /// Current cursor offset in the focused block (0-based document offset).
  int? get cursorOffset => _editorWidgetState?.cursorOffset;

  /// Sets cursor position in the specified block using 0-based document offset.
  void setCursorPosition(int blockIndex, int docOffset, {int? row, int? col}) {
    _editorWidgetState?.setCursorPosition(blockIndex, docOffset,
        row: row, col: col);
  }

  /// Sets text selection in the specified block using 0-based document offsets.
  void setSelection(int blockIndex, int startOffset, int endOffset,
      {int? row, int? col}) {
    _editorWidgetState?.setSelection(blockIndex, startOffset, endOffset,
        row: row, col: col);
  }

  /// Current selection in the focused block.
  TextSelection? get selection => _editorWidgetState?.selection;

  // ─── Clipboard Methods ─────────────────────────────────────────

  /// Whether there is a selection available to copy.
  bool get canCopy {
    final selection = _editorWidgetState?.selection;
    return selection != null && !selection.isCollapsed;
  }

  /// Whether the system clipboard contains pasteable content.
  bool get canPaste => _canPaste;

  void _initClipboardListener() {
    // In automated widget tests, skip periodic timer to prevent test invariant failures.
    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest && SystemClipboard.instance != null) {
      _clipboardTimer =
          Timer.periodic(const Duration(seconds: 2), (_) => _updatePasteState());
    }
    _updatePasteState(); // Initial check
  }

  Future<void> _updatePasteState() async {
    try {
      final reader = await SystemClipboard.instance?.read();
      final hasContent = reader != null &&
          (reader.canProvide(Formats.htmlText) ||
              reader.canProvide(Formats.plainText));

      if (hasContent != _canPaste) {
        _canPaste = hasContent;
        _safeNotifyListeners();
      }
    } catch (_) {
      // Gracefully ignore clipboard failures in headless/test environments
    }
  }

  /// Copies the current selection to the system clipboard as HTML and Text.
  Future<void> copySelection() async {
    final selection = _editorWidgetState?.selection;
    final blockIndex = _editorWidgetState?.focusedBlockIndex;

    if (selection == null || selection.isCollapsed || blockIndex == null) {
      return;
    }

    final html = _documentController.getSelectedHtml(blockIndex, selection);
    final plainText =
        _documentController.getSelectedPlainText(blockIndex, selection);

    final item = DataWriterItem();
    if (html.isNotEmpty) {
      item.add(Formats.htmlText(html));
    }
    item.add(Formats.plainText(plainText));

    await SystemClipboard.instance?.write([item]);
    await _updatePasteState(); // Refresh canPaste state immediately
    onMessage?.call('Copied to clipboard');
  }

  /// Pastes content from the system clipboard into the editor.
  Future<void> pasteContent() async {
    final blockIndex = _editorWidgetState?.focusedBlockIndex;
    if (blockIndex == null) return;

    final reader = await SystemClipboard.instance?.read();
    if (reader == null) return;

    if (reader.canProvide(Formats.htmlText)) {
      final html = await reader.readValue(Formats.htmlText);
      if (html != null && html.isNotEmpty) {
        insertHtml(html);
        return;
      }
    }

    if (reader.canProvide(Formats.plainText)) {
      final text = await reader.readValue(Formats.plainText);
      if (text != null && text.isNotEmpty) {
        insertText(text);
      }
    }
  }

  @override
  void dispose() {
    _clipboardTimer?.cancel();
    _documentController.removeListener(_onDocumentChanged);
    searchStateNotifier.dispose();
    super.dispose();
  }

  // ─── Internal Helpers ─────────────────────────────────────────

  String _processInput(String html) {
    html = html
        .replaceAll("'", "\\'")
        .replaceAll('"', '\\"')
        .replaceAll('\r', '')
        .replaceAll('\r\n', '');

    if (processNewLineAsBr) {
      html = html.replaceAll('\n', '<br/>');
    } else {
      html = html.replaceAll('\n', '');
    }

    return html;
  }

  // ─── Table Methods ─────────────────────────────────────────────

  /// Returns info about the currently focused table cell, or null.
  ({int blockIndex, int row, int col})? get focusedTableInfo =>
      _editorWidgetState?.focusedTableInfo;

  /// Whether the cursor is currently inside a table cell.
  bool get isInsideTable => focusedTableInfo != null;

  /// Inserts a new table after the currently focused block.
  void insertTable({int rows = 2, int cols = 2}) {
    final blockIndex = _editorWidgetState?.focusedBlockIndex ?? 0;
    _documentController.insertTable(blockIndex, rows: rows, cols: cols);
    _editorWidgetState?.rebuild();
  }

  /// Inserts a row below the currently focused cell.
  void insertRow() {
    final info = focusedTableInfo;
    if (info == null) return;
    _documentController.insertTableRow(info.blockIndex, info.row + 1);
    _editorWidgetState?.rebuild();
  }

  /// Inserts a column to the right of the currently focused cell.
  void insertColumn() {
    final info = focusedTableInfo;
    if (info == null) return;
    _documentController.insertTableColumn(info.blockIndex, info.col + 1);
    _editorWidgetState?.rebuild();
  }

  /// Removes the row at the currently focused cell.
  void deleteRow() {
    final info = focusedTableInfo;
    if (info == null) return;
    _documentController.removeTableRow(info.blockIndex, info.row);
    _editorWidgetState?.rebuild();
  }

  /// Removes the column at the currently focused cell.
  void deleteColumn() {
    final info = focusedTableInfo;
    if (info == null) return;
    _documentController.removeTableColumn(info.blockIndex, info.col);
    _editorWidgetState?.rebuild();
  }

  /// Deletes the entire table at the currently focused block.
  void deleteTable() {
    final info = focusedTableInfo;
    if (info == null) return;
    _documentController.deleteTable(info.blockIndex);
    _editorWidgetState?.rebuild();
  }

  // ─── Image Operations ──────────────────────────────────────────

  /// Delegate function to pick an image from device files or gallery.
  /// Should return the image as a base64 Data URL or file/network URL, or null if cancelled.
  Future<String?> Function()? imagePickerDelegate;

  /// Inserts an image block at or after [blockIndex].
  ///
  /// If [blockIndex] is null, inserts at the currently focused block or appends to the document.
  int insertImage({
    required String src,
    String? alt,
    double? width,
    double? height,
    String? caption,
    SmartTextAlign alignment = SmartTextAlign.center,
    int? blockIndex,
  }) {
    final targetIndex = blockIndex ?? _editorWidgetState?.focusedBlockIndex;
    final index = _documentController.insertImage(
      src: src,
      alt: alt,
      width: width,
      height: height,
      caption: caption,
      alignment: alignment,
      blockIndex: targetIndex,
    );
    _editorWidgetState?.rebuild();
    return index;
  }

  /// Updates properties on an existing image block at [blockIndex].
  void updateImage(
    int blockIndex, {
    String? src,
    String? alt,
    double? width,
    double? height,
    String? caption,
    SmartTextAlign? alignment,
  }) {
    _documentController.updateImage(
      blockIndex,
      src: src,
      alt: alt,
      width: width,
      height: height,
      caption: caption,
      alignment: alignment,
    );
    _editorWidgetState?.rebuild();
  }

  /// Sets alignment of an image block at [blockIndex].
  void setImageAlignment(int blockIndex, SmartTextAlign alignment) {
    _documentController.setImageAlignment(blockIndex, alignment);
    _editorWidgetState?.rebuild();
  }

  /// Sets size of an image block at [blockIndex].
  void setImageSize(int blockIndex, {double? width, double? height}) {
    _documentController.setImageSize(blockIndex, width: width, height: height);
    _editorWidgetState?.rebuild();
  }

  /// Removes an image block at [blockIndex].
  void removeImage(int blockIndex) {
    _documentController.removeImage(blockIndex);
    _editorWidgetState?.rebuild();
  }

  /// Gets the [ImageNode] at [blockIndex], or null if not an image.
  ImageNode? getImageNode(int blockIndex) {
    return _documentController.getImageNode(blockIndex);
  }
}

