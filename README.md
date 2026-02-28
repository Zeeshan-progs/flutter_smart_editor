# Flutter Smart Editor

A highly customizable, pure Dart and Flutter rich text editor.

[![Pub Version](https://img.shields.io/pub/v/flutter_smart_editor)](https://pub.dev/packages/flutter_smart_editor)

`flutter_smart_editor` provides a full-featured WYSIWYG editor designed from scratch for maximum flexibility, control, and cross-platform compatibility. It outputs and parses clean HTML, making it perfect for blogging platforms, note-taking apps, and messaging interfaces.

> **💡 Inspiration:** This package was heavily inspired by the popular [`html_editor_enhanced`](https://pub.dev/packages/html_editor_enhanced) package. However, where `html_editor_enhanced` relies on embedding a webview and bridging JavaScript to Flutter, `flutter_smart_editor` is built **100% in pure Dart and Flutter**. This guarantees native performance, eliminates tedious WebView configuration, avoids cross-platform bridging bugs, and gives developers full, customizable control over every pixel of the UI.

## ✨ Features (Phase 1)

- **Rich Text Formatting**: Bold, Italic, Underline, and Strikethrough.
- **Block Styles**: Paragraphs and Headings (H1–H6).
- **HTML Input/Output**: Seamlessly parse existing HTML into the editor, and export the document back to a clean HTML string.
- **Granular Customization**: 6 independent settings classes to control every aspect of the editor (Editor, Toolbar, Scroll, Keyboard, Selection, Style).
- **Multiple Toolbar Layouts**: Choose between Scrollable, Grid, and Expandable toolbars.
- **Rich Text Copy & Paste**: Paste HTML text from other applications or web browsers directly into the editor while preserving formatting.
- **Undo/Redo History**: Built-in history manager for safe text editing.
- **Dark Mode**: Native support for dark and light themes out of the box.

## 🚀 Getting Started

Add `flutter_smart_editor` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_smart_editor: ^0.1.0
```

## 📖 Usage

### Basic Initialization

Create a `SmartEditorController` and pass it to the `SmartEditor` widget.

```dart
import 'package:flutter_smart_editor/smart_editor.dart';

class MyEditor extends StatefulWidget {
  @override
  State<MyEditor> createState() => _MyEditorState();
}

class _MyEditorState extends State<MyEditor> {
  final SmartEditorController _controller = SmartEditorController();

  @override
  Widget build(BuildContext context) {
    return SmartEditor(
      controller: _controller,
      editorSettings: const SmartEditorSettings(
        hint: 'Start typing here...',
      ),
    );
  }
}
```

### Retrieving HTML Content

To get the HTML output of the editor:

```dart
final htmlString = _controller.getHtml();
print(htmlString);
```

### Advanced Customization

The editor is heavily modularized into 6 core settings classes and a callbacks class, giving you complete control over every behavior and pixel.

#### 1. `SmartEditorSettings`

Controls the core behavior of the editor constraints and HTML parsing.

| Parameter          | Type      | Default | Description                                                                 |
| ------------------ | --------- | ------- | --------------------------------------------------------------------------- |
| `initialText`      | `String?` | `null`  | The starting HTML content in the editor.                                    |
| `hint`             | `String?` | `null`  | Placeholder text when the editor is empty.                                  |
| `disabled`         | `bool`    | `false` | Completely disables the editor and grays it out.                            |
| `readOnly`         | `bool`    | `false` | Disables text input but allows selection/copying.                           |
| `processInputHtml` | `bool`    | `true`  | If true, pasting raw HTML string code will be parsed and formatted cleanly. |
| `darkMode`         | `bool?`   | `null`  | Force light or dark mode. If null, follows system brightness.               |

#### 2. `SmartToolbarSettings`

Customizes the layout, position, and buttons inside the rich text toolbar.

| Parameter            | Type                     | Default             | Description                                                                                               |
| -------------------- | ------------------------ | ------------------- | --------------------------------------------------------------------------------------------------------- |
| `toolbarPosition`    | `SmartToolbarPosition`   | `.above`            | Whether the toolbar appears `.above`, `.below`, or `.custom` (for rendering it anywhere in your app).     |
| `toolbarType`        | `SmartToolbarType`       | `.scrollable`       | The layout of the toolbar. Can be `.scrollable` (horizontally), `.grid` (wrapping box), or `.expandable`. |
| `showBorder`         | `bool`                   | `false`             | Draws a separating border between the toolbar and editor.                                                 |
| `defaultButtons`     | `List<SmartToolbarType>` | `[bold, italic...]` | Define exactly which buttons to show and in what order.                                                   |
| `initiallyExpanded`  | `bool`                   | `false`             | If using `.expandable`, starts the toolbar open.                                                          |
| `buttonIconSize`     | `double`                 | `20.0`              | Size of the toolbar icons.                                                                                |
| `dropdownItemHeight` | `double`                 | `36.0`              | Height of the style dropdown chips.                                                                       |

#### 3. `SmartStyleSettings`

Controls the visual borders, backgrounds, and padding of the overall editor.

| Parameter               | Type             | Default              | Description                                                                |
| ----------------------- | ---------------- | -------------------- | -------------------------------------------------------------------------- |
| `height`                | `double?`        | `null`               | The exact height of the editor. If null, scroll settings determine height. |
| `editorPadding`         | `EdgeInsets`     | `EdgeInsets.all(16)` | Internal padding of the text input area.                                   |
| `editorBackgroundColor` | `Color?`         | `null`               | The background color of the editing area.                                  |
| `decoration`            | `BoxDecoration?` | `null`               | Custom border/shadow/corners.                                              |

#### 4. `SmartScrollSettings`

Manages scrolling behavior and dynamic resizing.

| Parameter          | Type             | Default | Description                                                                       |
| ------------------ | ---------------- | ------- | --------------------------------------------------------------------------------- |
| `scrollPhysics`    | `ScrollPhysics?` | `null`  | Custom physics for the editor's scroll view.                                      |
| `autoAdjustHeight` | `bool`           | `true`  | Allows the editor to grow as the user types until it hits the layout constraints. |

#### 5. `SmartSelectionSettings`

Configures the text cursor and selection highlight colors.

| Parameter        | Type      | Default                          | Description                                    |
| ---------------- | --------- | -------------------------------- | ---------------------------------------------- |
| `cursorColor`    | `Color?`  | `Theme.primary`                  | The blinking vertical cursor color.            |
| `selectionColor` | `Color?`  | `Theme.primary.withOpacity(0.3)` | The background color when text is highlighted. |
| `cursorWidth`    | `double`  | `2.0`                            | Width of the cursor.                           |
| `cursorRadius`   | `Radius?` | `Radius.circular(2)`             | Corner rounding of the cursor.                 |

#### 6. `SmartKeyboardSettings`

Adjusts how the software keyboard interacts with the mobile framework.

| Parameter            | Type               | Default | Description                                |
| -------------------- | ------------------ | ------- | ------------------------------------------ |
| `autofocus`          | `bool`             | `false` | Opens the keyboard immediately on mount.   |
| `textInputAction`    | `TextInputAction?` | `null`  | E.g. `TextInputAction.done` or `.newline`. |
| `keyboardAppearance` | `Brightness?`      | `null`  | Force a dark or light keyboard on iOS.     |

#### 7. `SmartEditorCallbacks`

Subscribe to events happening inside the editor.

| Callback            | Signature                     | Description                                                                         |
| ------------------- | ----------------------------- | ----------------------------------------------------------------------------------- |
| `onChangeContent`   | `(String html)`               | Triggered whenever text or formatting changes. Returns the updated HTML.            |
| `onFocus`           | `()`                          | Triggered when the editor gains focus.                                              |
| `onBlur`            | `()`                          | Triggered when the editor loses focus.                                              |
| `onEnter`           | `()`                          | Triggered when the enter key is pressed.                                            |
| `onChangeSelection` | `(Map<String, bool> formats)` | Triggered when cursor moves. Provides currently active formats (bold, italic, etc). |

## 🛠️ Upcoming Features (Phase 2 & Beyond)

- Font Family & Font Size pickers
- Text and Highlight colors
- Bullet and Numbered Lists
- Paragraph Alignment & Indentation
- Hyperlinks and Media embedding
- Tables
- And much more!


## 📄 License

This package is licensed under the MIT License.

## 🤝 Contributing

We welcome contributions! `flutter_smart_editor` is actively seeking the community's help to reach Phase 2 and beyond.

If you find a bug, have a feature request, or want to contribute code:

1. **Open an Issue**: Please search existing issues first. If your issue is new, open a detailed issue report.
2. **Submit a Pull Request**:
   - Fork the repository.
   - Create a feature branch (`git checkout -b feature/amazing-feature`).
   - Write clear, passing unit tests for your changes.
   - Run `dart format` and `flutter test` before submitting.
   - Create a Pull Request against the `main` branch.

All contributions, from bug fixes to complete feature implementations (like Tables or Media embeddings) are highly appreciated!
