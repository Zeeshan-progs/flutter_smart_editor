/// A pure Flutter rich text HTML editor.
///
/// No WebView, no JavaScript — built entirely with Dart and Flutter.
library flutter_smart_editor;

// Top-level widgets
export 'smart_editor.dart';
export 'smart_editor_controller.dart';

// Settings (6 granular settings classes)
export 'src/models/editor_settings.dart';
export 'src/models/toolbar_settings.dart';
export 'src/models/scroll_settings.dart';
export 'src/models/keyboard_settings.dart';
export 'src/models/selection_settings.dart';
export 'src/models/style_settings.dart';

// Callbacks
export 'src/models/callbacks.dart';

// Toolbar button groups
export 'src/models/toolbar_buttons.dart';

// Enums
export 'src/models/enums.dart';

// Document model (for advanced usage)
export 'src/core/document.dart';
