import 'package:flutter/widgets.dart';
import '../enums.dart';
import 'toolbar_group.dart';

/// Insert buttons (Link, Attachment, Table, etc.)
class SmartInsertButtons extends SmartToolbarGroup {
  final bool link;
  final bool table;

  /// Whether to display the common attachment button which opens a bottom sheet
  /// allowing users to insert image, video, audio, or document files.
  final bool attachment;

  /// The set of attachment types available in the bottom sheet.
  /// Defaults to all options: image, video, audio, document.
  final Set<SmartAttachmentType> enabledAttachments;

  /// Optional custom icon for the attachment button (defaults to `Icons.attach_file`).
  final IconData? attachmentIcon;

  const SmartInsertButtons({
    this.link = true,
    this.table = true,
    this.attachment = true,
    this.enabledAttachments = const {
      SmartAttachmentType.image,
      SmartAttachmentType.video,
      SmartAttachmentType.audio,
      SmartAttachmentType.document,
    },
    this.attachmentIcon,
  });
}
