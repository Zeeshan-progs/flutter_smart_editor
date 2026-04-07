import 'dart:async';
import 'package:flutter/material.dart';
import 'enums.dart';
import 'toolbar_buttons.dart';

/// Comprehensive settings for the toolbar's behavior, layout, and style.
///
/// Controls which buttons are shown, how the toolbar is laid out,
/// and provides visual customization for buttons, dropdowns, and containers.
class SmartToolbarSettings {
  const SmartToolbarSettings({
    // Layout & Position
    this.toolbarType = SmartToolbarType.scrollable,
    this.toolbarPosition = SmartToolbarPosition.above,
    this.initiallyExpanded = false,
    this.showBorder = false,
    this.showSeparators = true,
    this.itemHeight = 36,
    this.gridSpacingH = 5,
    this.gridSpacingV = 5,
    this.separatorWidget,

    // Buttons & Content
    this.defaultButtons = const [
      SmartStyleButtons(),
      SmartFontButtons(clearAll: false),
      SmartInsertButtons(
        audio: false,
        video: false,
        table: false,
        hr: false,
        otherFile: false,
      ),
      SmartOtherButtons(
        fullscreen: false,
        codeview: false,
        help: false,
      ),
    ],
    this.customButtons = const [],
    this.customButtonInsertionIndices = const [],

    // Container Styling
    this.decoration,
    this.padding,

    // Button Styling
    this.buttonColor,
    this.buttonSelectedColor,
    this.buttonFillColor,
    this.buttonFocusColor,
    this.buttonHighlightColor,
    this.buttonHoverColor,
    this.buttonSplashColor,
    this.buttonBorderColor,
    this.buttonSelectedBorderColor,
    this.buttonBorderRadius,
    this.buttonBorderWidth,
    this.buttonIconSize = 20.0,
    this.textStyle,

    // Dropdown Styling
    this.dropdownBackgroundColor,
    this.dropdownElevation = 8,
    this.dropdownItemHeight,
    this.dropdownMenuDirection,
    this.dropdownMenuMaxHeight,
    this.dropdownIconColor,
    this.dropdownIconSize = 24,

    // Interceptors & Actions
    this.onButtonPressed,
    this.onDropdownChanged,
  });

  // ─── Layout & Position ────────────────────────────────────────

  /// Toolbar layout type (.scrollable, .grid, .expandable)
  final SmartToolbarType toolbarType;

  /// Where the toolbar is positioned relative to the editor
  final SmartToolbarPosition toolbarPosition;

  /// Whether the expandable toolbar starts expanded
  final bool initiallyExpanded;

  /// Draws a separating border between toolbar and editor
  final bool showBorder;

  /// Shows vertical separators between button groups
  final bool showSeparators;

  /// Height of the toolbar items (buttons/chips)
  final double itemHeight;

  /// Horizontal spacing in grid/wrap layouts
  final double gridSpacingH;

  /// Vertical spacing in grid/wrap layouts
  final double gridSpacingV;

  /// Custom widget to use as a separator
  final Widget? separatorWidget;

  // ─── Buttons & Content ────────────────────────────────────────

  /// Which button groups are shown in the toolbar
  final List<SmartToolbarGroup> defaultButtons;

  /// Custom widgets added to the toolbar
  final List<Widget> customButtons;

  /// Indices at which custom buttons are inserted
  final List<int> customButtonInsertionIndices;

  // ─── Container Styling ────────────────────────────────────────

  /// Decoration for the toolbar container
  final BoxDecoration? decoration;

  /// Padding inside the toolbar container
  final EdgeInsets? padding;

  // ─── Button Styling ───────────────────────────────────────────

  final Color? buttonColor;
  final Color? buttonSelectedColor;
  final Color? buttonFillColor;
  final Color? buttonFocusColor;
  final Color? buttonHighlightColor;
  final Color? buttonHoverColor;
  final Color? buttonSplashColor;
  final Color? buttonBorderColor;
  final Color? buttonSelectedBorderColor;
  final BorderRadius? buttonBorderRadius;
  final double? buttonBorderWidth;
  final double buttonIconSize;

  /// Text style for toolbar labels/chips
  final TextStyle? textStyle;

  // ─── Dropdown Styling ─────────────────────────────────────────

  final Color? dropdownBackgroundColor;
  final int dropdownElevation;
  final double? dropdownItemHeight;
  final SmartDropdownMenuDirection? dropdownMenuDirection;
  final double? dropdownMenuMaxHeight;
  final Color? dropdownIconColor;
  final double dropdownIconSize;

  // ─── Interceptors & Actions ───────────────────────────────────

  /// Intercept any button press. Return `true` to continue with default.
  final FutureOr<bool> Function(SmartButtonType, bool?, Function?)?
      onButtonPressed;

  /// Intercept any dropdown change. Return `true` to continue with default.
  final FutureOr<bool> Function(
      SmartDropdownType, dynamic, void Function(dynamic)?)? onDropdownChanged;
}
