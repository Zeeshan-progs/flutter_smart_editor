/// A pure Flutter rich text HTML editor.
///
/// No WebView, no JavaScript — built entirely with Dart and Flutter.
library flutter_smart_editor;

// Top-level widgets
export 'smart_editor.dart';
export 'smart_editor_controller.dart';
export 'src/models/toolbar/toolbar_index.dart';

// Settings (Simplified into 2 classes)
export 'src/models/editor_settings.dart';
export 'src/models/toolbar_settings.dart';

// Document model & Nodes
export 'src/core/document/document.dart';
export 'src/models/nodes/node_index.dart';

// enums
export 'src/models/enums.dart';
