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
  foregroundColor,
  highlightColor,
  ul,
  ol,
  alignLeft,
  alignCenter,
  alignRight,
  alignJustify,
  undo,
  redo,
  copy,
  paste,
  fontSize,
  fontName,
  blockType,
  bulletList,
  orderedList,
  horizontalRule,
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
  bulletList,
  orderedList,
  horizontalRule,
}

/// The type of list for a list item
enum SmartListType {
  /// Unordered list (`<ul>`)
  bullet,

  /// Ordered list (`<ol>`)
  ordered,
}

/// Predefined bullet shapes for unordered lists.
/// Can be set globally via [SmartEditorSettings.defaultBulletStyle]
/// or per-list via the toolbar bullet style picker.
enum SmartBulletStyle {
  /// • Filled circle (default)
  filledCircle,

  /// ◦ Hollow circle
  hollowCircle,

  /// ▪ Filled square
  filledSquare,

  /// □ Hollow square
  hollowSquare,

  /// ◆ Filled diamond
  diamond,

  /// ◇ Hollow diamond
  hollowDiamond,

  /// → Arrow
  arrow,

  /// » Double arrow
  doubleArrow,

  /// – Dash
  dash,

  /// ★ Filled star
  star,

  /// ☆ Hollow star
  hollowStar,

  /// ✓ Checkmark
  checkmark,

  /// ▶ Filled triangle
  triangle,
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

/// Direction for dropdown menu opening
enum SmartDropdownMenuDirection {
  down,
  up,
}

/// Identifies the type of HTML element being serialized.
enum SmartTagType {
  /// A block-level element (e.g. p, h1-h6)
  block,

  /// A bold text span (<b>)
  bold,

  /// An italic text span (<i>)
  italic,

  /// An underline text span (<u>)
  underline,

  /// A strikethrough text span (<s>)
  strikethrough,

  /// A hyperlink (<a>)
  link,

  /// A generic style span (<span>) for colors, fonts, etc.
  span,

  /// A list item (<li>)
  listItem,

  /// An unordered list container (<ul>)
  unorderedList,

  /// An ordered list container (<ol>)
  orderedList,

  /// A horizontal rule (<hr>)
  horizontalRule,
}
