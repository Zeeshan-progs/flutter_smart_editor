import 'package:flutter/widgets.dart';
import '../../../models/enums.dart';
import '../../../models/nodes/image_node_model.dart';
import 'base_editor_state.dart';

/// Mixin managing image block selection, interactions, dimensions, alignment, and deletion.
mixin ImageEditorMixin on BaseEditorState {
  /// Index of the currently selected/focused image block in the document, or null if none.
  int? selectedImageBlockIndex;

  /// Whether the image at [blockIndex] is currently selected.
  bool isImageSelected(int blockIndex) => selectedImageBlockIndex == blockIndex;

  /// Selects the image block at [blockIndex].
  void selectImage(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    if (document.blocks[blockIndex] is! ImageNode) return;

    // Unfocus active text block cleanly to avoid viewport jump or scrolling to top
    FocusManager.instance.primaryFocus?.unfocus(
      disposition: UnfocusDisposition.previouslyFocusedChild,
    );

    safeSetState(() {
      selectedImageBlockIndex = blockIndex;
      focusedBlockIndex = blockIndex;
      toolbarRangeSelection = null;
      toolbarRangeBlockIndex = null;
    });
  }

  /// Deselects any currently selected image block.
  void deselectImage() {
    if (selectedImageBlockIndex != null) {
      safeSetState(() {
        selectedImageBlockIndex = null;
      });
    }
  }

  /// Toggles selection of an image block on tap.
  void onImageTap(int blockIndex) {
    if (selectedImageBlockIndex == blockIndex) {
      deselectImage();
    } else {
      selectImage(blockIndex);
    }
  }

  /// Removes the image block at [blockIndex] and clears active selection.
  void onImageRemove(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    docController.removeImage(blockIndex);
    if (selectedImageBlockIndex == blockIndex) {
      selectedImageBlockIndex = null;
    }
    rebuild();
  }

  /// Changes alignment of the image block at [blockIndex].
  void onImageAlignment(int blockIndex, SmartTextAlign alignment) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    docController.setImageAlignment(blockIndex, alignment);
    rebuild();
  }

  /// Resizes the image block at [blockIndex] with width and/or height.
  void onImageResize(int blockIndex, {double? width, double? height}) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    docController.setImageSize(blockIndex, width: width, height: height);
    rebuild();
  }

  /// Updates the image src at [blockIndex] with cropped image data.
  void onImageCrop(int blockIndex, String croppedSrc) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    docController.updateImage(blockIndex, src: croppedSrc);
    rebuild();
  }

  @override
  void onDocChanged() {
    super.onDocChanged();
    // Validate that selected image still exists
    if (selectedImageBlockIndex != null) {
      if (selectedImageBlockIndex! >= document.blocks.length ||
          document.blocks[selectedImageBlockIndex!] is! ImageNode) {
        selectedImageBlockIndex = null;
      }
    }
  }
}

/// Backwards-compatibility alias for [ImageEditorMixin].
typedef ImageEditorState = ImageEditorMixin;
