import 'package:flutter/material.dart';
import 'smart_editor_controller.dart';
import 'src/core/html_parser.dart';
import 'src/models/editor_settings.dart';
import 'src/models/toolbar_settings.dart';
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
  });

  /// The controller for this editor instance.
  final SmartEditorController controller;

  /// Comprehensive editor behavior, style, and event settings.
  final SmartEditorSettings editorSettings;

  /// Toolbar appearance and behavior settings.
  final SmartToolbarSettings toolbarSettings;

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

    widget.controller.onTagSerialize = widget.editorSettings.onTagSerialize;
  }

  @override
  void didUpdateWidget(SmartEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editorSettings.onTagSerialize !=
        oldWidget.editorSettings.onTagSerialize) {
      widget.controller.onTagSerialize = widget.editorSettings.onTagSerialize;
    }
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
  void _onFormatStateChanged(int blockIndex, Map<String, dynamic> formats) {
    _toolbarKey.currentState?.updateFormatState(blockIndex, formats);
  }

  /// Called when the toolbar toggles a format at cursor (no selection).
  /// Sets the pending format so the next typed character gets that format.
  void _onPendingFormatChanged(Map<String, dynamic> formats) {
    _editorKey.currentState?.setPendingFormat(formats);
  }

  /// Called when toolbar wants focus back on the editor
  void _onFocusRequested() {
    _editorKey.currentState?.rebuild(); // Trigger any needed UI sync
    _editorKey.currentState?.requestEditorFocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDarkMode();
    final defaultDecoration = BoxDecoration(
      borderRadius: widget.editorSettings.borderRadius ??
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
                onFocusRequested: _onFocusRequested,
                isDarkMode: isDark,
              )
            : null;

    final double fontSize = widget.editorSettings.defaultFontSize;
    final double lineHeight =
        fontSize * 1.3; // Allow a bit more for strut/padding
    final double verticalPadding = widget.editorSettings.editorPadding.vertical;

    final bool hasToolbar =
        widget.toolbarSettings.toolbarPosition != SmartToolbarPosition.custom;
    final double toolbarHeight =
        hasToolbar ? widget.toolbarSettings.itemHeight + 12 : 0;

    final double effectiveMinHeight =
        (1 * lineHeight) + verticalPadding + toolbarHeight;

    double? effectiveMaxHeight;
    if (widget.editorSettings.maxLines != null) {
      effectiveMaxHeight = (widget.editorSettings.maxLines! * lineHeight) +
          verticalPadding +
          toolbarHeight;
    }

    final editorWidget = Flexible(
      fit: FlexFit.loose,
      child: SmartEditorWidget(
        key: _editorKey,
        documentController: widget.controller.documentController,
        editorSettings: widget.editorSettings,
        onFormatStateChanged: _onFormatStateChanged,
      ),
    );

    Widget content;
    if (widget.toolbarSettings.toolbarPosition == SmartToolbarPosition.above) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (toolbarWidget != null) toolbarWidget,
          editorWidget,
        ],
      );
    } else if (widget.toolbarSettings.toolbarPosition ==
        SmartToolbarPosition.below) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          editorWidget,
          if (toolbarWidget != null) toolbarWidget,
        ],
      );
    } else {
      // Custom position — no toolbar in this widget
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [editorWidget],
      );
    }

    return Container(
      constraints: BoxConstraints(
        minHeight: effectiveMinHeight,
        maxHeight: effectiveMaxHeight ?? double.infinity,
      ),
      decoration: widget.editorSettings.decoration ?? defaultDecoration,
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}
