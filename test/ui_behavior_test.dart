import 'package:flutter_smart_editor/smart_editor_controller.dart';
import 'package:flutter_smart_editor/src/models/editor_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_editor/smart_editor.dart';
import 'package:flutter_smart_editor/src/widgets/smart_editor_widget.dart';

void main() {
  testWidgets('Selecting text and toggling bold instantly updates UI',
      (WidgetTester tester) async {
    final controller = SmartEditorController();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SmartEditor(
          controller: controller,
          editorSettings: const SmartEditorSettings(
            initialText: '<p>Hello World</p>',
          ),
        ),
      ),
    ));

    await tester.pumpAndSettle();

    // Select "World"
    controller.documentController.toggleFormat(0, 6, 11, 'bold');
    tester
        .state<SmartEditorWidgetState>(find.byType(SmartEditorWidget))
        .rebuild();
    await tester.pumpAndSettle();

    // Check formatting directly in the document
    final spans = controller.document.blocks[0].spans;
    print('SPANS AFTER BOLD: $spans');
  });
}
