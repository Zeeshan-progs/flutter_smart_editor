import 'package:flutter/material.dart';
import '../../../models/enums.dart';
import '../../../models/nodes/node_index.dart';
import '../../dialogs/smart_attachment_dialog.dart';
import 'base_editor_state.dart';

/// Mixin managing media block (image, video, audio, document) selection,
/// interactions, dimensions, alignment, and deletion.
mixin AttachmentEditorMixin on BaseEditorState {
  /// Index of the currently selected/focused image block in the document, or null if none.
  int? selectedImageBlockIndex;

  /// Index of the currently selected media block (video, audio, document), or null if none.
  int? selectedMediaBlockIndex;

  /// Whether the image at [blockIndex] is currently selected.
  bool isImageSelected(int blockIndex) => selectedImageBlockIndex == blockIndex;

  /// Whether the media/attachment at [blockIndex] is currently selected.
  bool isMediaSelected(int blockIndex) => selectedMediaBlockIndex == blockIndex;

  /// Selects the image block at [blockIndex].
  void selectImage(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    if (document.blocks[blockIndex] is! ImageNode) return;
    hideLinkTooltip();

    // Unfocus active text block cleanly to avoid viewport jump or scrolling to top
    FocusManager.instance.primaryFocus?.unfocus(
      disposition: UnfocusDisposition.previouslyFocusedChild,
    );

    safeSetState(() {
      selectedImageBlockIndex = blockIndex;
      selectedMediaBlockIndex = null;
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
    hideLinkTooltip();
    docController.removeImage(blockIndex);
    if (selectedImageBlockIndex == blockIndex) {
      selectedImageBlockIndex = null;
    }
    rebuild();
  }

  /// Changes alignment of the image block at [blockIndex].
  void onImageAlignment(int blockIndex, SmartTextAlign alignment) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    hideLinkTooltip();
    docController.setImageAlignment(blockIndex, alignment);
    rebuild();
  }

  /// Resizes the image block at [blockIndex] with width and/or height.
  void onImageResize(int blockIndex, {double? width, double? height}) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    hideLinkTooltip();
    docController.setImageSize(blockIndex, width: width, height: height);
    rebuild();
  }

  /// Updates the image src at [blockIndex] with cropped image data.
  void onImageCrop(int blockIndex, String croppedSrc) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    hideLinkTooltip();
    docController.updateImage(blockIndex, src: croppedSrc);
    rebuild();
  }

  // ─── Video, Audio & Document Block Operations ──────────────────

  /// Selects the media block at [blockIndex].
  void selectMedia(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    hideLinkTooltip();

    FocusManager.instance.primaryFocus?.unfocus(
      disposition: UnfocusDisposition.previouslyFocusedChild,
    );

    safeSetState(() {
      selectedMediaBlockIndex = blockIndex;
      selectedImageBlockIndex = null;
      focusedBlockIndex = blockIndex;
      toolbarRangeSelection = null;
      toolbarRangeBlockIndex = null;
    });
  }

  /// Deselects any currently selected media block.
  void deselectMedia() {
    if (selectedMediaBlockIndex != null) {
      safeSetState(() {
        selectedMediaBlockIndex = null;
      });
    }
  }

  /// Toggles selection of a media block on tap.
  void onMediaTap(int blockIndex) {
    if (selectedMediaBlockIndex == blockIndex) {
      deselectMedia();
    } else {
      selectMedia(blockIndex);
    }
  }

  /// Removes the video block at [blockIndex].
  void onVideoRemove(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    hideLinkTooltip();
    docController.removeVideo(blockIndex);
    if (selectedMediaBlockIndex == blockIndex) {
      selectedMediaBlockIndex = null;
    }
    rebuild();
  }

  /// Changes alignment of the video block at [blockIndex].
  void onVideoAlignment(int blockIndex, SmartTextAlign alignment) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    hideLinkTooltip();
    docController.updateVideo(blockIndex, alignment: alignment);
    rebuild();
  }

  /// Resizes the video block at [blockIndex].
  void onVideoResize(int blockIndex, {double? width, double? height}) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    hideLinkTooltip();
    docController.updateVideo(blockIndex, width: width, height: height);
    rebuild();
  }

  /// Removes the audio block at [blockIndex].
  void onAudioRemove(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    hideLinkTooltip();
    docController.removeAudio(blockIndex);
    if (selectedMediaBlockIndex == blockIndex) {
      selectedMediaBlockIndex = null;
    }
    rebuild();
  }

  /// Changes alignment of the audio block at [blockIndex].
  void onAudioAlignment(int blockIndex, SmartTextAlign alignment) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    hideLinkTooltip();
    docController.updateAudio(blockIndex, alignment: alignment);
    rebuild();
  }

  /// Removes the document attachment block at [blockIndex].
  void onDocumentRemove(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    hideLinkTooltip();
    docController.removeDocument(blockIndex);
    if (selectedMediaBlockIndex == blockIndex) {
      selectedMediaBlockIndex = null;
    }
    rebuild();
  }

  /// Changes alignment of the document attachment block at [blockIndex].
  void onDocumentAlignment(int blockIndex, SmartTextAlign alignment) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    hideLinkTooltip();
    docController.updateDocument(blockIndex, alignment: alignment);
    rebuild();
  }

  /// Opens attachment dialog to replace the video at [blockIndex] in-place.
  void onVideoReplace(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! VideoNode) return;

    final isDark = widget.editorSettings.darkMode ??
        (MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    SmartAttachmentDialog.show(
      context,
      type: SmartAttachmentType.video,
      isDarkMode: isDark,
      initialUrl: block.src,
      initialCaption: block.caption,
      onPickFromDevice: widget.controller?.videoPickerDelegate ??
          (widget.controller?.attachmentPickerDelegate != null
              ? () => widget.controller!
                  .attachmentPickerDelegate!(SmartAttachmentType.video)
              : null),
    ).then((data) {
      if (data != null && data.src.isNotEmpty) {
        docController.updateVideo(
          blockIndex,
          src: data.src,
          caption: data.caption ?? data.name,
        );
        deselectMedia();
        rebuild();
      }
    });
  }

  /// Opens attachment dialog to replace the audio at [blockIndex] in-place.
  void onAudioReplace(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! AudioNode) return;

    final isDark = widget.editorSettings.darkMode ??
        (MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    SmartAttachmentDialog.show(
      context,
      type: SmartAttachmentType.audio,
      isDarkMode: isDark,
      initialUrl: block.src,
      initialName: block.title,
      onPickFromDevice: widget.controller?.audioPickerDelegate ??
          (widget.controller?.attachmentPickerDelegate != null
              ? () => widget.controller!
                  .attachmentPickerDelegate!(SmartAttachmentType.audio)
              : null),
    ).then((data) {
      if (data != null && data.src.isNotEmpty) {
        docController.updateAudio(
          blockIndex,
          src: data.src,
          title: data.name ?? data.caption,
        );
        deselectMedia();
        rebuild();
      }
    });
  }

  /// Opens attachment dialog to replace the document at [blockIndex] in-place.
  void onDocumentReplace(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= document.blocks.length) return;
    final block = document.blocks[blockIndex];
    if (block is! DocumentNode) return;

    final isDark = widget.editorSettings.darkMode ??
        (MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    SmartAttachmentDialog.show(
      context,
      type: SmartAttachmentType.document,
      isDarkMode: isDark,
      initialUrl: block.src,
      initialName: block.fileName,
      onPickFromDevice: widget.controller?.filePickerDelegate ??
          (widget.controller?.attachmentPickerDelegate != null
              ? () => widget.controller!
                  .attachmentPickerDelegate!(SmartAttachmentType.document)
              : null),
    ).then((data) {
      if (data != null && data.src.isNotEmpty) {
        docController.updateDocument(
          blockIndex,
          src: data.src,
          fileName: data.name ?? 'Attachment',
          fileSize: data.fileSize,
          fileExtension: data.fileExtension,
        );
        deselectMedia();
        rebuild();
      }
    });
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
    // Validate that selected media still exists
    if (selectedMediaBlockIndex != null) {
      if (selectedMediaBlockIndex! >= document.blocks.length ||
          (document.blocks[selectedMediaBlockIndex!] is! VideoNode &&
              document.blocks[selectedMediaBlockIndex!] is! AudioNode &&
              document.blocks[selectedMediaBlockIndex!] is! DocumentNode)) {
        selectedMediaBlockIndex = null;
      }
    }
  }
}

/// Backwards-compatibility alias for [AttachmentEditorMixin].
typedef AttachmentEditorState = AttachmentEditorMixin;
