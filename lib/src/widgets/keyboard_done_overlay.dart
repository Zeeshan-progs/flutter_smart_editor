import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Manages a sticky "Done" button overlay that appears above the soft keyboard
/// on mobile platforms (iOS/Android) when an editor block gains focus.
class KeyboardDoneOverlay {
  static OverlayEntry? _overlayEntry;

  /// Shows the "Done" accessory above the keyboard.
  /// Should be called on focus.
  static void show(BuildContext context) {
    if (kIsWeb) return;
    if (!(Platform.isIOS || Platform.isAndroid)) return;
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => const _DoneButtonAccessory(),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// Removes the "Done" accessory.
  /// Should be called on blur.
  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _DoneButtonAccessory extends StatelessWidget {
  const _DoneButtonAccessory();

  @override
  Widget build(BuildContext context) {
    // Only show if the keyboard is actually visible
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    if (bottomInset == 0.0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Positioned(
      bottom: bottomInset,
      left: 0,
      right: 0,
      child: Material(
        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0),
        elevation: 4.0,
        child: Container(
          height: 44.0,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white12 : Colors.black12,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
