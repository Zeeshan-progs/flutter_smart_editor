import 'dart:async';

import 'package:flutter/material.dart';
import 'enums.dart';
import 'toolbar_buttons.dart';

/// Toolbar appearance and behavior settings.
///
/// Controls which buttons are shown, how the toolbar is laid out,
/// and provides interceptors for button presses and dropdown changes.
class SmartToolbarSettings {
  const SmartToolbarSettings({
    this.toolbarType = SmartToolbarType.scrollable,
    this.toolbarPosition = SmartToolbarPosition.above,
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
    this.initiallyExpanded = false,
    // Button styling
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
    // Dropdown styling
    this.dropdownBackgroundColor,
    this.dropdownElevation = 8,
    this.dropdownItemHeight,
    this.dropdownMenuDirection,
    this.dropdownMenuMaxHeight,
    this.dropdownIconColor,
    this.dropdownIconSize = 24,
    // Separator
    this.separatorWidget,
    this.showSeparators = true,
    // Layout
    this.showBorder = false,
    this.textStyle,
    this.itemHeight = 36,
    this.gridSpacingH = 5,
    this.gridSpacingV = 5,
    // Interceptors
    this.onButtonPressed,
    this.onDropdownChanged,
  });

  /// Toolbar layout type
  final SmartToolbarType toolbarType;

  /// Where the toolbar is positioned relative to the editor
  final SmartToolbarPosition toolbarPosition;

  /// Which button groups are shown in the toolbar
  final List<SmartToolbarGroup> defaultButtons;

  /// Custom widgets added to the toolbar
  final List<Widget> customButtons;

  /// Indices at which custom buttons are inserted
  final List<int> customButtonInsertionIndices;

  /// Whether the expandable toolbar starts expanded (grid view)
  final bool initiallyExpanded;

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

  // ─── Dropdown Styling ─────────────────────────────────────────

  final Color? dropdownBackgroundColor;
  final int dropdownElevation;
  final double? dropdownItemHeight;
  final SmartDropdownMenuDirection? dropdownMenuDirection;
  final double? dropdownMenuMaxHeight;
  final Color? dropdownIconColor;
  final double dropdownIconSize;

  // ─── Layout ───────────────────────────────────────────────────

  final Widget? separatorWidget;
  final bool showSeparators;
  final bool showBorder;
  final TextStyle? textStyle;
  final double itemHeight;
  final double gridSpacingH;
  final double gridSpacingV;

  // ─── Interceptors ─────────────────────────────────────────────

  /// Intercept any button press. Return `true` to continue with default
  /// handler, `false` to handle it yourself.
  final FutureOr<bool> Function(SmartButtonType, bool?, Function?)?
      onButtonPressed;

  /// Intercept any dropdown change. Return `true` to continue with default
  /// handler, `false` to handle it yourself.
  final FutureOr<bool> Function(
      SmartDropdownType, dynamic, void Function(dynamic)?)? onDropdownChanged;
}
