/// Defines the toolbar layout mode
enum SmartToolbarType {
  /// Grid layout (wraps to multiple rows)
  grid,

  /// Single scrollable row (default)
  scrollable,

  /// Toggle between grid and scrollable with an expand/collapse icon
  expandable,
}

/// Defines where the toolbar is positioned relative to the editor
enum SmartToolbarPosition {
  /// Toolbar is above the editor area (default)
  above,

  /// Toolbar is below the editor area
  below,

  /// Toolbar is removed; user must place [SmartToolbar] widget manually
  custom,
}

/// Identifies a toolbar button type (used in onButtonPressed callback)
enum SmartButtonType {
  style,
  bold,
  italic,
  underline,
  clearFormatting,
  strikethrough,
  superscript,
  subscript,
  foregroundColor,
  highlightColor,
  ul,
  ol,
  alignLeft,
  alignCenter,
  alignRight,
  alignJustify,
  increaseIndent,
  decreaseIndent,
  ltr,
  rtl,
  link,
  picture,
  audio,
  video,
  otherFile,
  table,
  hr,
  fullscreen,
  codeview,
  undo,
  redo,
  help,
  copy,
  paste,
}

/// Identifies a toolbar dropdown type (used in onDropdownChanged callback)
enum SmartDropdownType {
  style,
  fontName,
  fontSize,
  fontSizeUnit,
  listStyles,
  lineHeight,
  caseConverter,
}

/// The type of block element
enum BlockType {
  paragraph,
  heading1,
  heading2,
  heading3,
  heading4,
  heading5,
  heading6,
}

/// Text alignment for a block
enum SmartTextAlign {
  left,
  center,
  right,
  justify,
}

/// Virtual keyboard type for mobile
enum SmartInputType {
  text,
  decimal,
  email,
  numeric,
  tel,
  url,
}

/// Notification style
enum SmartNotificationType {
  info,
  warning,
  success,
  danger,
  plaintext,
}

/// Direction for dropdown menu opening
enum SmartDropdownMenuDirection {
  down,
  up,
}
