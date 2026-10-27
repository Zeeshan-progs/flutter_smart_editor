import 'package:flutter/material.dart';
import 'package:flutter_smart_editor/smart_editor.dart';
import 'package:flutter_smart_editor/smart_editor_controller.dart';
import 'package:flutter_smart_editor/src/models/enums.dart';
import 'package:flutter_smart_editor/src/models/toolbar_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'SmartToolbarType.expandable shows 1 toolbar at a time with toggle button',
      (WidgetTester tester) async {
    final controller = SmartEditorController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartEditor(
            controller: controller,
            toolbarSettings: const SmartToolbarSettings(
              toolbarType: SmartToolbarType.expandable,
              initiallyExpanded: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // When collapsed: exactly 1 SingleChildScrollView, 0 Wrap, expand button present
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byType(Wrap), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);

    // Tap to expand
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pumpAndSettle();

    // When expanded: exactly 1 Wrap, 0 SingleChildScrollView (only 1 toolbar, not 2!)
    expect(find.byType(Wrap), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    // No dangling or empty separators in expanded mode
    expect(find.byType(VerticalDivider), findsNothing);

    // Tap to shrink back
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
    await tester.pumpAndSettle();

    // Collapsed again
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byType(Wrap), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
  });
}
