import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../core/document/document.dart';
import '../../../core/document/document_controller.dart';
import '../../../core/infra/html_serializer.dart';
import '../../../models/enums.dart';
import '../../../models/pending_inline_format.dart';
import '../../blocks/block_widget.dart';
import '../../blocks/table_block_widget.dart';
import '../smart_editor_widget.dart';

/// Base state managing editor lifecycle, focus nodes, document bindings, and core rebuilds.
///
/// Defines the core contract and stubs so feature mixins can interact cleanly
/// through [BaseEditorState] without tightly coupling to one another.
abstract class BaseEditorState extends State<SmartEditorWidget> {
  final Map<String, FocusNode> focusNodes = {};
  final Map<String, GlobalKey<BlockWidgetState>> blockKeys = {};
  final Map<String, GlobalKey<TableBlockWidgetState>> tableBlockKeys = {};
  final SmartHtmlSerializer serializer = SmartHtmlSerializer();
  late final ScrollController internalScrollController = ScrollController();

  int focusedBlockIndex = 0;
  bool initialized = false;
  bool isTyping = false;

  /// Pending inline style at caret (no selection). Applied to the next insert.
  PendingInlineFormat? pendingInline;
  int? pendingFormatOffset;
  int? pendingFormatBlockIndex;
  int? pendingFormatCellRow;
  int? pendingFormatCellCol;

  /// Last non-collapsed range, retained when the field loses focus (e.g. toolbar tap).
  TextSelection? toolbarRangeSelection;
  int? toolbarRangeBlockIndex;

  DocumentController get docController => widget.documentController;
  Document get document => docController.document;

  @override
  void initState() {
    super.initState();
    syncFocusNodes();

    docController.addListener(onDocChanged);

    // Connect message callback
    docController.onMessage = (msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
      );
    };

    // Fire onInit after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!initialized) {
        initialized = true;
        widget.editorSettings.onInit?.call();
        if (widget.editorSettings.autofocus && document.blocks.isNotEmpty) {
          focusNodes[document.blocks[0].id]?.requestFocus();
        }
      }
    });
  }

  @override
  void didUpdateWidget(SmartEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.documentController != oldWidget.documentController) {
      oldWidget.documentController.removeListener(onDocChanged);
      widget.documentController.addListener(onDocChanged);
    }
    syncFocusNodes();
  }

  @override
  void dispose() {
    hideLinkTooltip();
    docController.removeListener(onDocChanged);
    for (final node in focusNodes.values) {
      node.dispose();
    }
    internalScrollController.dispose();
    super.dispose();
  }

  @protected
  void onDocChanged() {
    if (!mounted) return;
    hideLinkTooltip();
    rebuild();
  }

  /// Safe setState wrapper that schedules a post-frame callback if called during build
  @protected
  void safeSetState(VoidCallback fn) {
    if (!mounted) return;
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
    } else {
      setState(fn);
    }
  }

  /// Synchronizes the focus nodes and block keys with the document blocks
  @protected
  void syncFocusNodes() {
    final currentIds = document.blocks.map((b) => b.id).toSet();

    // Add new ones
    for (final block in document.blocks) {
      if (!focusNodes.containsKey(block.id)) {
        focusNodes[block.id] = FocusNode();
        blockKeys[block.id] = GlobalKey<BlockWidgetState>(debugLabel: block.id);
      }
    }

    // Remove old ones
    final toRemove =
        focusNodes.keys.where((id) => !currentIds.contains(id)).toList();
    for (final id in toRemove) {
      focusNodes.remove(id)?.dispose();
      blockKeys.remove(id);
    }
  }

  /// Notifies the content change callback
  @protected
  void notifyContentChanged() {
    final html = serializer.serialize(document);
    widget.editorSettings.onChangeContent?.call(html);
  }

  /// Forces a rebuild of all blocks
  void rebuild() {
    safeSetState(() {
      syncFocusNodes();
    });
    notifyContentChanged();
  }

  /// Determines if dark mode is active
  @protected
  bool isDarkMode() {
    final darkMode = widget.editorSettings.darkMode;
    if (darkMode != null) return darkMode;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  /// Requests focus back to the currently focused block
  void requestEditorFocus() {
    if (focusedBlockIndex >= 0 && focusedBlockIndex < document.blocks.length) {
      final id = document.blocks[focusedBlockIndex].id;
      focusNodes[id]?.requestFocus();
    }
  }

  /// Helper to focus a specific block with optional offset
  @protected
  void focusTarget(int targetIndex, {int offset = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (targetIndex >= 0 && targetIndex < document.blocks.length) {
        final id = document.blocks[targetIndex].id;
        focusNodes[id]?.requestFocus();
        blockKeys[id]?.currentState?.setCursorPosition(offset);
      }
    });
  }

  // ─── Shared Virtual Stubs & Static Utilities for Feature Mixins ────────

  /// Normalize raw selection offsets accounting for ZWSP at index 0.
  static TextSelection normalizeTextSelection(TextSelection raw) {
    final base = (raw.baseOffset - 1).clamp(0, 1 << 30);
    final extent = (raw.extentOffset - 1).clamp(0, 1 << 30);
    return TextSelection(baseOffset: base, extentOffset: extent);
  }

  /// Common prefix/suffix diff helper for text editing.
  static int insertOffsetInOldText(String oldText, String newText) {
    if (oldText == newText) return 0;
    int commonPrefix = 0;
    final minLen =
        oldText.length < newText.length ? oldText.length : newText.length;
    while (commonPrefix < minLen &&
        oldText[commonPrefix] == newText[commonPrefix]) {
      commonPrefix++;
    }
    int commonSuffix = 0;
    while (commonSuffix < minLen - commonPrefix &&
        oldText[oldText.length - 1 - commonSuffix] ==
            newText[newText.length - 1 - commonSuffix]) {
      commonSuffix++;
    }
    return commonPrefix;
  }

  /// Stubs implemented/overridden by feature mixins:
  int? get cursorOffset => null;
  TextSelection? get selection => null;
  TextSelection? get selectionForToolbar => null;
  Map<SmartButtonType, dynamic> getToolbarFormatState() => {};
  Map<SmartButtonType, dynamic> getMergedFormats(int blockIndex, int offset) =>
      {};
  void setCursorPosition(int blockIndex, int docOffset, {int? row, int? col}) {}
  void setSelection(int blockIndex, int startOffset, int endOffset,
      {int? row, int? col}) {}
  void setPendingInlineFormat(PendingInlineFormat format) {}
  double? pendingStrutFontSize(int index) => null;
  void onPaste(int blockIndex) {}
  void hideLinkTooltip() {}
  void checkLinkTooltip(int blockIndex, int minOffset, [int? maxOffset]) {}
  void checkCellLinkTooltip(
      int blockIndex, int row, int col, int minOffset, [int? maxOffset]) {}
}
