import 'toolbar_group.dart';

/// Miscellaneous buttons (Undo, Redo, Code view, Fullscreen, etc.)
class SmartOtherButtons extends SmartToolbarGroup {
  final bool undo;
  final bool redo;
  final bool copy;
  final bool paste;

  const SmartOtherButtons({
    this.undo = true,
    this.redo = true,
    this.copy = true,
    this.paste = true,
  });
}
