import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_editor/flutter_smart_editor.dart';
import 'package:flutter_smart_editor/src/core/document/document_controller.dart';
import 'package:flutter_smart_editor/src/core/infra/html_parser.dart';
import 'package:flutter_smart_editor/src/core/infra/html_serializer.dart';
import 'package:flutter_smart_editor/src/widgets/blocks/image_block_widget.dart';

void main() {
  group('ImageNode model', () {
    test('creates with correct defaults and properties', () {
      final img = ImageNode(src: 'https://example.com/pic.jpg', alt: 'Test Photo');
      expect(img.src, 'https://example.com/pic.jpg');
      expect(img.alt, 'Test Photo');
      expect(img.alignment, SmartTextAlign.center);
      expect(img.blockType, BlockType.image);
      expect(img.tag, 'img');
      expect(img.plainText, 'Test Photo');
      expect(img.width, isNull);
      expect(img.height, isNull);
    });

    test('deepCopy preserves all attributes', () {
      final img = ImageNode(
        id: 'img_1',
        src: 'data:image/png;base64,abc',
        alt: 'Copy Test',
        width: 300,
        height: 200,
        caption: 'A caption',
        alignment: SmartTextAlign.right,
      );

      final copy = img.deepCopy() as ImageNode;
      expect(copy.id, img.id);
      expect(copy.src, img.src);
      expect(copy.alt, img.alt);
      expect(copy.width, 300);
      expect(copy.height, 200);
      expect(copy.caption, 'A caption');
      expect(copy.alignment, SmartTextAlign.right);
      expect(copy.plainText, 'Copy Test');
    });
  });

  group('ImageDocumentController', () {
    late DocumentController controller;

    setUp(() {
      controller = DocumentController(
        document: Document(blocks: [ParagraphNode(spans: [TextFormatSpan.plain('First paragraph')])]),
      );
    });

    test('insertImage inserts node and appends trailing paragraph at end', () {
      final idx = controller.insertImage(
        src: 'https://example.com/flower.png',
        alt: 'Flower',
        width: 400,
        alignment: SmartTextAlign.center,
      );

      expect(idx, 1);
      expect(controller.document.blocks.length, 3);
      expect(controller.document.blocks[1], isA<ImageNode>());
      expect(controller.document.blocks[2], isA<ParagraphNode>());

      final img = controller.getImageNode(1);
      expect(img, isNotNull);
      expect(img!.src, 'https://example.com/flower.png');
      expect(img.alt, 'Flower');
      expect(img.width, 400);
      expect(img.alignment, SmartTextAlign.center);
    });

    test('updateImage modifies properties correctly', () {
      controller.insertImage(src: 'https://example.com/orig.jpg');
      controller.updateImage(
        1,
        src: 'https://example.com/new.jpg',
        alt: 'New Alt',
        width: 250,
        height: 150,
        alignment: SmartTextAlign.left,
      );

      final img = controller.getImageNode(1)!;
      expect(img.src, 'https://example.com/new.jpg');
      expect(img.alt, 'New Alt');
      expect(img.width, 250);
      expect(img.height, 150);
      expect(img.alignment, SmartTextAlign.left);
    });

    test('setImageAlignment and setImageSize helper methods', () {
      controller.insertImage(src: 'https://example.com/pic.png');
      controller.setImageAlignment(1, SmartTextAlign.right);
      expect(controller.getImageNode(1)!.alignment, SmartTextAlign.right);

      controller.setImageSize(1, width: 500, height: 300);
      expect(controller.getImageNode(1)!.width, 500);
      expect(controller.getImageNode(1)!.height, 300);
    });

    test('removeImage deletes image block cleanly', () {
      controller.insertImage(src: 'https://example.com/pic.png');
      expect(controller.getImageNode(1), isNotNull);

      controller.removeImage(1);
      expect(controller.document.blocks.any((b) => b is ImageNode), isFalse);
    });

    test('insertImage and removeImage support atomic undo and redo', () {
      controller.insertImage(src: 'https://example.com/pic.png');
      expect(controller.document.blocks[1], isA<ImageNode>());

      // Undo insertion
      controller.undo();
      expect(controller.document.blocks.any((b) => b is ImageNode), isFalse);

      // Redo insertion
      controller.redo();
      expect(controller.document.blocks[1], isA<ImageNode>());
      expect((controller.document.blocks[1] as ImageNode).src, 'https://example.com/pic.png');
    });
  });

  group('HTML Serialization & Parsing for Images', () {
    test('SmartHtmlParser parses <img> tags into ImageNode', () {
      final parser = SmartHtmlParser();
      const html = '<p>Header</p><img src="https://example.com/cat.jpg" alt="A cute cat" width="300" height="200" /><p>Footer</p>';
      final doc = parser.parse(html);

      expect(doc.blocks.length, 3);
      expect(doc.blocks[1], isA<ImageNode>());
      final img = doc.blocks[1] as ImageNode;
      expect(img.src, 'https://example.com/cat.jpg');
      expect(img.alt, 'A cute cat');
      expect(img.width, 300);
      expect(img.height, 200);
    });

    test('SmartHtmlParser parses <p><img ...></p> correctly', () {
      final parser = SmartHtmlParser();
      const html = '<p style="text-align: center"><img src="https://example.com/logo.png" /></p>';
      final doc = parser.parse(html);

      expect(doc.blocks.length, 1);
      expect(doc.blocks[0], isA<ImageNode>());
      final img = doc.blocks[0] as ImageNode;
      expect(img.src, 'https://example.com/logo.png');
      expect(img.alignment, SmartTextAlign.center);
    });

    test('SmartHtmlSerializer outputs proper <img> tags', () {
      final serializer = SmartHtmlSerializer();
      final doc = Document(blocks: [
        ImageNode(
          src: 'https://example.com/pic.png',
          alt: 'Photo',
          width: 400,
          height: 300,
          alignment: SmartTextAlign.center,
        ),
      ]);

      final html = serializer.serialize(doc);
      expect(html, contains('<img src="https://example.com/pic.png"'));
      expect(html, contains('alt="Photo"'));
      expect(html, contains('width="400"'));
      expect(html, contains('height="300"'));
      expect(html, contains('margin-left: auto; margin-right: auto'));
    });
  });

  group('Toolbar Image Button & Interaction Widget Tests', () {
    testWidgets('SmartToolbar renders insert picture button when picture is true', (tester) async {
      final controller = SmartEditorController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartEditor(
              controller: controller,
              toolbarSettings: const SmartToolbarSettings(
                defaultButtons: [
                  SmartInsertButtons(
                    link: true,
                    picture: true,
                    table: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the picture button with Icons.image_outlined exists
      final pictureButtonFinder = find.byIcon(Icons.image_outlined);
      expect(pictureButtonFinder, findsOneWidget);

      // Verify tooltip
      final tooltipFinder = find.byTooltip('Insert Image');
      expect(tooltipFinder, findsOneWidget);
    });

    testWidgets('SmartToolbar does not render picture button when picture is false', (tester) async {
      final controller = SmartEditorController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartEditor(
              controller: controller,
              toolbarSettings: const SmartToolbarSettings(
                defaultButtons: [
                  SmartInsertButtons(
                    link: true,
                    picture: false,
                    table: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pictureButtonFinder = find.byIcon(Icons.image_outlined);
      expect(pictureButtonFinder, findsNothing);
    });

    testWidgets('Tapping image button opens ImageImportDialog', (tester) async {
      final controller = SmartEditorController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartEditor(
              controller: controller,
              toolbarSettings: const SmartToolbarSettings(
                defaultButtons: [
                  SmartInsertButtons(
                    picture: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the insert image button
      await tester.tap(find.byIcon(Icons.image_outlined));
      await tester.pumpAndSettle();

      // Verify that ImageImportDialog title/tabs appear
      expect(find.text('Insert Image'), findsWidgets);
      expect(find.text('From Web URL'), findsOneWidget);
      expect(find.text('From Device'), findsOneWidget);
    });

    testWidgets('Clicking uploaded image reveals Crop, Remove, Align, and Resize options', (tester) async {
      final controller = SmartEditorController();
      const testImageSrc =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
      controller.insertImage(
        src: testImageSrc,
        alt: 'Sample Image',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartEditor(
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the image block is rendered
      expect(find.byType(ImageBlockWidget), findsOneWidget);

      // Contextual action bar shouldn't be visible before clicking
      expect(find.text('Crop'), findsNothing);
      expect(find.byTooltip('Remove Image'), findsNothing);

      // Tap the image block to select it
      await tester.tap(find.byType(ImageBlockWidget));
      await tester.pumpAndSettle();

      // Contextual action bar should now be visible
      expect(find.text('Crop'), findsOneWidget);
      expect(find.byTooltip('Remove Image'), findsOneWidget);
      expect(find.byTooltip('Align Left'), findsOneWidget);
      expect(find.byTooltip('Align Center'), findsOneWidget);
      expect(find.byTooltip('Align Right'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);

      final imgIndex =
          controller.document.blocks.indexWhere((b) => b is ImageNode);
      expect(imgIndex, isNonNegative);

      // Tap Align Left
      await tester.tap(find.byTooltip('Align Left'));
      await tester.pumpAndSettle();
      expect(controller.getImageNode(imgIndex)?.alignment, SmartTextAlign.left);

      // Tap 50% resize pill
      await tester.tap(find.text('50%'));
      await tester.pumpAndSettle();
      expect(controller.getImageNode(imgIndex)?.width, 300);

      // Tap Remove Image button
      await tester.tap(find.byTooltip('Remove Image'));
      await tester.pumpAndSettle();

      // Image block should be removed
      expect(find.byType(ImageBlockWidget), findsNothing);
      expect(controller.document.blocks.any((b) => b is ImageNode), isFalse);
    });

    testWidgets('Image caption is rendered and Hide Options dismisses toolbar', (tester) async {
      final controller = SmartEditorController();
      const testImageSrc =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
      controller.insertImage(
        src: testImageSrc,
        alt: 'Sample Alt',
        caption: 'Figure 1: Test Caption Display',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartEditor(
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the caption text is rendered
      expect(find.text('Figure 1: Test Caption Display'), findsOneWidget);

      // Tap image to reveal options
      await tester.tap(find.byType(ImageBlockWidget));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hide Options'), findsOneWidget);

      // Tap Hide Options
      await tester.tap(find.byTooltip('Hide Options'));
      await tester.pumpAndSettle();

      // Contextual toolbar should be hidden
      expect(find.byTooltip('Hide Options'), findsNothing);
      expect(find.text('Crop'), findsNothing);
    });

    test('HTML serialization and parser preserves image caption', () {
      final serializer = SmartHtmlSerializer();
      final parser = SmartHtmlParser();

      final node = ImageNode(
        src: 'https://example.com/photo.png',
        alt: 'Accessible Photo',
        caption: 'Beautiful sunset view',
        alignment: SmartTextAlign.center,
      );

      final doc = Document(blocks: [node]);
      final html = serializer.serialize(doc);

      expect(html, contains('data-caption="Beautiful sunset view"'));
      expect(html, contains('alt="Accessible Photo"'));

      final parsedDoc = parser.parse(html);
      expect(parsedDoc.blocks.first, isA<ImageNode>());
      final parsedImg = parsedDoc.blocks.first as ImageNode;
      expect(parsedImg.caption, 'Beautiful sunset view');
      expect(parsedImg.alt, 'Accessible Photo');
    });

    testWidgets('Image block shows drag handle when BlockType.image is in draggableBlockTypes', (tester) async {
      final controller = SmartEditorController();
      controller.insertImage(
        src: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        alt: 'Test',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartEditor(
              controller: controller,
              editorSettings: const SmartEditorSettings(
                draggableBlockTypes: {BlockType.image},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
      expect(find.byType(ReorderableDragStartListener), findsOneWidget);
    });

    testWidgets('Image block does not show drag handle when BlockType.image is not in draggableBlockTypes', (tester) async {
      final controller = SmartEditorController();
      controller.insertImage(
        src: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        alt: 'Test',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartEditor(
              controller: controller,
              editorSettings: const SmartEditorSettings(
                draggableBlockTypes: {BlockType.heading1},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.drag_indicator), findsNothing);
      expect(find.byType(ReorderableDragStartListener), findsNothing);
    });
  });
}

