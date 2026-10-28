import 'package:flutter_smart_editor/src/core/document/document.dart';
import '../../../models/enums.dart';
import 'image_document_controller.dart';

/// Controller handling media (video, audio) and document/file block insertion, updates, and removal.
class AttachmentDocumentController extends ImageDocumentController {
  AttachmentDocumentController({
    super.document,
    super.undoRedoManager,
  });

  // ─── Video Operations ──────────────────────────────────────────

  /// Inserts a video block at or after [blockIndex].
  ///
  /// If [blockIndex] is null, appends the video at the end of the document.
  /// Also appends an empty paragraph if inserted at the end of the document.
  int insertVideo({
    required String src,
    String? caption,
    double? width,
    double? height,
    String? poster,
    SmartTextAlign alignment = SmartTextAlign.center,
    int? blockIndex,
  }) {
    saveState();

    final videoNode = VideoNode(
      src: src,
      caption: caption,
      width: width,
      height: height,
      poster: poster,
      alignment: alignment,
    );

    final targetIndex = blockIndex ?? document.blocks.length;
    final clampedIndex = targetIndex.clamp(0, document.blocks.length);

    document.blocks.insert(clampedIndex, videoNode);

    if (clampedIndex == document.blocks.length - 1) {
      document.blocks.add(ParagraphNode());
    }

    notifyChanged();
    return clampedIndex;
  }

  /// Updates properties on an existing [VideoNode] at [blockIndex].
  void updateVideo(
    int blockIndex, {
    String? src,
    String? caption,
    double? width,
    double? height,
    String? poster,
    SmartTextAlign? alignment,
  }) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! VideoNode) return;

    saveState();

    if (src != null) block.src = src;
    if (caption != null) {
      block.caption = caption;
      block.spans = [TextFormatSpan.plain(caption)];
    }
    if (width != null) block.width = width;
    if (height != null) block.height = height;
    if (poster != null) block.poster = poster;
    if (alignment != null) block.alignment = alignment;

    notifyChanged();
  }

  /// Removes the video at [blockIndex].
  void removeVideo(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! VideoNode) return;

    saveState();
    document.blocks.removeAt(blockIndex);
    if (document.blocks.isEmpty) {
      document.blocks.add(ParagraphNode());
    }
    notifyChanged();
  }

  /// Returns the [VideoNode] at [blockIndex], or null if not a video block.
  VideoNode? getVideoNode(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return null;
    final block = document.blocks[blockIndex];
    if (block is VideoNode) return block;
    return null;
  }

  // ─── Audio Operations ──────────────────────────────────────────

  /// Inserts an audio block at or after [blockIndex].
  int insertAudio({
    required String src,
    String? title,
    String? author,
    SmartTextAlign alignment = SmartTextAlign.left,
    int? blockIndex,
  }) {
    saveState();

    final audioNode = AudioNode(
      src: src,
      title: title,
      author: author,
      alignment: alignment,
    );

    final targetIndex = blockIndex ?? document.blocks.length;
    final clampedIndex = targetIndex.clamp(0, document.blocks.length);

    document.blocks.insert(clampedIndex, audioNode);

    if (clampedIndex == document.blocks.length - 1) {
      document.blocks.add(ParagraphNode());
    }

    notifyChanged();
    return clampedIndex;
  }

  /// Updates properties on an existing [AudioNode] at [blockIndex].
  void updateAudio(
    int blockIndex, {
    String? src,
    String? title,
    String? author,
    SmartTextAlign? alignment,
  }) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! AudioNode) return;

    saveState();

    if (src != null) block.src = src;
    if (title != null) {
      block.title = title;
      block.spans = [TextFormatSpan.plain(title)];
    }
    if (author != null) block.author = author;
    if (alignment != null) block.alignment = alignment;

    notifyChanged();
  }

  /// Removes the audio block at [blockIndex].
  void removeAudio(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! AudioNode) return;

    saveState();
    document.blocks.removeAt(blockIndex);
    if (document.blocks.isEmpty) {
      document.blocks.add(ParagraphNode());
    }
    notifyChanged();
  }

  /// Returns the [AudioNode] at [blockIndex], or null if not an audio block.
  AudioNode? getAudioNode(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return null;
    final block = document.blocks[blockIndex];
    if (block is AudioNode) return block;
    return null;
  }

  // ─── Document / File Operations ────────────────────────────────

  /// Inserts a document file attachment block at or after [blockIndex].
  int insertDocument({
    required String src,
    required String fileName,
    int? fileSize,
    String? fileExtension,
    SmartTextAlign alignment = SmartTextAlign.left,
    int? blockIndex,
  }) {
    saveState();

    final ext = fileExtension ?? (fileName.contains('.') ? fileName.split('.').last : null);
    final docNode = DocumentNode(
      src: src,
      fileName: fileName,
      fileSize: fileSize,
      fileExtension: ext,
      alignment: alignment,
    );

    final targetIndex = blockIndex ?? document.blocks.length;
    final clampedIndex = targetIndex.clamp(0, document.blocks.length);

    document.blocks.insert(clampedIndex, docNode);

    if (clampedIndex == document.blocks.length - 1) {
      document.blocks.add(ParagraphNode());
    }

    notifyChanged();
    return clampedIndex;
  }

  /// Updates properties on an existing [DocumentNode] at [blockIndex].
  void updateDocument(
    int blockIndex, {
    String? src,
    String? fileName,
    int? fileSize,
    String? fileExtension,
    SmartTextAlign? alignment,
  }) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! DocumentNode) return;

    saveState();

    if (src != null) block.src = src;
    if (fileName != null) {
      block.fileName = fileName;
      block.spans = [TextFormatSpan.plain(fileName)];
    }
    if (fileSize != null) block.fileSize = fileSize;
    if (fileExtension != null) block.fileExtension = fileExtension;
    if (alignment != null) block.alignment = alignment;

    notifyChanged();
  }

  /// Removes the document attachment block at [blockIndex].
  void removeDocument(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! DocumentNode) return;

    saveState();
    document.blocks.removeAt(blockIndex);
    if (document.blocks.isEmpty) {
      document.blocks.add(ParagraphNode());
    }
    notifyChanged();
  }

  /// Returns the [DocumentNode] at [blockIndex], or null if not a document block.
  DocumentNode? getDocumentNode(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return null;
    final block = document.blocks[blockIndex];
    if (block is DocumentNode) return block;
    return null;
  }
}
