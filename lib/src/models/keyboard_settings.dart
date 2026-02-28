import 'package:flutter/material.dart';
import 'enums.dart';

/// Keyboard configuration settings.
///
/// Controls virtual keyboard appearance and behavior on mobile devices.
class SmartKeyboardSettings {
  const SmartKeyboardSettings({
    this.inputType = SmartInputType.text,
    this.adjustForKeyboard = true,
    this.keyboardAppearance,
    this.textInputAction,
    this.autofocus = false,
  });

  /// The type of virtual keyboard to display
  final SmartInputType inputType;

  /// Shrinks the editor when the keyboard appears to prevent overlap
  final bool adjustForKeyboard;

  /// Keyboard brightness (light/dark). `null` follows platform default.
  final Brightness? keyboardAppearance;

  /// The action button on the keyboard (e.g. done, newline)
  final TextInputAction? textInputAction;

  /// Whether to automatically focus the editor on load
  final bool autofocus;
}
