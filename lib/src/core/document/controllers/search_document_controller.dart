import 'package:meta/meta.dart';
import 'package:flutter_smart_editor/src/core/document/document.dart';
import '../../../models/search/search_index.dart';
import 'image_document_controller.dart';

/// Controller handling live document searching, regex parsing, and atomic match replacement.
class SearchDocumentController extends ImageDocumentController {
  SearchDocumentController({
    super.document,
    super.undoRedoManager,
  });

  // ─── Find & Replace Operations ────────────────────────────────

  /// Searches the document for occurrences matching [query] with the given [options].
  /// Returns an ordered list of [SearchMatch]es across all blocks and table cells.
  List<SearchMatch> findMatches(String query, SearchOptions options) {
    if (query.isEmpty) return const [];

    RegExp regex;
    try {
      if (options.isRegex) {
        regex = RegExp(query, caseSensitive: options.matchCase);
      } else if (options.wholeWord) {
        regex = RegExp(
          r'\b' + RegExp.escape(query) + r'\b',
          caseSensitive: options.matchCase,
        );
      } else {
        regex = RegExp(
          RegExp.escape(query),
          caseSensitive: options.matchCase,
        );
      }
    } catch (_) {
      rethrow;
    }

    final matches = <SearchMatch>[];
    var globalMatchIndex = 0;

    for (var blockIndex = 0; blockIndex < document.blocks.length; blockIndex++) {
      final block = document.blocks[blockIndex];

      if (block is TableNode) {
        for (var r = 0; r < block.rowCount; r++) {
          for (var c = 0; c < block.colCount; c++) {
            final cell = block.getCell(r, c);
            final plainText = cell.plainText;
            if (plainText.isEmpty) continue;

            for (final match in regex.allMatches(plainText)) {
              String? linkUrl;
              final loc = cell.getSpanAt(match.start);
              if (loc.spanIndex < cell.spans.length) {
                final span = cell.spans[loc.spanIndex];
                if (span.linkUrl != null && span.linkUrl!.isNotEmpty) {
                  linkUrl = span.linkUrl;
                }
              }

              matches.add(SearchMatch(
                matchIndex: globalMatchIndex++,
                blockIndex: blockIndex,
                row: r,
                col: c,
                start: match.start,
                end: match.end,
                matchedText: match.group(0) ??
                    plainText.substring(match.start, match.end),
                linkUrl: linkUrl,
              ));
            }
          }
        }
      } else {
        final plainText = block.plainText;
        if (plainText.isEmpty) continue;

        for (final match in regex.allMatches(plainText)) {
          String? linkUrl;
          final loc = block.getSpanAt(match.start);
          if (loc.spanIndex < block.spans.length) {
            final span = block.spans[loc.spanIndex];
            if (span.linkUrl != null && span.linkUrl!.isNotEmpty) {
              linkUrl = span.linkUrl;
            }
          }

          matches.add(SearchMatch(
            matchIndex: globalMatchIndex++,
            blockIndex: blockIndex,
            start: match.start,
            end: match.end,
            matchedText: match.group(0) ??
                plainText.substring(match.start, match.end),
            linkUrl: linkUrl,
          ));
        }
      }
    }

    return matches;
  }

  /// Replaces a single [match] with [replacement], preserving link URL if [preserveLink] is true.
  void replaceMatch(
    SearchMatch match,
    String replacement, {
    bool preserveLink = true,
  }) {
    if (match.blockIndex < 0 || match.blockIndex >= document.blocks.length) {
      return;
    }
    saveState();

    applySingleReplacement(match, replacement, preserveLink: preserveLink);
    notifyChanged();
  }

  /// Replaces all [matches] across the document in a single atomic undo step.
  /// Returns the number of occurrences replaced.
  int replaceAllMatches(
    List<SearchMatch> matches,
    String replacement, {
    bool preserveLinks = true,
  }) {
    if (matches.isEmpty) return 0;
    saveState();

    // Process matches in reverse order so replacements at later offsets do not
    // disrupt preceding match offset ranges within the same block/cell.
    final sortedMatches = List<SearchMatch>.from(matches)
      ..sort((a, b) {
        if (a.blockIndex != b.blockIndex) {
          return b.blockIndex.compareTo(a.blockIndex);
        }
        if (a.row != b.row) return (b.row ?? 0).compareTo(a.row ?? 0);
        if (a.col != b.col) return (b.col ?? 0).compareTo(a.col ?? 0);
        return b.start.compareTo(a.start);
      });

    for (final match in sortedMatches) {
      applySingleReplacement(match, replacement, preserveLink: preserveLinks);
    }

    notifyChanged();
    return matches.length;
  }

  @protected
  void applySingleReplacement(
    SearchMatch match,
    String replacement, {
    required bool preserveLink,
  }) {
    final block = document.blocks[match.blockIndex];

    if (match.isTableCell && block is TableNode) {
      final cell = block.getCell(match.row!, match.col!);
      final length = match.end - match.start;
      if (length <= 0) return;

      deleteFromCellSpans(cell, match.start, length);

      if (replacement.isNotEmpty) {
        if (preserveLink && match.isLink) {
          final linkSpan =
              TextFormatSpan(text: replacement, linkUrl: match.linkUrl);
          insertFormattedIntoCellSpans(
              cell, match.start, replacement, linkSpan);
        } else {
          insertIntoCellSpans(cell, match.start, replacement);
        }
      }
      cell.normalizeSpans();
    } else {
      final length = match.end - match.start;
      if (length <= 0) return;

      deleteFromSpans(block, match.start, length);

      if (replacement.isNotEmpty) {
        if (preserveLink && match.isLink) {
          final linkSpan =
              TextFormatSpan(text: replacement, linkUrl: match.linkUrl);
          insertFormattedIntoSpans(block, match.start, replacement, linkSpan);
        } else {
          insertIntoSpans(block, match.start, replacement);
        }
      }
      block.normalizeSpans();
    }
  }
}
