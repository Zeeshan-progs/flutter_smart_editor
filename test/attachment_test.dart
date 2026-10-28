import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_editor/flutter_smart_editor.dart';
import 'package:flutter_smart_editor/src/core/document/document_controller.dart';
import 'package:flutter_smart_editor/src/core/infra/html_parser.dart';
import 'package:flutter_smart_editor/src/core/infra/html_serializer.dart';
import 'package:flutter_smart_editor/src/widgets/editor/smart_editor_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Attachment Models', () {
    test('VideoNode creates with correct defaults and properties', () {
      final video =
          VideoNode(src: 'https://example.com/video.mp4', caption: 'Demo Clip');
      expect(video.src, 'https://example.com/video.mp4');
      expect(video.caption, 'Demo Clip');
      expect(video.alignment, SmartTextAlign.center);
      expect(video.blockType, BlockType.video);
      expect(video.tag, 'video');
      expect(video.controls, isTrue);
      expect(video.plainText, 'Demo Clip');
    });

    test('VideoNode deepCopy preserves all attributes', () {
      final video = VideoNode(
        id: 'vid_1',
        src: 'https://example.com/movie.mp4',
        caption: 'Action Movie',
        width: 640,
        height: 360,
        poster: 'https://example.com/thumb.jpg',
        controls: false,
        alignment: SmartTextAlign.right,
      );

      final copy = video.deepCopy() as VideoNode;
      expect(copy.id, video.id);
      expect(copy.src, video.src);
      expect(copy.caption, video.caption);
      expect(copy.width, 640);
      expect(copy.height, 360);
      expect(copy.poster, 'https://example.com/thumb.jpg');
      expect(copy.controls, isFalse);
      expect(copy.alignment, SmartTextAlign.right);
    });

    test('AudioNode creates with correct defaults and properties', () {
      final audio = AudioNode(
          src: 'https://example.com/sound.mp3',
          title: 'Theme Song',
          author: 'Composer');
      expect(audio.src, 'https://example.com/sound.mp3');
      expect(audio.title, 'Theme Song');
      expect(audio.author, 'Composer');
      expect(audio.blockType, BlockType.audio);
      expect(audio.tag, 'audio');
      expect(audio.controls, isTrue);
      expect(audio.alignment, SmartTextAlign.left);
      expect(audio.plainText, 'Theme Song');
    });

    test('AudioNode deepCopy preserves all attributes', () {
      final audio = AudioNode(
        id: 'aud_1',
        src: 'https://example.com/podcast.mp3',
        title: 'Episode 1',
        author: 'Host',
        controls: true,
        alignment: SmartTextAlign.center,
      );

      final copy = audio.deepCopy() as AudioNode;
      expect(copy.id, audio.id);
      expect(copy.src, audio.src);
      expect(copy.title, audio.title);
      expect(copy.author, audio.author);
      expect(copy.alignment, SmartTextAlign.center);
    });

    test(
        'VideoNode and AudioNode support custom builder and deepCopy preserves it',
        () {
      Widget customVideo(BuildContext context, VideoNode node) =>
          const Text('Custom Video Player');
      Widget customAudio(BuildContext context, AudioNode node) =>
          const Text('Custom Audio Player');

      final v = VideoNode(src: 'v.mp4', builder: customVideo);
      expect(v.builder, isNotNull);
      final vCopy = v.deepCopy() as VideoNode;
      expect(vCopy.builder, equals(customVideo));

      final a = AudioNode(src: 'a.mp3', builder: customAudio);
      expect(a.builder, isNotNull);
      final aCopy = a.deepCopy() as AudioNode;
      expect(aCopy.builder, equals(customAudio));
    });

    test('DocumentNode formattedSize formats properly', () {
      final doc1 =
          DocumentNode(src: 'file.pdf', fileName: 'guide.pdf', fileSize: 500);
      expect(doc1.formattedSize, '500 B');

      final doc2 = DocumentNode(
          src: 'file.pdf', fileName: 'guide.pdf', fileSize: 1024 * 512);
      expect(doc2.formattedSize, '512 KB');

      final doc3 = DocumentNode(
          src: 'file.pdf', fileName: 'guide.pdf', fileSize: 1024 * 1024 * 3);
      expect(doc3.formattedSize, '3 MB');
    });

    test('SmartAttachmentData getters and properties', () {
      const data = SmartAttachmentData(
        src: 'https://example.com/sheet.xlsx',
        type: SmartAttachmentType.document,
        name: 'budget.xlsx',
        sizeInBytes: 2048,
      );

      expect(data.src, 'https://example.com/sheet.xlsx');
      expect(data.type, SmartAttachmentType.document);
      expect(data.fileSize, 2048);
      expect(data.fileExtension, 'xlsx');
      expect(data.formattedSize, '2 KB');
    });
  });

  group('Attachment Operations & Undo/Redo', () {
    late DocumentController controller;

    setUp(() {
      controller = DocumentController(
        document: Document(blocks: [
          ParagraphNode(spans: [TextFormatSpan.plain('Header')])
        ]),
      );
    });

    test('insertVideo, update, remove, and undo/redo', () {
      expect(controller.document.blocks.length, 1);

      final idx = controller.insertVideo(
        src: 'https://example.com/v.mp4',
        caption: 'Nature',
        width: 500,
      );
      expect(idx, 1);
      expect(controller.document.blocks[1], isA<VideoNode>());
      final vNode = controller.getVideoNode(1);
      expect(vNode?.caption, 'Nature');
      expect(vNode?.width, 500);

      // Update
      controller.updateVideo(1,
          caption: 'Wildlife', width: 600, alignment: SmartTextAlign.right);
      expect(controller.getVideoNode(1)?.caption, 'Wildlife');
      expect(controller.getVideoNode(1)?.width, 600);
      expect(controller.getVideoNode(1)?.alignment, SmartTextAlign.right);

      // Undo update
      controller.undo();
      expect(controller.getVideoNode(1)?.caption, 'Nature');
      expect(controller.getVideoNode(1)?.width, 500);

      // Remove
      controller.removeVideo(1);
      expect(controller.getVideoNode(1), isNull);

      // Undo remove
      controller.undo();
      expect(controller.getVideoNode(1), isNotNull);
    });

    test('insertAudio, update, and remove', () {
      final idx = controller.insertAudio(
        src: 'https://example.com/a.mp3',
        title: 'Song',
        author: 'Artist',
      );
      expect(controller.document.blocks[idx], isA<AudioNode>());
      final aNode = controller.getAudioNode(idx);
      expect(aNode?.title, 'Song');
      expect(aNode?.author, 'Artist');

      controller.updateAudio(idx, title: 'Remix');
      expect(controller.getAudioNode(idx)?.title, 'Remix');

      controller.removeAudio(idx);
      expect(controller.getAudioNode(idx), isNull);
    });

    test('insertDocument, update, and remove', () {
      final idx = controller.insertDocument(
        src: 'https://example.com/report.pdf',
        fileName: 'report.pdf',
        fileSize: 1048576,
      );
      expect(controller.document.blocks[idx], isA<DocumentNode>());
      final dNode = controller.getDocumentNode(idx);
      expect(dNode?.fileName, 'report.pdf');
      expect(dNode?.fileSize, 1048576);
      expect(dNode?.fileExtension, 'pdf');

      controller.updateDocument(idx, fileName: 'final_report.pdf');
      expect(controller.getDocumentNode(idx)?.fileName, 'final_report.pdf');

      controller.removeDocument(idx);
      expect(controller.getDocumentNode(idx), isNull);
    });
  });

  group('HTML Serialization & Parsing for Attachments', () {
    final serializer = SmartHtmlSerializer();
    final parser = SmartHtmlParser();

    test('Video serialization and parsing roundtrip', () {
      final doc = Document(blocks: [
        VideoNode(
          src: 'https://example.com/stream.mp4',
          caption: 'Great Video',
          width: 640,
          height: 360,
          poster: 'https://example.com/p.jpg',
          alignment: SmartTextAlign.center,
        ),
      ]);

      final html = serializer.serialize(doc);
      expect(html, contains('<video'));
      expect(html, contains('src="https://example.com/stream.mp4"'));
      expect(html, contains('data-caption="Great Video"'));
      expect(html, contains('poster="https://example.com/p.jpg"'));
      expect(html, contains('width="640"'));

      final parsed = parser.parse(html);
      expect(parsed.blocks.first, isA<VideoNode>());
      final v = parsed.blocks.first as VideoNode;
      expect(v.src, 'https://example.com/stream.mp4');
      expect(v.caption, 'Great Video');
      expect(v.poster, 'https://example.com/p.jpg');
      expect(v.width, 640);
      expect(v.alignment, SmartTextAlign.center);
    });

    test('Audio serialization and parsing roundtrip', () {
      final doc = Document(blocks: [
        AudioNode(
          src: 'https://example.com/track.mp3',
          title: 'Podcast 12',
          author: 'Alex',
        ),
      ]);

      final html = serializer.serialize(doc);
      expect(html, contains('<audio'));
      expect(html, contains('src="https://example.com/track.mp3"'));
      expect(html, contains('data-title="Podcast 12"'));
      expect(html, contains('data-author="Alex"'));

      final parsed = parser.parse(html);
      expect(parsed.blocks.first, isA<AudioNode>());
      final a = parsed.blocks.first as AudioNode;
      expect(a.src, 'https://example.com/track.mp3');
      expect(a.title, 'Podcast 12');
      expect(a.author, 'Alex');
    });

    test('Document attachment serialization and parsing roundtrip', () {
      final doc = Document(blocks: [
        DocumentNode(
          src: 'https://example.com/whitepaper.pdf',
          fileName: 'whitepaper.pdf',
          fileSize: 2097152,
          fileExtension: 'pdf',
          alignment: SmartTextAlign.center,
        ),
      ]);

      final html = serializer.serialize(doc);
      expect(html, contains('<a'));
      expect(html, contains('href="https://example.com/whitepaper.pdf"'));
      expect(html, contains('download="whitepaper.pdf"'));
      expect(html, contains('data-attachment="document"'));
      expect(html, contains('data-file-size="2097152"'));
      expect(html, contains('whitepaper.pdf</a>'));

      final parsed = parser.parse(html);
      expect(parsed.blocks.first, isA<DocumentNode>());
      final d = parsed.blocks.first as DocumentNode;
      expect(d.src, 'https://example.com/whitepaper.pdf');
      expect(d.fileName, 'whitepaper.pdf');
      expect(d.fileSize, 2097152);
      expect(d.fileExtension, 'pdf');
      expect(d.alignment, SmartTextAlign.center);
    });
  });

  group('SmartInsertButtons Configuration', () {
    test('defaults to unified attachment button with all 4 types enabled', () {
      const buttons = SmartInsertButtons();
      expect(buttons.attachment, isTrue);
      expect(buttons.enabledAttachments, contains(SmartAttachmentType.image));
      expect(buttons.enabledAttachments, contains(SmartAttachmentType.video));
      expect(buttons.enabledAttachments, contains(SmartAttachmentType.audio));
      expect(
          buttons.enabledAttachments, contains(SmartAttachmentType.document));
    });

    test(
        'custom enabled attachments allows developer single or selected choices',
        () {
      const buttons = SmartInsertButtons(
        enabledAttachments: {
          SmartAttachmentType.video,
          SmartAttachmentType.audio
        },
      );
      expect(buttons.enabledAttachments.length, 2);
      expect(buttons.enabledAttachments.contains(SmartAttachmentType.image),
          isFalse);
      expect(buttons.enabledAttachments.contains(SmartAttachmentType.video),
          isTrue);
      expect(buttons.enabledAttachments.contains(SmartAttachmentType.audio),
          isTrue);
      expect(buttons.enabledAttachments.contains(SmartAttachmentType.document),
          isFalse);
    });
  });

  group('SmartEditorController Attachment APIs', () {
    test('insertVideo, insertAudio, insertDocument via controller', () {
      final controller = SmartEditorController();
      controller.setText('<p>Initial Text</p>');

      final vIdx = controller.insertVideo(
          src: 'https://test.com/vid.mp4', caption: 'Controller Test');
      expect(controller.getVideoNode(vIdx)?.caption, 'Controller Test');

      final aIdx = controller.insertAudio(
          src: 'https://test.com/aud.mp3', title: 'Audio 1');
      expect(controller.getAudioNode(aIdx)?.title, 'Audio 1');

      final dIdx = controller.insertDocument(
          src: 'https://test.com/file.docx', fileName: 'doc.docx');
      expect(controller.getDocumentNode(dIdx)?.fileName, 'doc.docx');
    });

    test('delegates can be configured on controller', () {
      final controller = SmartEditorController();
      expect(controller.videoPickerDelegate, isNull);
      expect(controller.audioPickerDelegate, isNull);
      expect(controller.filePickerDelegate, isNull);
      expect(controller.attachmentPickerDelegate, isNull);

      controller.videoPickerDelegate = () async => const SmartAttachmentData(
            src: 'local/video.mp4',
            type: SmartAttachmentType.video,
          );
      expect(controller.videoPickerDelegate, isNotNull);
    });
  });

  group('Audio and Video Custom Builders Widget Tests', () {
    testWidgets('AudioBlockWidget renders custom builder when provided',
        (tester) async {
      final audio = AudioNode(
        src: 'podcast.mp3',
        title: 'Episode 5',
        builder: (context, node) =>
            Text('Rendered Custom Audio: ${node.title}'),
      );
      final docController = DocumentController(
        document: Document(blocks: [audio]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartEditorWidget(documentController: docController),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rendered Custom Audio: Episode 5'), findsOneWidget);
    });

    testWidgets('VideoBlockWidget renders custom builder when provided',
        (tester) async {
      final video = VideoNode(
        src: 'clip.mp4',
        caption: 'Nature Clip',
        builder: (context, node) =>
            Text('Rendered Custom Video: ${node.caption}'),
      );
      final docController = DocumentController(
        document: Document(blocks: [video]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartEditorWidget(documentController: docController),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rendered Custom Video: Nature Clip'), findsOneWidget);
    });

    testWidgets(
        'SmartEditorSettings audioBuilder and videoBuilder apply globally',
        (tester) async {
      final audio = AudioNode(src: 'global_aud.mp3', title: 'Global Audio');
      final video = VideoNode(src: 'global_vid.mp4', caption: 'Global Video');
      final docController = DocumentController(
        document: Document(blocks: [audio, video]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartEditorWidget(
              documentController: docController,
              editorSettings: SmartEditorSettings(
                audioBuilder: (context, node) =>
                    Text('Global Audio Player: ${node.title}'),
                videoBuilder: (context, node) =>
                    Text('Global Video Player: ${node.caption}'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Global Audio Player: Global Audio'), findsOneWidget);
      expect(find.text('Global Video Player: Global Video'), findsOneWidget);
    });
  });
}
