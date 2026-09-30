import 'package:flutter/foundation.dart';

/// Represents a single text search match within a document block or table cell.
@immutable
class SearchMatch {
  /// Global sequential 0-based match index across the document.
  final int matchIndex;

  /// Index of the containing block in [Document.blocks].
  final int blockIndex;

  /// Table row index if the match is inside a [TableNode], or null for standard blocks.
  final int? row;

  /// Table column index if the match is inside a [TableNode], or null for standard blocks.
  final int? col;

  /// Start offset in plainText (0-based).
  final int start;

  /// End offset in plainText (exclusive).
  final int end;

  /// The matched text substring.
  final String matchedText;

  /// Associated link URL if the match is inside a hyperlink span.
  final String? linkUrl;

  const SearchMatch({
    required this.matchIndex,
    required this.blockIndex,
    this.row,
    this.col,
    required this.start,
    required this.end,
    required this.matchedText,
    this.linkUrl,
  });

  /// Whether this match is inside a table cell.
  bool get isTableCell => row != null && col != null;

  /// Whether this match is part of a hyperlink.
  bool get isLink => linkUrl != null && linkUrl!.isNotEmpty;

  /// Length of the matched text.
  int get length => end - start;

  SearchMatch copyWith({
    int? matchIndex,
    int? blockIndex,
    int? row,
    int? col,
    int? start,
    int? end,
    String? matchedText,
    String? linkUrl,
  }) {
    return SearchMatch(
      matchIndex: matchIndex ?? this.matchIndex,
      blockIndex: blockIndex ?? this.blockIndex,
      row: row ?? this.row,
      col: col ?? this.col,
      start: start ?? this.start,
      end: end ?? this.end,
      matchedText: matchedText ?? this.matchedText,
      linkUrl: linkUrl ?? this.linkUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchMatch &&
        other.matchIndex == matchIndex &&
        other.blockIndex == blockIndex &&
        other.row == row &&
        other.col == col &&
        other.start == start &&
        other.end == end &&
        other.matchedText == matchedText &&
        other.linkUrl == linkUrl;
  }

  @override
  int get hashCode => Object.hash(
        matchIndex,
        blockIndex,
        row,
        col,
        start,
        end,
        matchedText,
        linkUrl,
      );

  @override
  String toString() =>
      'SearchMatch(#$matchIndex, block: $blockIndex${isTableCell ? " [$row,$col]" : ""}, range: [$start, $end], text: "$matchedText"${isLink ? ", link: $linkUrl" : ""})';
}
