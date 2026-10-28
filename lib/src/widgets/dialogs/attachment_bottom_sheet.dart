import 'package:flutter/material.dart';
import '../../models/enums.dart';

/// Modal bottom sheet allowing users to choose an attachment type (Image, Video, Audio, Document).
class SmartAttachmentBottomSheet extends StatelessWidget {
  final Set<SmartAttachmentType> enabledAttachments;
  final bool isDarkMode;
  final ValueChanged<SmartAttachmentType> onSelect;

  const SmartAttachmentBottomSheet({
    super.key,
    required this.enabledAttachments,
    required this.isDarkMode,
    required this.onSelect,
  });

  static Future<SmartAttachmentType?> show(
    BuildContext context, {
    required Set<SmartAttachmentType> enabledAttachments,
    required bool isDarkMode,
  }) {
    return showModalBottomSheet<SmartAttachmentType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SmartAttachmentBottomSheet(
        enabledAttachments: enabledAttachments,
        isDarkMode: isDarkMode,
        onSelect: (type) => Navigator.of(ctx).pop(type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? const Color(0xFF1E232E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1E293B);
    final subtextColor =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg =
        isDarkMode ? const Color(0xFF131722) : const Color(0xFFF8FAFC);
    final borderColor =
        isDarkMode ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0);

    final items = <_AttachmentItemConfig>[];

    if (enabledAttachments.contains(SmartAttachmentType.image)) {
      items.add(_AttachmentItemConfig(
        type: SmartAttachmentType.image,
        icon: Icons.image_outlined,
        color: const Color(0xFF38BDF8),
        title: 'Image',
        subtitle: 'Photo, gallery or URL',
      ));
    }

    if (enabledAttachments.contains(SmartAttachmentType.video)) {
      items.add(_AttachmentItemConfig(
        type: SmartAttachmentType.video,
        icon: Icons.videocam_outlined,
        color: const Color(0xFFF43F5E),
        title: 'Video',
        subtitle: 'MP4, stream or link',
      ));
    }

    if (enabledAttachments.contains(SmartAttachmentType.audio)) {
      items.add(_AttachmentItemConfig(
        type: SmartAttachmentType.audio,
        icon: Icons.audiotrack_outlined,
        color: const Color(0xFF10B981),
        title: 'Audio',
        subtitle: 'Podcast, voice or MP3',
      ));
    }

    if (enabledAttachments.contains(SmartAttachmentType.document)) {
      items.add(_AttachmentItemConfig(
        type: SmartAttachmentType.document,
        icon: Icons.description_outlined,
        color: const Color(0xFFA855F7),
        title: 'Document',
        subtitle: 'PDF, Word or other files',
      ));
    }

    return Container(
      // margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.5 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle indicator
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Insert Attachment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: subtextColor, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Grid of options
            ListView.separated(
              separatorBuilder: (context, index) {
                return const SizedBox(height: 12);
              },
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              // gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              //   crossAxisCount: 2,
              //   crossAxisSpacing: 12,
              //   mainAxisSpacing: 12,
              //   childAspectRatio: 1.8,
              // ),
              itemCount: items.length,
              itemBuilder: (ctx, index) {
                final item = items[index];
                return InkWell(
                  onTap: () => onSelect(item.type),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(item.icon, color: item.color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.subtitle,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: subtextColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentItemConfig {
  final SmartAttachmentType type;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  _AttachmentItemConfig({
    required this.type,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}
