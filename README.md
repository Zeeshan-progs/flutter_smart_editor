# Flutter Smart Editor

A highly customizable, **pure Dart and Flutter** rich text HTML editor. No WebViews, no JavaScript—built entirely for native performance and full control.

[![Pub Version](https://img.shields.io/pub/v/flutter_smart_editor)](https://pub.dev/packages/flutter_smart_editor)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

`flutter_smart_editor` is a full-featured WYSIWYG editor designed from scratch to eliminate the overhead and bugs associated with WebView-based editors. It provides a premium, Material 3 experience with clean HTML input/output.

## 📌 Table of Contents

- [✨ Features](#-features)
- [🚀 Getting Started](#-getting-started)
- [📖 Basic Usage](#-basic-usage)
- [⚙️ Detailed Configuration](#️-detailed-configuration)
  - [1. SmartEditorSettings](#1-smarteditorsettings)
    - [Core & HTML](#core--html)
    - [Scroll & Layout](#scroll--layout)
    - [Keyboard](#keyboard)
    - [Selection & Cursor](#selection--cursor)
    - [Style & Decoration](#style--decoration)
    - [Lists & Horizontal Rules](#lists--horizontal-rules)
    - [Callbacks](#callbacks)
  - [2. SmartToolbarSettings](#2-smarttoolbarsettings)
    - [Layout & Position](#layout--position)
    - [Content](#content)
    - [Container Styling](#container-styling)
    - [Button & Text Styling](#button--text-styling)
    - [Dropdown Styling](#dropdown-styling)
    - [Interceptors](#interceptors)
  - [3. Interactive List Customization](#3-interactive-list-customization)
    - [Enabling the Bullet Picker](#enabling-the-bullet-picker)
    - [Customizing Available Styles](#customizing-available-styles)
    - [Custom Serialization Example](#custom-serialization-example)
  - [4. Programmatic APIs (Tables, Lists, Hyperlinks, Search & Images)](#4-programmatic-apis-tables-lists-hyperlinks-search--images)
    - [📊 Table Management APIs](#-table-management-apis)
    - [🔢 List & Numbered List APIs](#-list--numbered-list-apis)
    - [🔗 Hyperlink Management APIs](#-hyperlink-management-apis)
    - [🔍 Find & Replace APIs](#-find--replace-apis)
    - [🖼️ Image Block APIs](#️-image-block-apis)
- [🎛️ Toolbar Customization](#️-toolbar-customization)
- [🏃 Migration Guide](#-migration-guide-v10x--v200)
- [🛠️ Upcoming Features](#️-upcoming-features)
- [❓ Troubleshooting](#-troubleshooting)
- [📄 License](#-license)

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
- **Lists (v2.1+)**: Robust, atomic Bullet and Numbered lists with smart reordering.
- **Tables (v2.1+)**: Full support for HTML tables with dynamic row/column management (insertion, deletion, and cell updates).
- **Hyperlinks (v2.2+)**: Native link insertion, editing, and removal dialogs, URL normalization, display text replacement, and custom tap listeners.
- **Find & Replace (v2.2+)**: Floating search overlay with real-time match highlighting, regex, whole word, match case, hyperlink preservation, and atomic single-step undo.
- **Image Blocks (v2.2+)**: Full image support with URL import, device Camera/Gallery picking (via `image_picker`), interactive cropping (via `image_cropper`), in-editor resizing, alignment (left/center/right), captions, alt text, and contextual action toolbar (Crop, Remove, Align, Resize).
- **Mobile Optimized**: Smart backspace bridge for soft keyboards and accessory bar avoidance.
- **Undo/Redo**: Built-in history management.
- **Material 3 Toolbar**: **Scrollable**, **Grid**, or **Expandable** layouts.

---

## 🚀 Getting Started

Add `flutter_smart_editor` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_smart_editor: ^2.2.0
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
| `searchMatchColor` | `Color?` | `null` | Custom background highlight color for inactive search matches. |
| `searchActiveMatchColor` | `Color?` | `null` | Custom background highlight color for the active search match. |

#### Lists & Horizontal Rules

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `maxListDepth` | `int` | `3` | Maximum nesting depth for lists (1-5 recommended). |
| `defaultBulletStyle` | `SmartBulletStyle` | `.filledCircle` | Default bullet shape for unordered lists. |
| `hrStyle` | `SmartHrStyle` | `(defaults)` | Visual configuration for Horizontal Rule dividers. |
| `draggableBlockTypes` | `Set<BlockType>` | `null` | Types of blocks that show reordering handles (e.g. `{BlockType.bulletList}`). |

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
| `onLinkTapped` | `(String url)` | Triggered when a hyperlink is tapped in the editor. |
| `onKeyUp` / `onKeyDown` | `(String? key)` | Raw key event callbacks. |

### 🛠️ Interactive List Customization

Version 2.1.0 introduces the ability for users to live-change their bullet point symbols (pointers).

#### Enabling the Bullet Picker

To show the bullet style picker in your toolbar, ensure `listStyles` is enabled in your `SmartListButtons` group:

```dart
SmartToolbarSettings(
  defaultButtons: [
    const SmartListButtons(
      ul: true,
      ol: true,
      listStyles: true, // Enables the style picker button
    ),
  ],
)
```

#### Customizing Available Styles

You can filter which pointers are available to the user:

```dart
SmartListButtons(
  listStyles: true,
  availableStyles: [
    SmartBulletStyle.filledCircle,
    SmartBulletStyle.diamond,
    SmartBulletStyle.star,
  ],
)
```

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

### 4. Programmatic APIs (Tables, Lists, Hyperlinks, Search & Images)

`SmartEditorController` provides a rich set of programmatic APIs to manipulate tables, lists, hyperlinks, and document search dynamically from your parent widgets, custom toolbar buttons, or keyboard listeners.

#### 📊 Table Management APIs

When the user is interacting with tables, you can use these controller methods to perform programmatic modifications:

| Method / Getter | Return Type | Description |
| :--- | :--- | :--- |
| `insertTable({int rows, int cols})` | `void` | Inserts a new responsive HTML table grid with specified dimensions after the active block. |
| `insertRow()` | `void` | Inserts a new table row below the currently focused table cell. |
| `insertColumn()` | `void` | Inserts a new table column to the right of the currently focused table cell. |
| `deleteRow()` | `void` | Deletes the row containing the currently focused table cell. |
| `deleteColumn()` | `void` | Deletes the column containing the currently focused table cell. |
| `deleteTable()` | `void` | Deletes the entire focused table block. |
| `isInsideTable` | `bool` | Returns `true` if the caret/cursor is currently inside a table cell. |
| `focusedTableInfo` | `({int blockIndex, int row, int col})?` | Returns the exact coordinate position of the focused cell, or `null`. |

##### Code Example: Context-Aware Table Modification

```dart
final controller = SmartEditorController();

// 1. Insert a 3x3 table programmatically
controller.insertTable(rows: 3, cols: 3);

// 2. perform context-aware row addition
if (controller.isInsideTable) {
  print("Focused cell coordinates: ${controller.focusedTableInfo}");
  
  // Add a new row below the focused cell
  controller.insertRow();
}
```

#### 🔢 List & Numbered List APIs

To toggle lists and adjust indentation programmatically:

| Method / Getter | Arguments | Description |
| :--- | :--- | :--- |
| `setBlockType(BlockType type)` | `BlockType.bulletList` | Converts the active block to an Unordered Bullet List (`<ul>`). |
| `setBlockType(BlockType type)` | `BlockType.orderedList` | Converts the active block to an Ordered Numbered List (`<ol>`). |
| `setBlockType(BlockType type)` | `BlockType.paragraph` | Converts a list item back to standard paragraph text (`<p>`). |
| `documentController.increaseIndent(int blockIndex)` | `blockIndex` | Increases list nesting depth/indentation (supports up to 3 levels). |
| `documentController.decreaseIndent(int blockIndex)` | `blockIndex` | Decreases list nesting depth/outdents the list block. |

##### Code Example: Programmatic List Customization

```dart
final controller = SmartEditorController();

// Convert current block to a Bullet List
controller.setBlockType(BlockType.bulletList);

// Convert current block to a Numbered List
controller.setBlockType(BlockType.orderedList);

// Increase Indentation on the active block index
final activeIndex = controller.documentController.focusedBlockIndex;
controller.documentController.increaseIndent(activeIndex);
```

#### 🔗 Hyperlink Management APIs

`flutter_smart_editor` provides native, full-lifecycle hyperlink management across both regular paragraphs and table cells. It supports interactive dialogs, automatic protocol normalization (`http://` prefixing), display text replacements, link inspection, and removal.

| Method / Getter | Return Type | Description |
| :--- | :--- | :--- |
| `insertLink(String url, String displayText, {int? blockIndex, TextSelection? selection})` | `void` | Inserts a new link span at the cursor, applies a link to the selected text range, or updates the display text and URL atomically. |
| `removeLink({int? blockIndex, TextSelection? selection})` | `void` | Strips the hyperlink from the active selection or focused link span while preserving the text. |
| `getLinkInfo({int? blockIndex, TextSelection? selection})` | `Map<String, String?>` | Returns `{'text': ..., 'url': ...}` for the focused caret position or selected text. Works seamlessly inside both paragraphs and table cells. |
| `documentController.applyLink(int blockIndex, int start, int end, String? url)` | `void` | Low-level document method applying or clearing a URL over a character range. |
| `documentController.setLink({...})` | `int` | Atomically applies or replaces a link in a block, appends a trailing unlinked space if needed, and returns the target cursor offset. |
| `documentController.setCellLink({...})` | `int` | Cell-level equivalent of `setLink` for table cells. |
| `editorSettings.onLinkTapped` | `void Function(String url)?` | Callback invoked when a user clicks or taps a hyperlink in the editor. |

##### Code Example: Programmatic Link Insertion & Tap Handling

```dart
final controller = SmartEditorController();

// 1. Insert a link at the current cursor position
controller.insertLink(
  'https://flutter.dev',
  'Flutter Official Website',
);

// 2. Query existing link information at the cursor
final linkInfo = controller.getLinkInfo();
print('Active link: ${linkInfo['text']} -> ${linkInfo['url']}');

// 3. Remove a hyperlink from the selected text
controller.removeLink();

// 4. Handle link taps in the editor widget
SmartEditor(
  controller: controller,
  editorSettings: SmartEditorSettings(
    onLinkTapped: (url) {
      print('User clicked link: $url');
      // Launch URL with url_launcher, open in-app webview, etc.
    },
  ),
);
```

#### 🔍 Find & Replace APIs

Version 2.2.0 introduces a native floating Find & Replace search overlay anchored right over the editor. It supports live match counts, cycling navigation, regex queries, case sensitivity, whole-word matching, hyperlink preservation, and atomic single-step undo.

| Method / Getter | Return Type | Description |
| :--- | :--- | :--- |
| `showFindReplace({bool showReplace = false})` | `void` | Displays the floating search bar. Pass `showReplace: true` to open with the Replace row expanded. |
| `hideFindReplace()` | `void` | Closes the search overlay, clears match highlights, and restores editor focus. |
| `setSearchQuery(String query)` | `void` | Sets the search query and searches the document live across all blocks and table cells. |
| `setReplaceText(String text)` | `void` | Sets the replacement string used by `replaceCurrent` and `replaceAll`. |
| `setSearchOptions(SearchOptions options)` | `void` | Updates options (`matchCase`, `wholeWord`, `isRegex`, `preserveLinkOnReplace`) and recalculates matches. |
| `setReplaceExpanded(bool expanded)` | `void` | Expands or collapses the Replace input row in the floating panel. |
| `findNext()` | `void` | Cycles and smoothly navigates to the next match in the document. |
| `findPrevious()` | `void` | Cycles and smoothly navigates to the previous match in the document. |
| `replaceCurrent()` | `void` | Replaces the currently focused match with the replacement text. |
| `replaceAll()` | `int` | Replaces all occurrences across all blocks and table cells in a single atomic undo step. Returns total count replaced. |
| `searchState` | `SearchState` | Current search state snapshot (`query`, `replaceText`, `matches`, `currentMatchIndex`, `isBarVisible`, `totalMatches`, etc.). |
| `searchStateNotifier` | `ValueNotifier<SearchState>` | Reactive notifier for listening to search overlay and match state changes. |

##### Search Options Configuration (`SearchOptions`)

| Option | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `matchCase` | `bool` | `false` | When `true`, matches are strictly case-sensitive. |
| `wholeWord` | `bool` | `false` | When `true`, matches only complete standalone words (`\bquery\b`). |
| `isRegex` | `bool` | `false` | When `true`, parses the query string as a standard Regular Expression. |
| `preserveLinkOnReplace` | `bool` | `true` | When `true`, replacing text inside a hyperlink updates the display text while keeping the hyperlink URL intact. |

##### Code Example: Programmatic Search & Batch Replacement

```dart
final controller = SmartEditorController();

// 1. Open the search overlay programmatically
controller.showFindReplace(showReplace: true);

// 2. Perform a live regex search
controller.setSearchOptions(const SearchOptions(
  matchCase: true,
  isRegex: true,
));
controller.setSearchQuery(r'\bFlutter\b');

// 3. Navigate through matches
controller.findNext();
print("Found ${controller.searchState.totalMatches} matches");
print("Current match index: ${controller.searchState.currentMatchIndex}");

// 4. Batch replace occurrences in a single undo step
controller.setReplaceText('Dart & Flutter');
final replacedCount = controller.replaceAll();
print("Replaced $replacedCount occurrences atomically!");

// 5. Customize search highlight colors in editor settings
SmartEditor(
  controller: controller,
  editorSettings: const SmartEditorSettings(
    searchMatchColor: Color(0x66FFEB3B),       // Highlight for all matches
    searchActiveMatchColor: Color(0xCCFF9800), // Highlight for focused match
  ),
);
```

#### 🖼️ Image Block APIs

Version 2.2.0 introduces native image blocks with full lifecycle management: URL import, device Camera/Gallery picking (with runtime permissions), interactive cropping, resizing, alignment, captions, alt text, and a contextual action toolbar.

##### Image Node Model (`ImageNode`)

| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `src` | `String` | *(required)* | Image source: network URL (`https://...`), local file path, or base64 Data URL (`data:image/png;base64,...`). |
| `alt` | `String?` | `null` | Accessibility text (HTML `alt` attribute). |
| `width` | `double?` | `null` | Display width in logical pixels. `null` = intrinsic width. |
| `height` | `double?` | `null` | Display height in logical pixels. `null` = intrinsic height. |
| `caption` | `String?` | `null` | Optional caption text displayed below the image. |
| `alignment` | `SmartTextAlign` | `.center` | Horizontal alignment: `.left`, `.center`, or `.right`. |

##### Controller APIs (`SmartEditorController`)

| Method / Getter | Return Type | Description |
| :--- | :--- | :--- |
| `insertImage({required String src, String? alt, double? width, double? height, String? caption, SmartTextAlign alignment, int? blockIndex})` | `int` | Inserts a new image block at or after the given `blockIndex` (or the focused block). Returns the index of the inserted `ImageNode`. Automatically appends an empty paragraph after the image if it is at the end of the document. |
| `updateImage(int blockIndex, {String? src, String? alt, double? width, double? height, String? caption, SmartTextAlign? alignment})` | `void` | Updates any combination of properties on an existing `ImageNode` at `blockIndex`. |
| `setImageAlignment(int blockIndex, SmartTextAlign alignment)` | `void` | Convenience method to change only the alignment of an image block. |
| `setImageSize(int blockIndex, {double? width, double? height})` | `void` | Convenience method to resize an image block. |
| `removeImage(int blockIndex)` | `void` | Deletes the image block at `blockIndex`. Ensures the document always retains at least one empty paragraph. |
| `getImageNode(int blockIndex)` | `ImageNode?` | Returns the `ImageNode` at `blockIndex`, or `null` if the block is not an image. |
| `imagePickerDelegate` | `Future<String?> Function()?` | Optional delegate for custom device image picking. When set, the import dialog calls this instead of the built-in Camera/Gallery picker. Should return a base64 Data URL, file path, or network URL (or `null` if cancelled). |

##### Document Controller APIs (`DocumentController`)

For lower-level control, these methods are available directly on `controller.documentController`:

| Method | Return Type | Description |
| :--- | :--- | :--- |
| `insertImage({required String src, ...})` | `int` | Inserts an `ImageNode` into the document block list. |
| `updateImage(int blockIndex, {...})` | `void` | Mutates properties on an existing `ImageNode` in place. |
| `setImageAlignment(int blockIndex, SmartTextAlign)` | `void` | Sets alignment on the image block. |
| `setImageSize(int blockIndex, {double? width, double? height})` | `void` | Sets width/height on the image block. |
| `removeImage(int blockIndex)` | `void` | Removes the image block from the document. |
| `getImageNode(int blockIndex)` | `ImageNode?` | Returns the `ImageNode` or `null`. |

##### Toolbar Configuration

Enable the image button in the toolbar via `SmartInsertButtons`:

```dart
SmartToolbarSettings(
  defaultButtons: [
    // ... other button groups ...
    const SmartInsertButtons(
      link: true,
      picture: true,   // Enables the Image import button
      table: true,
    ),
  ],
)
```

When the user clicks the image button, the `ImageImportDialog` opens with two tabs:

| Tab | Feature | Details |
| :--- | :--- | :--- |
| **URL** | Web URL import | Paste a network URL, see a live preview, add optional caption and alt text. |
| **Device** | Camera / Gallery | Pick from Camera or Gallery with runtime permission handling (`permission_handler`). Captured image is converted to a base64 Data URL. |

Both tabs offer two actions:
- **Insert** — inserts the image directly into the editor.
- **Crop & Insert** — opens the native `image_cropper` (iOS: `TOCropViewController`, Android: `UCropActivity`) before insertion.

##### Interactive Image Block Widget

When an image block is tapped (selected), a contextual floating action toolbar appears with:

| Action | Icon | Description |
| :--- | :--- | :--- |
| **Crop** | ✂️ | Opens the native `image_cropper` to crop/adjust the existing image. |
| **Align Left / Center / Right** | ◀️ ⬛ ▶️ | Changes horizontal alignment of the image block. |
| **Resize** | 📐 | Width/height input fields to resize the image. |
| **Remove** | 🗑️ | Deletes the image block from the document. |

##### Cropper Utility (`SmartImageCropper`)

The built-in cropper wraps the official [`image_cropper`](https://pub.dev/packages/image_cropper) package:

| Method | Return Type | Description |
| :--- | :--- | :--- |
| `SmartImageCropper.crop({required BuildContext context, required String imageSrc, bool isDarkMode})` | `Future<String?>` | Crops an image using the native platform cropper. Accepts base64 Data URLs, network URLs, or local file paths. Returns the cropped image as a base64 Data URL, or `null` if the user cancelled. |
| `SmartImageCropper.show(context, {required String imageSrc, bool isDarkMode})` | `Future<String?>` | Convenience alias for `crop()`. |

##### Platform Dependencies

The image feature requires these packages in your app's `pubspec.yaml`:

```yaml
dependencies:
  flutter_smart_editor: ^2.2.0
  # These are transitive dependencies of flutter_smart_editor,
  # but you may need platform-specific setup:
  # - image_picker: Camera/Gallery access
  # - image_cropper: Native cropping UI
  # - permission_handler: Runtime permission requests
```

**iOS** — add to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is needed to take photos for the editor.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access is needed to pick images for the editor.</string>
```

**Android** — add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
```

##### Code Example: Programmatic Image Management

```dart
final controller = SmartEditorController();

// 1. Insert an image from a URL
controller.insertImage(
  src: 'https://example.com/photo-1579783900882-c0d3dad7b119?w=600',
  alt: 'Sample Artwork',
  caption: 'A beautiful photo from Unsplash',
);

// 2. Insert an image with custom dimensions and alignment
controller.insertImage(
  src: 'data:image/png;base64,iVBORw0KGgo...',
  alt: 'Logo',
  width: 200,
  height: 100,
  alignment: SmartTextAlign.left,
  blockIndex: 0, // Insert at the top of the document
);

// 3. Update an existing image block
controller.updateImage(
  2, // block index
  caption: 'Updated caption',
  alignment: SmartTextAlign.right,
);

// 4. Resize an image
controller.setImageSize(2, width: 400, height: 300);

// 5. Query an image block
final node = controller.getImageNode(2);
if (node != null) {
  print('Image src: ${node.src}');
  print('Caption: ${node.caption}');
  print('Alignment: ${node.alignment}');
}

// 6. Remove an image block
controller.removeImage(2);

// 7. Custom image picker delegate
controller.imagePickerDelegate = () async {
  // Your custom image picking logic
  // Return a base64 Data URL, file path, or network URL
  return 'data:image/png;base64,iVBORw0KGgo...';
};
```

---

## 🎛️ Toolbar Customization

The toolbar is built using modular button groups. You can fully customize which groups appear and which specific buttons within those groups are active.

### Full Toolbar Example

Here is how you would configure a toolbar with **every available group** active:

```dart
SmartToolbarSettings(
  toolbarType: SmartToolbarType.expandable,
  defaultButtons: [
    const SmartStyleButtons(),      // Heading 1-6 & Paragraph
    const SmartFontButtons(
      strikethrough: true,
      fontSize: true,
      clearAll: true,
    ),
    const SmartColorButtons(
      foregroundColor: true,
      highlightColor: true,
    ),
    const SmartListButtons(
      ul: true,
      ol: true,
      hr: true,
      listStyles: true,             // Enables interactive bullet picker
    ),
    const SmartFontFamilyButtons(),
    const SmartParagraphButtons(),    // Alignment: Left, Center, Right, Justify
    const SmartOtherButtons(
      undo: true,
      redo: true,
      copy: true,
      paste: true,
    ),
  ],
)
```

### Breakdown of Button Groups

| Group Class | Description |
| --- | --- |
| `SmartStyleButtons` | Controls the paragraph style dropdown (Heading 1 to Heading 6 and Normal text). |
| `SmartFontButtons` | Standard formatting: Bold, Italic, Underline, Strikethrough, Font Size, and Clear Formatting. |
| `SmartColorButtons` | Integrated color pickers for text color and background highlight color. |
| `SmartFontFamilyButtons` | A dropdown for selecting from your application's available font families. |
| `SmartListButtons` | Bullet/Numbered list toggles, horizontal dividers (HR), and the premium Bullet Style Picker. |
| `SmartParagraphButtons` | Text alignment controls: Left, Center, Right, and Full Justify. |
| `SmartInsertButtons` | Insert elements: Hyperlinks (`link: true`), Images, and HTML Tables. |
| `SmartOtherButtons` | Utility actions: Undo, Redo, Copy to Clipboard, Paste, and Find & Replace (`findReplace: true`). |

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

## 🏃 Migration Guide (v1.0.x ➔ v2.x.x)

Version 2.x.x introduces a **Unified Settings API**. Instead of separate `ScrollSettings`, `KeyboardSettings`, etc., all editor-related properties are now in `SmartEditorSettings`.

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

- [ ] **Markdown Shortcuts**: Auto-format headers and lists during typing.
- [x] **Find & Replace**: Native search overlay with match highlighting.
- [x] **Image Blocks**: Support for network/local/camera images with cropping, resizing, and alignment.
- [ ] **Code Blocks**: Syntax highlighting for 100+ languages.
- [x] **Hyperlinks**: Comprehensive link insertion and management dialogs.
- [ ] **Focus Mode**: Zen mode for distraction-free writing.
- [ ] **Live Statistics**: Real-time word, character, and reading time counters.
- [ ] **Auto-Save**: Background persistence and draft recovery.
- [ ] **AI Assistant**: context-aware writing improvements and summaries.
- [ ] **PDF Export**: Generate high-quality PDFs directly from Dart.
- [ ] **Real-time Sync**: Collaborative editing via WebSocket/CRDT.
- [ ] **Slash Commands**: Notion-style `/` menu for quick block insertion.
- [ ] **Mobile Haptics**: Tactile feedback for editing actions.

## ❓ Troubleshooting

### Failed to load 'libsuper_native_extensions.so'

If you encounter errors when using the **Paste** feature:

1. `flutter clean`
2. `flutter pub get`
3. Perform a **cold start** (full rebuild) of the app. This is required to bundle the native clipboard libraries.

## 📄 License

This project is licensed under the MIT License.
