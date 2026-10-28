import 'package:flutter/material.dart';
import '../../models/editor_settings.dart';
import '../../models/enums.dart';
import '../../models/nodes/audio_node_model.dart';

/// Interactive widget representing an audio block in [SmartEditor].
///
/// If [AudioNode.builder] or [SmartEditorSettings.audioBuilder] is provided,
/// the custom player widget is rendered. Otherwise, a clean presentation card
/// is displayed.
class AudioBlockWidget extends StatefulWidget {
  const AudioBlockWidget({
    super.key,
    required this.audioNode,
    required this.blockIndex,
    required this.isSelected,
    this.editorSettings,
    this.isDarkMode = false,
    this.readOnly = false,
    this.showDragHandle = true,
    this.dragIndex,
    required this.onTap,
    required this.onRemove,
    this.onReplace,
    required this.onHideControls,
    this.onAlignmentChanged,
  });

  final AudioNode audioNode;
  final int blockIndex;
  final bool isSelected;
  final SmartEditorSettings? editorSettings;
  final bool isDarkMode;
  final bool readOnly;
  final bool showDragHandle;
  final int? dragIndex;

  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback? onReplace;
  final VoidCallback onHideControls;
  final ValueChanged<SmartTextAlign>? onAlignmentChanged;

  @override
  State<AudioBlockWidget> createState() => _AudioBlockWidgetState();
}

class _AudioBlockWidgetState extends State<AudioBlockWidget> {
  late final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Alignment _getAlignment(SmartTextAlign align) {
    switch (align) {
      case SmartTextAlign.left:
        return Alignment.centerLeft;
      case SmartTextAlign.center:
        return Alignment.center;
      case SmartTextAlign.right:
        return Alignment.centerRight;
      case SmartTextAlign.justify:
        return Alignment.center;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    final isBlockTypeDraggable = widget.editorSettings != null
        ? (widget.editorSettings!.draggableBlockTypes
                ?.contains(widget.audioNode.blockType) ??
            false)
        : widget.showDragHandle;
    final isDraggable = widget.showDragHandle && isBlockTypeDraggable;

    final bg = widget.isDarkMode ? const Color(0xFF1E232E) : Colors.white;
    final fg = widget.isDarkMode ? Colors.white : const Color(0xFF1E293B);
    final sub =
        widget.isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border =
        widget.isDarkMode ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0);

    final displayTitle = widget.audioNode.title?.isNotEmpty == true
        ? widget.audioNode.title!
        : (widget.audioNode.src.contains('/')
            ? widget.audioNode.src.split('/').last
            : 'Audio Track');

    final customBuilder =
        widget.audioNode.builder ?? widget.editorSettings?.audioBuilder;

    final audioContent = customBuilder != null
        ? customBuilder(context, widget.audioNode)
        : Container(
            constraints: const BoxConstraints(maxWidth: 480, minWidth: 260),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isSelected ? primaryColor : border,
                width: widget.isSelected ? 2.0 : 1.0,
              ),
              boxShadow: [
                if (widget.isSelected)
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.audiotrack_rounded,
                    color: Color(0xFF10B981),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.audioNode.author?.isNotEmpty == true
                            ? widget.audioNode.author!
                            : 'Audio attachment',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: sub,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

    final content = Focus(
      focusNode: _focusNode,
      canRequestFocus: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Audio Card ──
            Align(
              alignment: _getAlignment(widget.audioNode.alignment),
              child: GestureDetector(
                onTap: widget.readOnly
                    ? null
                    : () {
                        _focusNode.requestFocus();
                        widget.onTap();
                      },
                child: audioContent,
              ),
            ),

            // ── Contextual Action Toolbar ──
            if (widget.isSelected && !widget.readOnly) ...[
              const SizedBox(height: 8),
              Align(
                alignment: _getAlignment(widget.audioNode.alignment),
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(10),
                  color: widget.isDarkMode
                      ? const Color(0xFF2A2A2A)
                      : Colors.white,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.isDarkMode
                            ? Colors.white12
                            : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Remove Audio
                        IconButton(
                          tooltip: 'Remove Audio',
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.redAccent),
                          visualDensity: VisualDensity.compact,
                          onPressed: widget.onRemove,
                        ),
                        _buildMiniDivider(),

                        // Hide Toolbar
                        IconButton(
                          tooltip: 'Hide Options',
                          icon: const Icon(Icons.close, size: 18),
                          visualDensity: VisualDensity.compact,
                          onPressed: widget.onHideControls,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (!isDraggable) {
      return content;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          child: ReorderableDragStartListener(
            index: widget.dragIndex ?? widget.blockIndex,
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Icon(
                Icons.drag_indicator,
                size: 18,
                color: widget.isDarkMode ? Colors.white38 : Colors.black26,
              ),
            ),
          ),
        ),
        Expanded(child: content),
      ],
    );
  }

  Widget _buildMiniDivider() {
    return Container(
      width: 1,
      height: 20,
      color: widget.isDarkMode
          ? Colors.white12
          : Colors.black.withValues(alpha: 0.1),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
