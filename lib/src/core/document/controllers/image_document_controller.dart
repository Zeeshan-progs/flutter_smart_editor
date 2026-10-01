import 'package:flutter_smart_editor/src/core/document/document.dart';
import '../../../models/enums.dart';
import 'table_document_controller.dart';

/// Controller handling image block insertion, updates, dimension changes, alignment, and deletion.
class ImageDocumentController extends TableDocumentController {
  ImageDocumentController({
    super.document,
    super.undoRedoManager,
  });

  // ─── Image Operations ──────────────────────────────────────────

  /// Inserts an image block at or after [blockIndex].
  ///
  /// If [blockIndex] is null, appends the image at the end of the document.
  /// Also appends an empty paragraph after the image if it is at the end of
  /// the document, so the user can continue typing below it.
  /// Returns the index of the inserted [ImageNode].
  int insertImage({
    required String src,
    String? alt,
    double? width,
    double? height,
    String? caption,
    SmartTextAlign alignment = SmartTextAlign.center,
    int? blockIndex,
  }) {
    saveState();

    final imageNode = ImageNode(
      src: src,
      alt: alt,
      width: width,
      height: height,
      caption: caption,
      alignment: alignment,
    );

    final targetIndex = blockIndex ?? document.blocks.length;
    final clampedIndex = targetIndex.clamp(0, document.blocks.length);

    document.blocks.insert(clampedIndex, imageNode);

    // If inserted at the end of the document, append an empty paragraph
    if (clampedIndex == document.blocks.length - 1) {
      document.blocks.add(ParagraphNode());
    }

    notifyChanged();
    return clampedIndex;
  }

  /// Updates properties on an existing [ImageNode] at [blockIndex].
  void updateImage(
    int blockIndex, {
    String? src,
    String? alt,
    double? width,
    double? height,
    String? caption,
    SmartTextAlign? alignment,
  }) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! ImageNode) return;

    saveState();

    if (src != null) block.src = src;
    if (alt != null) {
      block.alt = alt;
      block.spans = [TextFormatSpan.plain(alt)];
    }
    if (width != null) block.width = width;
    if (height != null) block.height = height;
    if (caption != null) block.caption = caption;
    if (alignment != null) block.alignment = alignment;

    notifyChanged();
  }

  /// Sets alignment of the image at [blockIndex].
  void setImageAlignment(int blockIndex, SmartTextAlign alignment) {
    updateImage(blockIndex, alignment: alignment);
  }

  /// Sets dimensions of the image at [blockIndex].
  void setImageSize(int blockIndex, {double? width, double? height}) {
    updateImage(blockIndex, width: width, height: height);
  }

  /// Removes the image at [blockIndex].
  void removeImage(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! ImageNode) return;

    saveState();
    document.blocks.removeAt(blockIndex);
    if (document.blocks.isEmpty) {
      document.blocks.add(ParagraphNode());
    }
    notifyChanged();
  }

  /// Returns the [ImageNode] at [blockIndex], or null if not an image block.
  ImageNode? getImageNode(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return null;
    final block = document.blocks[blockIndex];
    if (block is ImageNode) return block;
    return null;
  }
}
