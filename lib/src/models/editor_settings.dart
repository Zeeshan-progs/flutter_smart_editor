/// Core editor behavior settings.
///
/// Controls the editor's fundamental behavior like initial text,
/// placeholders, dark mode, and text processing rules.
class SmartEditorSettings {
  const SmartEditorSettings({
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
  });

  /// Placeholder text shown when the editor is empty
  final String? hint;

  /// Initial HTML content to pre-fill the editor
  final String? initialText;

  /// Dark mode control:
  /// - `null` — follows the system theme (default)
  /// - `true` — always dark
  /// - `false` — always light
  final bool? darkMode;

  /// Starts the editor in disabled (non-interactive) mode
  final bool disabled;

  /// Starts the editor in read-only mode. The user can see and select
  /// text but cannot edit it.
  final bool readOnly;

  /// Enables browser/OS spell checking
  final bool spellCheck;

  /// Maximum number of characters allowed. `null` = unlimited.
  final int? characterLimit;

  /// Maximum number of lines (blocks). `null` = unlimited.
  final int? maxLines;

  /// Whether to process input HTML (clean up quotes, newlines, etc.)
  final bool processInputHtml;

  /// Whether to process output HTML (return "" for empty editor instead of <p><br></p>)
  final bool processOutputHtml;

  /// Whether to convert `\n` to `<br>` in input HTML
  final bool processNewLineAsBr;
}
