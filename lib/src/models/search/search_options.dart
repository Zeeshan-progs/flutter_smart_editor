import 'package:flutter/foundation.dart';

/// Configuration options for document search in [SmartEditor].
@immutable
class SearchOptions {
  /// Whether the search should differentiate between uppercase and lowercase.
  final bool matchCase;

  /// Whether the search should match full words only.
  final bool wholeWord;

  /// Whether the query is treated as a regular expression.
  final bool isRegex;

  /// If true, when replacing a match inside a hyperlink, the replacement text
  /// updates the link's display text while preserving the existing link URL (`linkUrl`).
  /// If false, replaces with unlinked plain text.
  final bool preserveLinkOnReplace;

  const SearchOptions({
    this.matchCase = false,
    this.wholeWord = false,
    this.isRegex = false,
    this.preserveLinkOnReplace = true,
  });

  SearchOptions copyWith({
    bool? matchCase,
    bool? wholeWord,
    bool? isRegex,
    bool? preserveLinkOnReplace,
  }) {
    return SearchOptions(
      matchCase: matchCase ?? this.matchCase,
      wholeWord: wholeWord ?? this.wholeWord,
      isRegex: isRegex ?? this.isRegex,
      preserveLinkOnReplace:
          preserveLinkOnReplace ?? this.preserveLinkOnReplace,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchOptions &&
        other.matchCase == matchCase &&
        other.wholeWord == wholeWord &&
        other.isRegex == isRegex &&
        other.preserveLinkOnReplace == preserveLinkOnReplace;
  }

  @override
  int get hashCode => Object.hash(
        matchCase,
        wholeWord,
        isRegex,
        preserveLinkOnReplace,
      );

  @override
  String toString() =>
      'SearchOptions(matchCase: $matchCase, wholeWord: $wholeWord, isRegex: $isRegex, preserveLinkOnReplace: $preserveLinkOnReplace)';
}
