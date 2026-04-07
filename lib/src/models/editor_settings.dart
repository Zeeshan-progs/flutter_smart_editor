import 'package:flutter/material.dart';
import 'enums.dart';

/// Comprehensive settings for the editor's behavior, style, and events.
///
/// This class merges what was previously split across Editor, Scroll,
/// Keyboard, Selection, Style, and Callbacks settings into a single
/// unified configuration object.
class SmartEditorSettings {
  const SmartEditorSettings({
    // Core & HTML
    this.hint,
    this.initialText,
    this.darkMode,
    this.disabled = false,
    this.readOnly = false,
    this.spellCheck = false,
    this.characterLimit,
    this.maxLines,
    this.processInputHtml = true,
    this.processOutputHtml = true,
    this.processNewLineAsBr = false,
    this.defaultFontSize = 16.0,

    // Scroll & Layout
    this.autoAdjustHeight = true,
    this.ensureVisible = false,
    this.scrollPhysics,

    // Keyboard
    this.inputType = SmartInputType.text,
    this.adjustForKeyboard = true,
    this.keyboardAppearance,
    this.textInputAction,
    this.autofocus = false,

    // Selection & Cursor
    this.selectionColor,
    this.cursorColor,
    this.cursorWidth = 2.0,
    this.cursorRadius,
    this.cursorHeight,
    this.showCursor = true,
    this.selectionHandleColor,
    this.enableInteractiveSelection = true,

    // Style & Decoration
    this.decoration,
    this.editorDecoration,
    this.editorPadding = const EdgeInsets.all(12),
    this.editorBackgroundColor,
    this.borderRadius,

    // Callbacks / Actions
    this.onChangeContent,
    this.onChangeSelection,
    this.onFocus,
    this.onBlur,
    this.onInit,
    this.onEnter,
    this.onKeyUp,
    this.onKeyDown,
    this.onPaste,
  });

  // ─── Core & HTML ──────────────────────────────────────────────

  /// The default font size for the editor
  final double defaultFontSize;

  /// Placeholder text shown when the editor is empty
  final String? hint;

  /// Initial HTML content to pre-fill the editor
  final String? initialText;

  /// Dark mode control (null = system theme)
  final bool? darkMode;

  /// Starts the editor in disabled (non-interactive) mode
  final bool disabled;

  /// Starts the editor in read-only mode (allows selection/copying)
  final bool readOnly;

  /// Enables browser/OS spell checking
  final bool spellCheck;

  /// Maximum number of characters allowed
  final int? characterLimit;

  /// Maximum number of lines (blocks) before the editor starts scrolling
  final int? maxLines;

  /// Whether to process input HTML (clean up quotes, newlines, etc.)
  final bool processInputHtml;

  /// Whether to process output HTML (return "" for empty editor)
  final bool processOutputHtml;

  /// Whether to convert `\n` to `<br>` in input HTML
  final bool processNewLineAsBr;

  // ─── Scroll & Layout ──────────────────────────────────────────

  /// Automatically adjusts editor height to fit content
  final bool autoAdjustHeight;

  /// Scrolls the editor into view when it gains focus
  final bool ensureVisible;

  /// Custom scroll physics for the editor's scroll view
  final ScrollPhysics? scrollPhysics;

  // ─── Keyboard ───────────────────────────────────────────────

  /// The type of virtual keyboard to display
  final SmartInputType inputType;

  /// Shrinks the editor when the keyboard appears
  final bool adjustForKeyboard;

  /// Keyboard brightness (iOS mostly)
  final Brightness? keyboardAppearance;

  /// The action button on the keyboard (done, search, etc.)
  final TextInputAction? textInputAction;

  /// Whether to automatically focus the editor on load
  final bool autofocus;

  // ─── Selection & Cursor ───────────────────────────────────────

  /// Background color of selected text
  final Color? selectionColor;

  /// Color of the blinking vertical cursor
  final Color? cursorColor;

  /// Width of the cursor in logical pixels
  final double cursorWidth;

  /// Rounded corners for the cursor
  final Radius? cursorRadius;

  /// Height of the cursor. `null` uses default.
  final double? cursorHeight;

  /// Whether to show the cursor
  final bool showCursor;

  /// Color of the selection drag handles on mobile
  final Color? selectionHandleColor;

  /// Whether the user can interactively select text
  final bool enableInteractiveSelection;

  // ─── Style & Decoration ───────────────────────────────────────

  /// Decoration around the entire editor container
  final BoxDecoration? decoration;

  /// Decoration around just the text input area
  final BoxDecoration? editorDecoration;

  /// Padding inside the text input area
  final EdgeInsets editorPadding;

  /// Background color of the editor area
  final Color? editorBackgroundColor;

  /// Default border radius if no decoration is provided
  final BorderRadius? borderRadius;

  // ─── Callbacks / Actions ──────────────────────────────────────

  /// Called whenever the HTML content of the editor changes
  final void Function(String?)? onChangeContent;

  /// Called whenever the cursor position or selection changes
  final void Function(Map<String, dynamic>)? onChangeSelection;

  /// Called when the editor gains focus
  final void Function()? onFocus;

  /// Called when the editor loses focus
  final void Function()? onBlur;

  /// Called when the editor is fully initialized
  final void Function()? onInit;

  /// Called when the Enter/Return key is pressed
  final void Function()? onEnter;

  /// Called when a key is released
  final void Function(String?)? onKeyUp;

  /// Called when a key is pressed down
  final void Function(String?)? onKeyDown;

  /// Called when text is pasted into the editor
  final void Function()? onPaste;
}
