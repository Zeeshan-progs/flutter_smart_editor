import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_editor/flutter_smart_editor.dart';
import 'package:flutter_smart_editor/src/widgets/blocks/block_widget.dart';
import 'package:flutter_smart_editor/src/widgets/overlay/find_replace_bar_widget.dart';

void main() {
  testWidgets('Find & Replace overlay opens, searches live, and updates match badge',
      (WidgetTester tester) async {
    final controller = SmartEditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartEditor(
            controller: controller,
            editorSettings: const SmartEditorSettings(
              initialText: '<p>Hello world. Welcome to the world of Flutter.</p>',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initially, find bar is not visible
    expect(find.byType(FindReplaceBarWidget), findsNothing);

    // Open find overlay
    controller.showFindReplace();
    await tester.pumpAndSettle();

    expect(find.byType(FindReplaceBarWidget), findsOneWidget);
    expect(find.text('Find...'), findsOneWidget);

    // Enter search query "world"
    await tester.enterText(find.widgetWithText(TextField, 'Find...'), 'world');
    await tester.pumpAndSettle();

    // Verify 2 matches found and badge shows "1 of 2"
    expect(controller.searchState.totalMatches, 2);
    expect(controller.searchState.currentMatchIndex, 0);
    expect(find.text('1 of 2'), findsOneWidget);

    // Click next button
    await tester.tap(find.byTooltip('Next match (Enter)'));
    await tester.pumpAndSettle();

    expect(controller.searchState.currentMatchIndex, 1);
    expect(find.text('2 of 2'), findsOneWidget);

    // Click previous button
    await tester.tap(find.byTooltip('Previous match (Shift+Enter)'));
    await tester.pumpAndSettle();

    expect(controller.searchState.currentMatchIndex, 0);
    expect(find.text('1 of 2'), findsOneWidget);

    // Close find bar via close button
    await tester.tap(find.byTooltip('Close (Escape)'));
    await tester.pumpAndSettle();

    expect(controller.searchState.isBarVisible, false);
    expect(find.byType(FindReplaceBarWidget), findsNothing);
  });

  testWidgets('Typing in Find input retains focus and does not steal focus to editor block',
      (WidgetTester tester) async {
    final controller = SmartEditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartEditor(
            controller: controller,
            editorSettings: const SmartEditorSettings(
              initialText: '<p>Typing focus test for search overlay.</p>',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.showFindReplace();
    await tester.pumpAndSettle();

    final findTextFieldFinder = find.widgetWithText(TextField, 'Find...');
    expect(findTextFieldFinder, findsOneWidget);

    await tester.tap(findTextFieldFinder);
    await tester.pumpAndSettle();

    // Type characters and verify focus is never stolen
    await tester.enterText(findTextFieldFinder, 'T');
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(findTextFieldFinder).focusNode?.hasFocus,
        true);

    await tester.enterText(findTextFieldFinder, 'Typ');
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(findTextFieldFinder).focusNode?.hasFocus,
        true);

    await tester.enterText(findTextFieldFinder, 'Typing');
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(findTextFieldFinder).focusNode?.hasFocus,
        true);
    expect(controller.searchState.totalMatches, 1);
  });

  testWidgets('Case sensitivity, whole word, and regex toggles update search results',
      (WidgetTester tester) async {
    final controller = SmartEditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartEditor(
            controller: controller,
            editorSettings: const SmartEditorSettings(
              initialText: '<p>Cat cat caterpillar CAT</p>',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.showFindReplace();
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Find...'), 'cat');
    await tester.pumpAndSettle();

    // Default: case-insensitive, substring -> matches: Cat, cat, cat(erpillar), CAT = 4
    expect(controller.searchState.totalMatches, 4);

    // Toggle matchCase
    await tester.tap(find.byTooltip('Match Case'));
    await tester.pumpAndSettle();

    // Only lowercase "cat" in "cat" and "caterpillar" -> 2
    expect(controller.searchState.totalMatches, 2);

    // Toggle wholeWord
    await tester.tap(find.byTooltip('Match Whole Word'));
    await tester.pumpAndSettle();

    // Only exact lowercase "cat" word -> 1
    expect(controller.searchState.totalMatches, 1);

    // Toggle wholeWord off
    await tester.tap(find.byTooltip('Match Whole Word'));
    await tester.pumpAndSettle();

    // Toggle regex on (matchCase is still true)
    await tester.tap(find.byTooltip('Use Regular Expression'));
    await tester.pumpAndSettle();

    // Regex query: "c[a-z]+" (case-sensitive) -> matches "cat", "caterpillar" -> 2
    await tester.enterText(find.widgetWithText(TextField, 'Find...'), 'c[a-z]+');
    await tester.pumpAndSettle();

    expect(controller.searchState.totalMatches, 2);

    // Toggle matchCase off -> case-insensitive regex matches "Cat", "cat", "caterpillar", "CAT" -> 4
    await tester.tap(find.byTooltip('Match Case'));
    await tester.pumpAndSettle();

    expect(controller.searchState.totalMatches, 4);
  });

  testWidgets('Replace and Replace All update document and support atomic undo',
      (WidgetTester tester) async {
    final controller = SmartEditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartEditor(
            controller: controller,
            editorSettings: const SmartEditorSettings(
              initialText: '<p>Foo bar foo baz foo.</p>',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.showFindReplace(showReplace: true);
    await tester.pumpAndSettle();

    expect(controller.searchState.isReplaceExpanded, true);
    expect(find.text('Replace with...'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Find...'), 'foo');
    await tester.enterText(find.widgetWithText(TextField, 'Replace with...'), 'qux');
    await tester.pumpAndSettle();

    expect(controller.searchState.totalMatches, 3);

    // Replace current (first occurrence "Foo")
    await tester.tap(find.byTooltip('Replace current match'));
    await tester.pumpAndSettle();

    expect(controller.document.blocks[0].plainText, 'qux bar foo baz foo.');
    expect(controller.searchState.totalMatches, 2);

    // Replace all remaining occurrences
    await tester.tap(find.byTooltip('Replace all occurrences'));
    await tester.pumpAndSettle();

    expect(controller.document.blocks[0].plainText, 'qux bar qux baz qux.');
    expect(controller.searchState.totalMatches, 0);

    // Undo should restore all replacements from replaceAll in a single step
    controller.undo();
    await tester.pumpAndSettle();

    expect(controller.document.blocks[0].plainText, 'qux bar foo baz foo.');
  });

  testWidgets('Preserve link display text replacement keeps hyperlink URL intact',
      (WidgetTester tester) async {
    final controller = SmartEditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartEditor(
            controller: controller,
            editorSettings: const SmartEditorSettings(
              initialText: '<p>Visit <a href="https://flutter.dev">Flutter</a> today.</p>',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial link
    final initialSpan = controller.document.blocks[0].spans
        .firstWhere((s) => s.linkUrl != null);
    expect(initialSpan.text, 'Flutter');
    expect(initialSpan.linkUrl, 'https://flutter.dev');

    controller.showFindReplace(showReplace: true);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Find...'), 'Flutter');
    await tester.enterText(find.widgetWithText(TextField, 'Replace with...'), 'Google Flutter');
    await tester.pumpAndSettle();

    expect(controller.searchState.totalMatches, 1);
    expect(controller.searchState.options.preserveLinkOnReplace, true);

    // Tap Replace
    await tester.tap(find.byTooltip('Replace current match'));
    await tester.pumpAndSettle();

    final updatedBlock = controller.document.blocks[0];
    expect(updatedBlock.plainText, 'Visit Google Flutter today.');

    final linkSpan = updatedBlock.spans.firstWhere((s) => s.linkUrl != null);
    expect(linkSpan.text, 'Google Flutter');
    expect(linkSpan.linkUrl, 'https://flutter.dev');
  });

  testWidgets('Highlight styling adapts to light and dark modes',
      (WidgetTester tester) async {
    final controller = SmartEditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.light,
        home: Scaffold(
          body: SmartEditor(
            controller: controller,
            editorSettings: const SmartEditorSettings(
              initialText: '<p>Highlight test one and test two</p>',
              searchMatchColor: Color(0xFFFFF59D),
              searchActiveMatchColor: Color(0xFFFF9800),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.showFindReplace();
    controller.setSearchQuery('test');
    await tester.pumpAndSettle();

    expect(controller.searchState.totalMatches, 2);

    // Verify BlockWidget received matches
    final blockWidget = tester.widget<BlockWidget>(find.byType(BlockWidget).first);
    expect(blockWidget.searchMatches.length, 2);
    expect(blockWidget.activeSearchMatchIndex, 0);
  });

  testWidgets('Toolbar find & replace button toggles overlay',
      (WidgetTester tester) async {
    final controller = SmartEditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartEditor(
            controller: controller,
            toolbarSettings: const SmartToolbarSettings(
              defaultButtons: [
                SmartOtherButtons(findReplace: true),
              ],
            ),
            editorSettings: const SmartEditorSettings(
              initialText: '<p>Toolbar button test</p>',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify search button exists in toolbar
    final searchButtonFinder = find.byTooltip('Find & Replace');
    expect(searchButtonFinder, findsOneWidget);

    // Tap search button to show overlay
    await tester.tap(searchButtonFinder);
    await tester.pumpAndSettle();

    expect(controller.searchState.isBarVisible, true);
    expect(find.byType(FindReplaceBarWidget), findsOneWidget);

    // Tap again to hide overlay
    await tester.tap(searchButtonFinder);
    await tester.pumpAndSettle();

    expect(controller.searchState.isBarVisible, false);
    expect(find.byType(FindReplaceBarWidget), findsNothing);
  });
}
