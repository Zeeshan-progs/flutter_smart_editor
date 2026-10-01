import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_editor/flutter_smart_editor.dart';
import 'package:flutter_smart_editor/src/widgets/toolbar/inputs/link_dialog.dart';

void main() {
  testWidgets('LinkDialog pre-fills text and submits normalized URL',
      (WidgetTester tester) async {
    Map<String, dynamic>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (_) => const LinkDialog(
                    initialText: 'Flutter',
                    initialUrl: null,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    // Open dialog
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Verify Display Text is pre-filled
    expect(find.text('Flutter'), findsOneWidget);

    // Enter URL without scheme
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Link URL'), 'flutter.dev');

    // Tap Insert
    await tester.tap(find.text('Insert'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!['action'], 'insert');
    expect(result!['text'], 'Flutter');
    expect(result!['url'], 'https://flutter.dev');
  });

  testWidgets('SmartEditor toolbar link button applies link to selected text',
      (WidgetTester tester) async {
    final controller = SmartEditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartEditor(
            controller: controller,
            editorSettings: const SmartEditorSettings(
              initialText: '<p>Learning Flutter today</p>',
            ),
            toolbarSettings: const SmartToolbarSettings(
              defaultButtons: [
                SmartInsertButtons(link: true, table: false),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial content
    expect(
        controller.document.blocks.first.plainText, 'Learning Flutter today');

    // Select "Flutter" (offsets 9 to 16 in document)
    // In EditableText controller, offsets include ZWSP so raw is 10 to 17
    final editableFinder = find.byType(EditableText);
    expect(editableFinder, findsWidgets);

    final editable = tester.widget<EditableText>(editableFinder.first);
    editable.controller.selection = const TextSelection(
      baseOffset: 10,
      extentOffset: 17,
    );
    await tester.pump();

    // Tap Insert Link button in toolbar
    final linkButtonFinder = find.byTooltip('Insert Link');
    expect(linkButtonFinder, findsOneWidget);
    await tester.tap(linkButtonFinder);
    await tester.pumpAndSettle();

    // Verify LinkDialog opened with pre-filled "Flutter"
    expect(find.text('Insert Link'), findsOneWidget);
    expect(find.text('Flutter'), findsWidgets);

    // Type URL
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Link URL'), 'https://flutter.dev');
    await tester.pump();

    // Tap Insert button
    await tester.tap(find.text('Insert'));
    await tester.pumpAndSettle();

    // Verify document block has link applied
    final block = controller.document.blocks.first;
    expect(block.plainText, 'Learning Flutter today');
    final linkInfo = controller.getLinkInfo(
      blockIndex: 0,
      selection: const TextSelection(baseOffset: 9, extentOffset: 16),
    );
    expect(linkInfo['text'], 'Flutter');
    expect(linkInfo['url'], 'https://flutter.dev');
  });

  testWidgets('SmartEditor link dialog replaces text if edited',
      (WidgetTester tester) async {
    final controller = SmartEditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartEditor(
            controller: controller,
            editorSettings: const SmartEditorSettings(
              initialText: '<p>Awesome Framework</p>',
            ),
            toolbarSettings: const SmartToolbarSettings(
              defaultButtons: [
                SmartInsertButtons(link: true, table: false),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Select "Awesome" (0 to 7 in document -> 1 to 8 raw)
    final editableFinder = find.byType(EditableText);
    final editable = tester.widget<EditableText>(editableFinder.first);
    editable.controller.selection = const TextSelection(
      baseOffset: 1,
      extentOffset: 8,
    );
    await tester.pump();

    // Tap Insert Link button
    await tester.tap(find.byTooltip('Insert Link'));
    await tester.pumpAndSettle();

    // Edit Display Text to "Incredible"
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Display Text'), 'Incredible');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Link URL'), 'https://flutter.dev');
    await tester.pump();

    // Tap Insert
    await tester.tap(find.text('Insert'));
    await tester.pumpAndSettle();

    // Verify document text was replaced
    final block = controller.document.blocks.first;
    expect(block.plainText, 'Incredible Framework');
    // Link toolbar button should NOT look selected (tooltip is 'Insert Link', not 'Edit Link')
    expect(find.byTooltip('Insert Link'), findsOneWidget);
    expect(find.byTooltip('Edit Link'), findsNothing);
  });

  testWidgets(
      'Adding link appends single space if not present, moves cursor after space, and unselects link button',
      (WidgetTester tester) async {
    final controller = SmartEditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartEditor(
            controller: controller,
            editorSettings: const SmartEditorSettings(
              initialText: '<p>Flutter</p>',
            ),
            toolbarSettings: const SmartToolbarSettings(
              defaultButtons: [
                SmartInsertButtons(link: true, table: false),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Select "Flutter" (offsets 0 to 7 in document -> 1 to 8 raw)
    final editableFinder = find.byType(EditableText);
    final editable = tester.widget<EditableText>(editableFinder.first);
    editable.controller.selection = const TextSelection(
      baseOffset: 1,
      extentOffset: 8,
    );
    await tester.pump();

    // Tap Insert Link button
    await tester.tap(find.byTooltip('Insert Link'));
    await tester.pumpAndSettle();

    // Enter URL
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Link URL'), 'https://flutter.dev');
    await tester.pump();

    // Tap Insert
    await tester.tap(find.text('Insert'));
    await tester.pumpAndSettle();

    // Verify a single space was appended after "Flutter"
    final block = controller.document.blocks.first;
    expect(block.plainText, 'Flutter ');
    expect(block.spans.length, 2);
    expect(block.spans[0].text, 'Flutter');
    expect(block.spans[0].linkUrl, 'https://flutter.dev');
    expect(block.spans[1].text, ' ');
    expect(block.spans[1].linkUrl, isNull);

    // Verify cursor is after the space (offset 8 in document -> offset 9 raw)
    expect(controller.cursorOffset, 8);

    // Verify toolbar link option does NOT look selected
    expect(find.byTooltip('Insert Link'), findsOneWidget);
    expect(find.byTooltip('Edit Link'), findsNothing);
  });

  testWidgets(
      'Adding link with display text "test" styles entire word including last character',
      (WidgetTester tester) async {
    final controller = SmartEditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartEditor(
            controller: controller,
            editorSettings: const SmartEditorSettings(
              initialText: '<p></p>',
            ),
            toolbarSettings: const SmartToolbarSettings(
              defaultButtons: [
                SmartInsertButtons(link: true, table: false),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Insert Link button
    await tester.tap(find.byTooltip('Insert Link'));
    await tester.pumpAndSettle();

    // Enter display text "test" and URL "https://example.com"
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Display Text'), 'test');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Link URL'), 'https://example.com');
    await tester.pump();

    // Tap Insert
    await tester.tap(find.text('Insert'));
    await tester.pumpAndSettle();

    final block = controller.document.blocks.first;
    expect(block.plainText, 'test ');

    // Inspect the rendered TextSpan in the EditableText widget
    final editableFinder = find.byType(EditableText);
    final editable = tester.widget<EditableText>(editableFinder.first);
    final context = tester.element(editableFinder.first);
    final span = editable.controller.buildTextSpan(
      context: context,
      withComposing: false,
    );

    // The span should have children: [ZWSP, 'test', ' ']
    // 'test' must be the whole word with link styling (underline, blue color)
    final textChildren = span.children!.cast<TextSpan>();
    expect(textChildren[0].text, '\u200B');
    expect(textChildren[1].text, 'test');
    expect(textChildren[1].style?.decoration, TextDecoration.underline);
    expect(textChildren[1].style?.color, const Color(0xFF1E88E5));
    expect(textChildren[2].text, ' ');
    expect(textChildren[2].style?.decoration, TextDecoration.none);
  });

  testWidgets('insertLink performs atomic modification in a single undo step',
      (WidgetTester tester) async {
    final controller = SmartEditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartEditor(
            controller: controller,
            editorSettings: const SmartEditorSettings(
              initialText: '<p>Original</p>',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.document.blocks.first.plainText, 'Original');

    // Replace "Original" with link "Flutter"
    controller.insertLink(
      'https://flutter.dev',
      'Flutter',
      blockIndex: 0,
      selection: const TextSelection(baseOffset: 0, extentOffset: 8),
    );
    await tester.pumpAndSettle();

    expect(controller.document.blocks.first.plainText, 'Flutter ');

    // Undo should restore "Original" in exactly one step
    controller.undo();
    await tester.pumpAndSettle();

    expect(controller.document.blocks.first.plainText, 'Original');
  });

  testWidgets(
      'Link tooltip appears on cursor placement and dismisses on tap outside',
      (WidgetTester tester) async {
    final controller = SmartEditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const SizedBox(height: 50, child: Text('Header')),
              Expanded(
                child: SmartEditor(
                  controller: controller,
                  editorSettings: const SmartEditorSettings(
                    initialText:
                        '<p>Visit <a href="https://flutter.dev">Flutter</a> website</p>',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initially no tooltip
    expect(find.byTooltip('Open link'), findsNothing);

    // Place cursor on "Flutter" (offset 6)
    controller.setCursorPosition(0, 6);
    await tester.pumpAndSettle();

    // Verify tooltip is visible
    expect(find.byTooltip('Open link'), findsOneWidget);
    expect(find.text('https://flutter.dev'), findsOneWidget);

    // Tap outside (e.g. Header at top)
    await tester.tap(find.text('Header'));
    await tester.pumpAndSettle();

    // Verify tooltip is dismissed
    expect(find.byTooltip('Open link'), findsNothing);
  });

  testWidgets('Link tooltip dismisses when typing in editor',
      (WidgetTester tester) async {
    final controller = SmartEditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartEditor(
            controller: controller,
            editorSettings: const SmartEditorSettings(
              initialText: '<p><a href="https://flutter.dev">Flutter</a></p>',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Place cursor on link (offset 2)
    controller.setCursorPosition(0, 2);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Open link'), findsOneWidget);

    // Type text into editor
    final editableFinder = find.byType(EditableText);
    await tester.enterText(editableFinder.first, '\u200BFluttering');
    await tester.pumpAndSettle();

    // Tooltip should be dismissed
    expect(find.byTooltip('Open link'), findsNothing);
  });

  testWidgets('Link tooltip dismisses when toolbar button is tapped',
      (WidgetTester tester) async {
    final controller = SmartEditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartEditor(
            controller: controller,
            editorSettings: const SmartEditorSettings(
              initialText:
                  '<p><a href="https://flutter.dev">Flutter</a> is great</p>',
            ),
            toolbarSettings: const SmartToolbarSettings(
              defaultButtons: [
                SmartFontButtons(bold: true),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Place cursor on link (offset 2)
    controller.setCursorPosition(0, 2);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Open link'), findsOneWidget);

    // Tap Bold button on toolbar
    await tester.tap(find.byTooltip('Bold'));
    await tester.pumpAndSettle();

    // Tooltip should be dismissed
    expect(find.byTooltip('Open link'), findsNothing);
  });

  testWidgets('Link tooltip appears when selecting linked text in editor',
      (WidgetTester tester) async {
    final controller = SmartEditorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartEditor(
            controller: controller,
            editorSettings: const SmartEditorSettings(
              initialText:
                  '<p>Visit <a href="https://flutter.dev">Flutter</a> website</p>',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initially no tooltip
    expect(find.byTooltip('Open link'), findsNothing);

    // Select "Flutter" (offsets 6 to 13)
    controller.setSelection(0, 6, 13);
    await tester.pumpAndSettle();

    // Tooltip should appear for the selected link text
    expect(find.byTooltip('Open link'), findsOneWidget);
    expect(find.text('https://flutter.dev'), findsOneWidget);

    // Now select non-linked text "website" (offsets 14 to 21)
    controller.setSelection(0, 14, 21);
    await tester.pumpAndSettle();

    // Tooltip should be dismissed for non-linked selection
    expect(find.byTooltip('Open link'), findsNothing);
  });

  testWidgets(
      'Link tooltip stays visible inside ancestor SingleChildScrollView and dismisses on scroll',
      (WidgetTester tester) async {
    final controller = SmartEditorController();
    addTearDown(controller.dispose);
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scrollController,
            child: SizedBox(
              height: 1200,
              child: SmartEditor(
                controller: controller,
                editorSettings: const SmartEditorSettings(
                  initialText:
                      '<p>Visit <a href="https://flutter.dev">Flutter</a> website</p>',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Select linked text "Flutter"
    controller.setSelection(0, 6, 13);
    await tester.pumpAndSettle();

    // Tooltip should be visible inside SingleChildScrollView
    expect(find.byTooltip('Open link'), findsOneWidget);

    // Scroll the SingleChildScrollView
    scrollController.jumpTo(50);
    await tester.pumpAndSettle();

    // Tooltip should be dismissed upon scrolling
    expect(find.byTooltip('Open link'), findsNothing);
  });
}
