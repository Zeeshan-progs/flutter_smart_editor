import 'package:flutter/material.dart';
import 'package:flutter_smart_editor/flutter_smart_editor.dart';

void main() => runApp(const SmartEditorExampleApp());

class SmartEditorExampleApp extends StatelessWidget {
  const SmartEditorExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Editor Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const EditorDemoPage(),
    );
  }
}

class EditorDemoPage extends StatefulWidget {
  const EditorDemoPage({super.key});

  @override
  State<EditorDemoPage> createState() => _EditorDemoPageState();
}

class _EditorDemoPageState extends State<EditorDemoPage> {
  final SmartEditorController controller = SmartEditorController();
  String _htmlOutput = '';

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Smart Editor'),
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── The Editor ─────────────────────────────────────
            SmartEditor(
              controller: controller,
              editorSettings: const SmartEditorSettings(
                hint: 'Start typing here...',
                initialText: '<p>Welcome to <b>Flutter Smart Editor</b>!</p>'
                    '<h2>A Pure Flutter Editor</h2>'
                    '<p>No WebView. No JavaScript. Just <i>Dart and Flutter</i>.</p>',
              ),
              toolbarSettings: const SmartToolbarSettings(
                toolbarPosition: SmartToolbarPosition.above,
                toolbarType: SmartToolbarType.scrollable,
                showBorder: true,
                defaultButtons: [
                  SmartStyleButtons(),
                  SmartFontButtons(
                    bold: true,
                    italic: true,
                    underline: true,
                    strikethrough: true,
                    clearAll: false,
                    superscript: false,
                    subscript: false,
                  ),
                  SmartOtherButtons(
                    undo: true,
                    redo: true,
                    fullscreen: false,
                    codeview: false,
                    help: false,
                    copy: false,
                    paste: false,
                  ),
                ],
              ),
              scrollSettings: const SmartScrollSettings(
                autoAdjustHeight: true,
                maxHeight: 140,
              ),
              selectionSettings: const SmartSelectionSettings(
                cursorWidth: 2.0,
              ),
              styleSettings: SmartStyleSettings(
                height: 400,
                editorPadding: const EdgeInsets.all(16),
                borderRadius: BorderRadius.circular(12),
              ),
              callbacks: SmartEditorCallbacks(
                onInit: () {
                  debugPrint('Editor initialized!');
                },
                onChangeContent: (html) {
                  debugPrint('Content changed: $html');
                },
                onFocus: () {
                  debugPrint('Editor focused');
                },
                onBlur: () {
                  debugPrint('Editor blurred');
                },
              ),
            ),

            const SizedBox(height: 16),

            // ─── Control Buttons Row 1: Content ─────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.code, size: 18),
                  label: const Text('Get HTML'),
                  onPressed: () async {
                    final html = await controller.getText();
                    setState(() {
                      _htmlOutput = html;
                    });
                  },
                ),
                FilledButton.tonal(
                  onPressed: () {
                    controller.setText(
                      '<h1>Reset Content</h1>'
                      '<p>The editor content has been <u>replaced</u>.</p>',
                    );
                  },
                  child: const Text('Set HTML'),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    controller.insertText(' [inserted text] ');
                  },
                  child: const Text('Insert Text'),
                ),
                OutlinedButton(
                  onPressed: () {
                    controller.clear();
                    setState(() {
                      _htmlOutput = '';
                    });
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ─── Control Buttons Row 2: Undo/Redo ───────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('Undo'),
                  onPressed: () => controller.undo(),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.redo, size: 18),
                  label: const Text('Redo'),
                  onPressed: () => controller.redo(),
                ),
                OutlinedButton(
                  onPressed: () => controller.disable(),
                  child: const Text('Disable'),
                ),
                FilledButton.tonal(
                  onPressed: () => controller.enable(),
                  child: const Text('Enable'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ─── HTML Output ────────────────────────────────────
            if (_htmlOutput.isNotEmpty) ...[
              Text(
                'HTML Output:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _htmlOutput,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
