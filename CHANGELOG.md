# Changelog

## 2.2.0

### 🚀 Features

- **Image Blocks**:
  - Pure Flutter image block representation (`ImageNode`, `BlockType.image`) with zero WebView dependency.
  - Multi-source image import via `ImageImportDialog`: remote web URLs, device gallery & camera with built-in permission management (`permission_handler`), and base64 Data URLs.
  - Integrated cropping using `image_cropper` (`SmartImageCropper`) with customizable platform styles.
  - Interactive on-click contextual toolbar offering **✂️ Crop**, **↔️ Align** (Left, Center, Right), **📐 Resize** quick presets (25%, 50%, 75%, 100%), and **🗑️ Remove**.
  - Captions and accessibility `alt` text support with complete HTML serialization (`<img src="..." alt="..." data-caption="..." />`).
  - Drag-and-drop block reordering support through `draggableBlockTypes: {BlockType.image}`.
  - Comprehensive programmatic APIs on `SmartEditorController` (`insertImage`, `updateImage`, `removeImage`, `setImageAlignment`, `setImageSize`, `getImageNode`).

- **Find & Replace**:
  - Floating native search overlay with live match counting (`n of total`) and search options (Match Case, Whole Word, Regular Expressions).
  - Real-time match highlighting across document text and table cells with customizable active & inactive colors.
  - Bidirectional match traversal, single Replace, and Replace All with atomic undo/redo history.
  - Standard keyboard shortcuts (`Cmd/Ctrl+F` to find, `Cmd/Ctrl+H` to replace, `Escape` to close).
  - Granular configuration via `SmartEditorSettings.enableFindReplace` and `SmartOtherButtons(findReplace: true)`.

- **Hyperlinks**:
  - Dedicated dialog for inserting and editing links (`LinkDialog`) with auto-population from current text selection.
  - Contextual link management (open URL, edit link/display text, or unlink) without losing formatting.
  - Full HTML round-trip parsing and serialization of `<a>` tags with `href` and `target` attributes.
  - Atomic undo/redo support for link applications and removals.

## 2.1.0

### 🚀 Features

- **Intelligent List System**: Full support for Bullet and Numbered lists with multiple levels/depths.
- **Atomic Group Reordering**: Move entire list groups as a single unit via drag-and-drop.
- **Smart Deletion (Backspace)**: Multi-stage backspace logic (Out-dent -> Un-list -> Merge) and instant empty-item deletion.
- **Mobile Optimized Backspace**: Custom ZWSP Bridge to support software keyboards on iOS and Android.
- **Semantic Tables**: Insert and manage fully responsive HTML tables with interactive dynamic row and column insertion and deletion.

### ⚙️ Setting Updates

- **`draggableBlockTypes`**: Granular control over which blocks (Headings, Lists, etc.) display drag handles.
- **Improved Keyboard Adaptation**: Dynamic scroll padding to prevent content occlusion by the mobile accessory bar.

### 🛠️ Bug Fixes

- **Visual Alignment**: Unified 32px vertical baseline for all blocks (fixes "jagged" text edges).
- **Index Drift**: Resolved reordering errors in large, complex documents.
- **Focus Stability**: Smoother cursor and focus preservation after block type transitions and indentation changes.

## 2.0.0

- **Font Customization**: Added Font Family and Font Size pickers.
- **Color Support**: Integrated foreground and background (highlight) color pickers.
- **Paragraph Alignment**: Added support for Left, Center, Right, and Justify alignment.
- **Line Height**: Configurable line height per block.
- **Clear Formatting**: One-click tool to reset text style in a selection.
- **Visual Refinements**: Tightened editor layout with `isDense` mode and optimized vertical spacing.
- **Stability**: Added 25+ unit tests covering all Phase 2 extended formatting features.

## 1.0.1

- Initial release
- Core editing: paragraphs, headings (H1-H6)
- Inline formatting: bold, italic, underline, strikethrough
- Undo/redo support
- HTML parsing and serialization
- Native Flutter toolbar
- 6 granular settings classes
- Dark mode support
