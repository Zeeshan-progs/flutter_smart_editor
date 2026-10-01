import 'package:flutter/foundation.dart';
import 'search_match.dart';
import 'search_options.dart';

/// Represents the complete state of the Find & Replace feature.
@immutable
class SearchState {
  /// The active search query text.
  final String query;

  /// The active replacement text.
  final String replaceText;

  /// Active search options.
  final SearchOptions options;

  /// All matches currently found across the document.
  final List<SearchMatch> matches;

  /// Index of the currently active match within [matches], or -1 if none.
  final int currentMatchIndex;

  /// Whether the Find & Replace bar is currently displayed.
  final bool isBarVisible;

  /// Whether the Replace row is expanded.
  final bool isReplaceExpanded;

  /// Optional error message (e.g. for invalid regular expressions).
  final String? errorMessage;

  const SearchState({
    this.query = '',
    this.replaceText = '',
    this.options = const SearchOptions(),
    this.matches = const [],
    this.currentMatchIndex = -1,
    this.isBarVisible = false,
    this.isReplaceExpanded = false,
    this.errorMessage,
  });

  /// An empty initial search state.
  static const SearchState empty = SearchState();

  /// Total number of matches found.
  int get totalMatches => matches.length;

  /// Whether any matches are found.
  bool get hasMatches => matches.isNotEmpty;

  /// The currently focused match, or null.
  SearchMatch? get currentMatch =>
      (currentMatchIndex >= 0 && currentMatchIndex < matches.length)
          ? matches[currentMatchIndex]
          : null;

  SearchState copyWith({
    String? query,
    String? replaceText,
    SearchOptions? options,
    List<SearchMatch>? matches,
    int? currentMatchIndex,
    bool? isBarVisible,
    bool? isReplaceExpanded,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      replaceText: replaceText ?? this.replaceText,
      options: options ?? this.options,
      matches: matches ?? this.matches,
      currentMatchIndex: currentMatchIndex ?? this.currentMatchIndex,
      isBarVisible: isBarVisible ?? this.isBarVisible,
      isReplaceExpanded: isReplaceExpanded ?? this.isReplaceExpanded,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchState &&
        other.query == query &&
        other.replaceText == replaceText &&
        other.options == options &&
        listEquals(other.matches, matches) &&
        other.currentMatchIndex == currentMatchIndex &&
        other.isBarVisible == isBarVisible &&
        other.isReplaceExpanded == isReplaceExpanded &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(
        query,
        replaceText,
        options,
        Object.hashAll(matches),
        currentMatchIndex,
        isBarVisible,
        isReplaceExpanded,
        errorMessage,
      );

  @override
  String toString() =>
      'SearchState(query: "$query", matches: ${matches.length}, current: $currentMatchIndex, visible: $isBarVisible, replaceOpen: $isReplaceExpanded${errorMessage != null ? ", error: $errorMessage" : ""})';
}
