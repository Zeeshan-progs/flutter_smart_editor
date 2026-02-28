/// Event callbacks for the editor.
///
/// All callbacks are optional. Only the ones you provide will be called.
class SmartEditorCallbacks {
  const SmartEditorCallbacks({
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

  /// Called whenever the HTML content of the editor changes.
  ///
  /// Returns the current HTML string.
  final void Function(String?)? onChangeContent;

  /// Called whenever the cursor position or text selection changes.
  ///
  /// Returns a map of current formatting states at the cursor position:
  /// `{'bold': true, 'italic': false, ...}`
  final void Function(Map<String, bool>)? onChangeSelection;

  /// Called when the editor gains focus.
  final void Function()? onFocus;

  /// Called when the editor loses focus.
  final void Function()? onBlur;

  /// Called when the editor is fully initialized and ready.
  final void Function()? onInit;

  /// Called when the Enter/Return key is pressed.
  final void Function()? onEnter;

  /// Called when a key is released.
  /// Provides the key as a [String].
  final void Function(String?)? onKeyUp;

  /// Called when a key is pressed down.
  /// Provides the key as a [String].
  final void Function(String?)? onKeyDown;

  /// Called when text is pasted into the editor.
  final void Function()? onPaste;
}
