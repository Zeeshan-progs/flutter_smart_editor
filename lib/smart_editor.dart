import 'package:flutter/material.dart';
import 'smart_editor_controller.dart';
import 'src/core/html_parser.dart';
import 'src/models/editor_settings.dart';
import 'src/models/toolbar_settings.dart';
import 'src/models/scroll_settings.dart';
import 'src/models/keyboard_settings.dart';
import 'src/models/selection_settings.dart';
import 'src/models/style_settings.dart';
import 'src/models/callbacks.dart';
import 'src/models/enums.dart';
import 'src/widgets/smart_editor_widget.dart';
import 'src/widgets/smart_toolbar_widget.dart';

/// A pure Flutter rich text HTML editor widget.
///
/// [SmartEditor] provides a full-featured WYSIWYG editor with:
/// - Rich text formatting (bold, italic, underline, strikethrough)
/// - Heading styles (H1–H6)
/// - Undo/redo
/// - HTML input/output
/// - Customizable toolbar
/// - Dark mode support
///
/// ```dart
/// final controller = SmartEditorController();
///
/// SmartEditor(
///   controller: controller,
///   editorSettings: SmartEditorSettings(
///     hint: 'Start typing...',
///   ),
/// )
/// ```
class SmartEditor extends StatefulWidget {
  const SmartEditor({
    super.key,
    required this.controller,
    this.editorSettings = const SmartEditorSettings(),
    this.toolbarSettings = const SmartToolbarSettings(),
    this.scrollSettings = const SmartScrollSettings(),
    this.keyboardSettings = const SmartKeyboardSettings(),
    this.selectionSettings = const SmartSelectionSettings(),
    this.styleSettings = const SmartStyleSettings(),
    this.callbacks = const SmartEditorCallbacks(),
  });

  /// The controller for this editor instance.
  final SmartEditorController controller;

  /// Core editor behavior settings.
  final SmartEditorSettings editorSettings;

  /// Toolbar appearance and behavior settings.
  final SmartToolbarSettings toolbarSettings;

  /// Scroll behavior settings.
  final SmartScrollSettings scrollSettings;

  /// Keyboard configuration settings.
  final SmartKeyboardSettings keyboardSettings;

  /// Selection and cursor appearance settings.
  final SmartSelectionSettings selectionSettings;

  /// Visual appearance settings.
  final SmartStyleSettings styleSettings;

  /// Event callbacks.
  final SmartEditorCallbacks callbacks;

  @override
  State<SmartEditor> createState() => _SmartEditorState();
}

class _SmartEditorState extends State<SmartEditor> {
  final GlobalKey<SmartEditorWidgetState> _editorKey =
      GlobalKey<SmartEditorWidgetState>();
  final GlobalKey<SmartToolbarState> _toolbarKey =
      GlobalKey<SmartToolbarState>();
  final SmartHtmlParser _parser = SmartHtmlParser();

  @override
  void initState() {
    super.initState();

    // Parse initial text if provided
    if (widget.editorSettings.initialText != null &&
        widget.editorSettings.initialText!.isNotEmpty) {
      final document = _parser.parse(widget.editorSettings.initialText);
      widget.controller.documentController.document = document;
    }

    // Apply disabled state
    if (widget.editorSettings.disabled) {
      widget.controller.disable();
    }

    // Attach controller to widgets after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_editorKey.currentState != null) {
        widget.controller.attachEditor(_editorKey.currentState!);
      }
      if (_toolbarKey.currentState != null) {
        widget.controller.attachToolbar(_toolbarKey.currentState!);
      }
    });
  }

  /// Determines if dark mode is active
  bool _isDarkMode() {
    final darkMode = widget.editorSettings.darkMode;
    if (darkMode != null) return darkMode;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  /// Called when formatting is applied from the toolbar
  void _onFormatApplied() {
    _editorKey.currentState?.rebuild();
  }

  /// Called when format state changes in the editor
  void _onFormatStateChanged(int blockIndex, Map<String, bool> formats) {
    _toolbarKey.currentState?.updateFormatState(blockIndex, formats);
  }

  /// Called when the toolbar toggles a format at cursor (no selection).
  /// Sets the pending format so the next typed character gets that format.
  void _onPendingFormatChanged(Map<String, bool> formats) {
    _editorKey.currentState?.setPendingFormat(formats);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDarkMode();
    final defaultDecoration = BoxDecoration(
      borderRadius: widget.styleSettings.borderRadius ??
          const BorderRadius.all(Radius.circular(8)),
      border: Border.all(
        color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
        width: 1,
      ),
    );

    final toolbarWidget =
        widget.toolbarSettings.toolbarPosition != SmartToolbarPosition.custom
            ? SmartToolbar(
                key: _toolbarKey,
                documentController: widget.controller.documentController,
                settings: widget.toolbarSettings,
                getFocusedBlockIndex: () =>
                    _editorKey.currentState?.focusedBlockIndex ?? 0,
                getSelection: () => _editorKey.currentState?.selection,
                onFormatApplied: _onFormatApplied,
                onPendingFormatChanged: _onPendingFormatChanged,
                isDarkMode: isDark,
              )
            : null;

    final editorWidget = Expanded(
      child: SmartEditorWidget(
        key: _editorKey,
        documentController: widget.controller.documentController,
        editorSettings: widget.editorSettings,
        scrollSettings: widget.scrollSettings,
        keyboardSettings: widget.keyboardSettings,
        selectionSettings: widget.selectionSettings,
        styleSettings: widget.styleSettings,
        callbacks: widget.callbacks,
        onFormatStateChanged: _onFormatStateChanged,
      ),
    );

    Widget content;
    if (widget.toolbarSettings.toolbarPosition == SmartToolbarPosition.above) {
      content = Column(
        children: [
          if (toolbarWidget != null) toolbarWidget,
          editorWidget,
        ],
      );
    } else if (widget.toolbarSettings.toolbarPosition ==
        SmartToolbarPosition.below) {
      content = Column(
        children: [
          editorWidget,
          if (toolbarWidget != null) toolbarWidget,
        ],
      );
    } else {
      // Custom position — no toolbar in this widget
      content = Column(children: [editorWidget]);
    }

    return Container(
      height: widget.styleSettings.height,
      decoration: widget.styleSettings.decoration ?? defaultDecoration,
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}
