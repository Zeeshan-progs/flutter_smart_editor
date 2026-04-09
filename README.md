# Flutter Smart Editor

A highly customizable, **pure Dart and Flutter** rich text HTML editor. No WebViews, no JavaScript—built entirely for native performance and full control.

[![Pub Version](https://img.shields.io/pub/v/flutter_smart_editor)](https://pub.dev/packages/flutter_smart_editor)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

`flutter_smart_editor` is a full-featured WYSIWYG editor designed from scratch to eliminate the overhead and bugs associated with WebView-based editors. It provides a premium, Material 3 experience with clean HTML input/output.

## ✨ Features

### 🎨 Formatting & Styling

- **Inline Styles**: Bold, Italic, Underline, and Strikethrough.
- **Dynamic Fonts**: Custom Font Family and Font Size selection.
- **Rich Colors**: Foreground (text) and Highlight (background) color pickers.
- **Block Types**: Paragraphs and Headings (H1–H6).
- **Alignment**: Left, Center, Right, and Justify.

### 🧩 Core Editor Capabilities

- **Pure HTML**: Clean output and robust parsing of existing HTML content.
- **Dynamic Height**: The editor expands as you type and can be limited via `maxLines`.
- **Native Paste**: Premium clipboard support—paste rich text/HTML from browsers and other apps.
- **Undo/Redo**: Built-in history management.
- **Material 3 Toolbar**: **Scrollable**, **Grid**, or **Expandable** layouts.

---

## 🚀 Getting Started

Add `flutter_smart_editor` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_smart_editor: ^2.0.0
```

## 📖 Basic Usage

```dart
import 'package:flutter_smart_editor/flutter_smart_editor.dart';

// ... inside your widget ...
SmartEditor(
  controller: _controller,
  editorSettings: const SmartEditorSettings(
    hint: 'Start typing...',
    initialText: '<p>Hello <b>World</b></p>',
  ),
  toolbarSettings: const SmartToolbarSettings(
    toolbarType: SmartToolbarType.scrollable,
  ),
)
```

---

## ⚙️ Detailed Configuration

### 1. `SmartEditorSettings`

#### Core & HTML

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `initialText` | `String?` | `null` | The starting HTML content in the editor. |
| `hint` | `String?` | `null` | Placeholder text shown when the editor is empty. |
| `defaultFontSize` | `double` | `16.0` | The base font size for paragraph text. |
| `darkMode` | `bool?` | `null` | Force light or dark mode. If null, follows system brightness. |
| `disabled` | `bool` | `false` | Completely disables interaction and grays out the editor. |
| `readOnly` | `bool` | `false` | Disables text input but allows selection and copying. |
| `maxLines` | `int?` | `null` | Max height in lines before scrolling. `null` = grows indefinitely. |
| `characterLimit` | `int?` | `null` | Max number of characters allowed in the editor. |
| `spellCheck` | `bool` | `false` | Enables browser/OS native spell checking. |
| `processInputHtml` | `bool` | `true` | Sanitizes and prepares input HTML string. |
| `processOutputHtml` | `bool` | `true` | Cleans up empty tags in the produced HTML output. |
| `processNewLineAsBr` | `bool` | `false` | Converts `\n` to `<br>` in input strings. |

#### Scroll & Layout

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `autoAdjustHeight` | `bool` | `true` | Allows the editor to grow vertically as the user types. |
| `ensureVisible` | `bool` | `false` | Scrolls the editor into view when it gains focus. |
| `scrollPhysics` | `ScrollPhysics?` | `null` | Custom physics for the editor's scroll view. |

#### Keyboard

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `inputType` | `SmartInputType` | `.text` | The type of virtual keyboard to display. |
| `autofocus` | `bool` | `false` | Opens the keyboard immediately on mount. |
| `textInputAction` | `TextInputAction?` | `null` | The action button on the keyboard (e.g. Done, Search). |
| `keyboardAppearance` | `Brightness?` | `null` | Force a dark or light keyboard on iOS. |
| `adjustForKeyboard` | `bool` | `true` | Automatically shrinks the editor when the keyboard appears. |

#### Selection & Cursor

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `cursorColor` | `Color?` | `Theme` | The color of the blinking vertical text cursor. |
| `cursorWidth` | `double` | `2.0` | Width of the cursor in logical pixels. |
| `cursorRadius` | `Radius?` | `Circular(2)` | Corner rounding of the cursor tip. |
| `cursorHeight` | `double?` | `null` | Fixed height for the cursor. |
| `showCursor` | `bool` | `true` | Whether to show the blinking cursor at all. |
| `selectionColor` | `Color?` | `Theme` | Background color for highlighted text. |
| `selectionHandleColor` | `Color?` | `Theme` | Color of the drag handles on mobile. |
| `enableInteractiveSelection` | `bool` | `true` | Allows users to select text via tap/hold. |

#### Style & Decoration

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `decoration` | `BoxDecoration?` | `null` | Decoration around the **entire editor container**. |
| `editorDecoration` | `BoxDecoration?` | `null` | Decoration around **just the text input area**. |
| `editorPadding` | `EdgeInsets` | `all(12)` | Internal padding of the text input area. |
| `editorBackgroundColor` | `Color?` | `null` | Background color of the editing area. |
| `borderRadius` | `BorderRadius?` | `null` | Rounded corners for the default editor border. |

#### Callbacks

| Callback | Signature | Description |
| --- | --- | --- |
| `onChangeContent` | `(String? html)` | Triggered whenever text or formatting changes. |
| `onFocus` | `()` | Triggered when the editor gains focus. |
| `onBlur` | `()` | Triggered when the editor loses focus. |
| `onInit` | `()` | Triggered when the editor is fully initialized. |
| `onEnter` | `()` | Triggered when the Enter/Return key is pressed. |
| `onChangeSelection` | `(Map<String, dynamic>)` | Triggered when cursor moves; provides active formatting state. |
| `onPaste` | `()` | Triggered when content is pasted into the editor. |
| `onTagSerialize` | `(Type, Tag, Attr, Styles, Content)` | Custom tag serialization interceptor (see below). |
| `onKeyUp` / `onKeyDown` | `(String? key)` | Raw key event callbacks. |

#### Custom Serialization Example

You can intercept any HTML tag before it is written to the output. The `styles` map allows you to precisely modify inline CSS properties without string parsing.

```dart
SmartEditorSettings(
  onTagSerialize: (type, tag, attributes, styles, content) {
    if (type == SmartTagType.bold) {
      // Add custom inline style to bold tags
      styles['color'] = 'royal-blue';
      return null; // Return null to let the editor build the final HTML using modified styles
    }
    
    if (type == SmartTagType.heading1) {
      // Completely replace h1 with a styled div
      return '<div class="h1-alternate" style="text-shadow: 1px 1px #eee;">$content</div>';
    }
    
    return null;
  },
)
```

---

### 2. `SmartToolbarSettings`

#### Layout & Position

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `toolbarType` | `SmartToolbarType` | `.scrollable` | Layout: `.scrollable`, `.grid`, or `.expandable`. |
| `toolbarPosition` | `SmartToolbarPosition` | `.above` | Position relative to editor: `.above` or `.below`. |
| `initiallyExpanded` | `bool` | `false` | Starts the expandable toolbar in the open state. |
| `showBorder` | `bool` | `false` | Separation border between editor and toolbar. |
| `showSeparators` | `bool` | `true` | Vertical lines between button groups. |
| `itemHeight` | `double` | `36` | Height of individual buttons and chips. |
| `gridSpacingH` | `double` | `5` | Horizontal gap between buttons in grid layout. |
| `gridSpacingV` | `double` | `5` | Vertical gap between buttons in grid layout. |
| `separatorWidget` | `Widget?` | `null` | Custom widget to use as a separator. |

#### Content

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `defaultButtons` | `List<SmartToolbarGroup>` | `[...]` | List of button groups to display. |
| `customButtons` | `List<Widget>` | `[]` | Custom widgets to insert into the toolbar. |
| `customButtonInsertionIndices` | `List<int>` | `[]` | Position indices for custom buttons. |

#### Container Styling

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `decoration` | `BoxDecoration?` | `null` | Styling for the toolbar background/border. |
| `padding` | `EdgeInsets?` | `null` | Internal padding of the toolbar container. |

#### Button & Text Styling

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `buttonColor` | `Color?` | `null` | Base color for toolbar icons. |
| `buttonSelectedColor` | `Color?` | `null` | Icon color when a style is active. |
| `buttonFillColor` | `Color?` | `null` | Background color of the button. |
| `buttonBorderRadius` | `BorderRadius?` | `null` | Corner rounding for buttons. |
| `buttonIconSize` | `double` | `20.0` | Size of the toolbar icons. |
| `textStyle` | `TextStyle?` | `null` | Style for text labels in the toolbar. |

#### Dropdown Styling

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `dropdownBackgroundColor` | `Color?` | `null` | Background color of popup menus. |
| `dropdownElevation` | `int` | `8` | Shadow depth for popup menus. |
| `dropdownItemHeight` | `double?` | `null` | Height of items inside dropdowns. |
| `dropdownIconSize` | `double` | `24` | Size of the dropdown arrow icon. |

#### Interceptors

| Callback | Signature | Description |
| --- | --- | --- |
| `onButtonPressed` | `(Type, bool, Fn)` | Intercept any button click to add custom logic. |
| `onDropdownChanged` | `(Type, val, Fn)` | Intercept any dropdown selection change. |

---

## 🏃 Migration Guide (v1.0.x ➔ v2.0.0)

Version 2.0.0 introduces a **Unified Settings API**. Instead of separate `ScrollSettings`, `KeyboardSettings`, etc., all editor-related properties are now in `SmartEditorSettings`.

**Old:**

```dart
SmartEditor(
  scrollSettings: SmartScrollSettings(autoAdjustHeight: true),
  styleSettings: SmartStyleSettings(editorPadding: EdgeInsets.all(16)),
)
```

**New:**

```dart
SmartEditor(
  editorSettings: SmartEditorSettings(
    autoAdjustHeight: true,
    editorPadding: EdgeInsets.all(16),
  ),
)
```

## 🛠️ Upcoming Features

- [ ] Table Support
- [ ] Hyperlinks & Media Embeds
- [ ] Bullet & Numbered Lists
- [ ] Code Block Syntax Highlighting

## ❓ Troubleshooting

### Failed to load 'libsuper_native_extensions.so'

If you encounter errors when using the **Paste** feature:

1. `flutter clean`
2. `flutter pub get`
3. Perform a **cold start** (full rebuild) of the app. This is required to bundle the native clipboard libraries.

## 📄 License

This project is licensed under the MIT License.
