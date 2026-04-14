# Changelog

## 2.1.0

### 🚀 Features

- **Intelligent List System**: Full support for Bullet and Numbered lists with multiple levels/depths.
- **Atomic Group Reordering**: Move entire list groups as a single unit via drag-and-drop.
- **Smart Deletion (Backspace)**: Multi-stage backspace logic (Out-dent -> Un-list -> Merge) and instant empty-item deletion.
- **Mobile Optimized Backspace**: Custom ZWSP Bridge to support software keyboards on iOS and Android.

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
