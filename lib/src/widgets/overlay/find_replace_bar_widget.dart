import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../smart_editor_controller.dart';
import '../../models/search/search_index.dart';

/// A sleek, floating Find & Replace panel anchored over the editor canvas.
class FindReplaceBarWidget extends StatefulWidget {
  final SmartEditorController controller;
  final bool isDarkMode;
  final Color? searchMatchColor;
  final Color? searchActiveMatchColor;

  const FindReplaceBarWidget({
    super.key,
    required this.controller,
    this.isDarkMode = false,
    this.searchMatchColor,
    this.searchActiveMatchColor,
  });

  @override
  State<FindReplaceBarWidget> createState() => _FindReplaceBarWidgetState();
}

class _FindReplaceBarWidgetState extends State<FindReplaceBarWidget> {
  late TextEditingController _findController;
  late TextEditingController _replaceController;
  final FocusNode _findFocusNode = FocusNode();
  final FocusNode _replaceFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final state = widget.controller.searchState;
    _findController = TextEditingController(text: state.query);
    _replaceController = TextEditingController(text: state.replaceText);

    // Auto-focus find input when opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _findFocusNode.requestFocus();
        _findController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _findController.text.length,
        );
      }
    });
  }

  @override
  void didUpdateWidget(FindReplaceBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final state = widget.controller.searchState;
    if (_findController.text != state.query) {
      _findController.value = _findController.value.copyWith(
        text: state.query,
        selection: TextSelection.collapsed(offset: state.query.length),
      );
    }
    if (_replaceController.text != state.replaceText) {
      _replaceController.value = _replaceController.value.copyWith(
        text: state.replaceText,
        selection: TextSelection.collapsed(offset: state.replaceText.length),
      );
    }
  }

  @override
  void dispose() {
    _findController.dispose();
    _replaceController.dispose();
    _findFocusNode.dispose();
    _replaceFocusNode.dispose();
    super.dispose();
  }

  void _onFindSubmitted(String value) {
    if (HardwareKeyboard.instance.isShiftPressed) {
      widget.controller.findPrevious();
    } else {
      widget.controller.findNext();
    }
    _findFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? const Color(0xFF252526) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF454545) : const Color(0xFFE0E0E0);
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.grey[500] : Colors.grey[400];

    return ValueListenableBuilder<SearchState>(
      valueListenable: widget.controller.searchStateNotifier,
      builder: (context, state, _) {
        return Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              widget.controller.hideFindReplace();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border(
                bottom: BorderSide(color: borderColor, width: 1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row 1: Find Row
                _buildFindRow(state, textColor, hintColor, isDark),

                // Row 2: Replace Row (when expanded)
                if (state.isReplaceExpanded) ...[
                  const SizedBox(height: 6),
                  _buildReplaceRow(state, textColor, hintColor, isDark),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFindRow(
    SearchState state,
    Color textColor,
    Color? hintColor,
    bool isDark,
  ) {
    final hasQuery = state.query.isNotEmpty;
    final countText = !hasQuery
        ? ''
        : state.hasMatches
            ? '${state.currentMatchIndex + 1} of ${state.totalMatches}'
            : (state.errorMessage != null ? 'Regex Error' : 'No matches');

    return Row(
      children: [
        // Expand/Collapse Replace toggle
        IconButton(
          tooltip:
              state.isReplaceExpanded ? 'Collapse Replace' : 'Expand Replace',
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
          icon: Icon(
            state.isReplaceExpanded
                ? Icons.keyboard_arrow_down
                : Icons.keyboard_arrow_right,
            color: textColor.withValues(alpha: 0.7),
          ),
          onPressed: () {
            widget.controller.setReplaceExpanded(!state.isReplaceExpanded);
          },
        ),

        // Search Input Field
        Expanded(
          child: Container(
            height: 32,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3C3C3C) : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: state.errorMessage != null
                    ? Colors.red.shade400
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    cursorHeight: 14,
                    controller: _findController,
                    focusNode: _findFocusNode,
                    style: TextStyle(fontSize: 13, color: textColor),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Find...',
                      hintStyle: TextStyle(fontSize: 13, color: hintColor),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: (text) => widget.controller.setSearchQuery(text),
                    onSubmitted: _onFindSubmitted,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (countText.isNotEmpty) ...[
          Text(
            countText,
            style: TextStyle(
              fontSize: 11,
              color: state.hasMatches
                  ? textColor.withValues(alpha: 0.6)
                  : (state.errorMessage != null
                      ? Colors.red.shade400
                      : textColor.withValues(alpha: 0.4)),
              fontWeight:
                  state.hasMatches ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
        const SizedBox(width: 4),

        // Option Toggles
        _buildToggle(
          label: 'Aa',
          tooltip: 'Match Case',
          isSelected: state.options.matchCase,
          onTap: () {
            widget.controller.setSearchOptions(
              state.options.copyWith(matchCase: !state.options.matchCase),
            );
          },
          isDark: isDark,
        ),
        const SizedBox(width: 4),

        _buildToggle(
          icon: Icons.abc,
          iconSize: 18,
          tooltip: 'Match Whole Word',
          isSelected: state.options.wholeWord,
          onTap: () {
            widget.controller.setSearchOptions(
              state.options.copyWith(wholeWord: !state.options.wholeWord),
            );
          },
          isDark: isDark,
        ),
        const SizedBox(width: 4),

        _buildToggle(
          label: '.*',
          tooltip: 'Use Regular Expression',
          isSelected: state.options.isRegex,
          onTap: () {
            widget.controller.setSearchOptions(
              state.options.copyWith(isRegex: !state.options.isRegex),
            );
          },
          isDark: isDark,
        ),

        const SizedBox(width: 4),

        // Prev & Next navigation
        Tooltip(
          message: 'Previous match (Shift+Enter)',
          child: InkWell(
            onTap: state.hasMatches ? widget.controller.findPrevious : null,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_upward,
                size: 18,
                color: state.hasMatches
                    ? textColor.withValues(alpha: 0.8)
                    : textColor.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Tooltip(
          message: 'Next match (Enter)',
          child: InkWell(
            onTap: state.hasMatches ? widget.controller.findNext : null,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_downward,
                size: 18,
                color: state.hasMatches
                    ? textColor.withValues(alpha: 0.8)
                    : textColor.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),

        // Close button
        IconButton(
          tooltip: 'Close (Escape)',
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          icon: Icon(
            Icons.close,
            color: textColor.withValues(alpha: 0.8),
          ),
          onPressed: widget.controller.hideFindReplace,
        ),
      ],
    );
  }

  Widget _buildReplaceRow(
    SearchState state,
    Color textColor,
    Color? hintColor,
    bool isDark,
  ) {
    return Row(
      children: [
        // Spacing corresponding to chevron column
        const SizedBox(width: 26),

        // Replace Input Field
        Expanded(
          child: Container(
            height: 32,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3C3C3C) : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const SizedBox(width: 6),
                Icon(
                  Icons.find_replace,
                  size: 16,
                  color: textColor.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _replaceController,
                    focusNode: _replaceFocusNode,
                    style: TextStyle(fontSize: 13, color: textColor),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Replace with...',
                      hintStyle: TextStyle(fontSize: 13, color: hintColor),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: (text) => widget.controller.setReplaceText(text),
                    onSubmitted: (_) {
                      widget.controller.replaceCurrent();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 4),

        // Toggle: Preserve link display text
        _buildToggle(
          icon: Icons.link,
          tooltip: state.options.preserveLinkOnReplace
              ? 'Preserve hyperlinks on replace: Enabled'
              : 'Preserve hyperlinks on replace: Disabled',
          isSelected: state.options.preserveLinkOnReplace,
          onTap: () {
            widget.controller.setSearchOptions(
              state.options.copyWith(
                preserveLinkOnReplace: !state.options.preserveLinkOnReplace,
              ),
            );
          },
          isDark: isDark,
        ),

        const SizedBox(width: 4),

        // Replace Button
        _buildActionButton(
          label: 'Replace',
          tooltip: 'Replace current match',
          enabled: state.hasMatches,
          onTap: widget.controller.replaceCurrent,
          isDark: isDark,
        ),

        const SizedBox(width: 4),

        // Replace All Button
        _buildActionButton(
          label: 'All',
          tooltip: 'Replace all occurrences',
          enabled: state.hasMatches,
          onTap: widget.controller.replaceAll,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildToggle({
    String? label,
    IconData? icon,
    double? iconSize,
    Widget Function(Color color, bool isSelected)? iconBuilder,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final activeBg = primaryColor.withValues(alpha: isDark ? 0.35 : 0.18);
    final activeBorder = primaryColor.withValues(alpha: 0.6);
    final inactiveColor = isDark ? Colors.white60 : Colors.black54;
    final color = isSelected ? primaryColor : inactiveColor;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected ? activeBorder : Colors.transparent,
              width: 1,
            ),
          ),
          child: iconBuilder != null
              ? iconBuilder(color, isSelected)
              : icon != null
                  ? Icon(
                      icon,
                      size: iconSize ?? 15,
                      color: color,
                    )
                  : Text(
                      label ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: color,
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required String tooltip,
    required bool enabled,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final textColor = isDark ? Colors.white : Colors.black87;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF3C3C3C) : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isDark ? const Color(0xFF555555) : const Color(0xFFD6D6D6),
              width: 0.8,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: enabled ? textColor : textColor.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}
