import 'package:flutter/material.dart';
import '../../models/editor_settings.dart';
import '../../models/enums.dart';
import '../../models/nodes/video_node_model.dart';

/// Interactive widget representing a video block in [SmartEditor].
///
/// If [VideoNode.builder] or [SmartEditorSettings.videoBuilder] is provided,
/// the custom video player widget is rendered. Otherwise, a clean presentation
/// preview card is displayed.
class VideoBlockWidget extends StatefulWidget {
  const VideoBlockWidget({
    super.key,
    required this.videoNode,
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
    this.onResize,
  });

  final VideoNode videoNode;
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
  final void Function(double? width, double? height)? onResize;

  @override
  State<VideoBlockWidget> createState() => _VideoBlockWidgetState();
}

class _VideoBlockWidgetState extends State<VideoBlockWidget> {
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
                ?.contains(widget.videoNode.blockType) ??
            false)
        : widget.showDragHandle;
    final isDraggable = widget.showDragHandle && isBlockTypeDraggable;

    final customBuilder =
        widget.videoNode.builder ?? widget.editorSettings?.videoBuilder;

    final videoContent = customBuilder != null
        ? customBuilder(context, widget.videoNode)
        : Container(
            width: widget.videoNode.width ?? 480,
            height: widget.videoNode.height ?? 270,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isSelected
                    ? primaryColor
                    : (widget.isDarkMode
                        ? const Color(0xFF2E384D)
                        : const Color(0xFFE2E8F0)),
                width: widget.isSelected ? 2.5 : 1.0,
              ),
              boxShadow: [
                if (widget.isSelected)
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Poster or Default Backdrop
                  if (widget.videoNode.poster != null &&
                      widget.videoNode.poster!.isNotEmpty)
                    Positioned.fill(
                      child: Image.network(
                        widget.videoNode.poster!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _buildDefaultVideoBackdrop(),
                      ),
                    )
                  else
                    _buildDefaultVideoBackdrop(),

                  // Center Play Badge
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.65),
                      border: Border.all(color: Colors.white38, width: 2),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),

                  // Top Video Badge
                  Positioned(
                    top: 10,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.videocam,
                              size: 13, color: Color(0xFFF43F5E)),
                          SizedBox(width: 4),
                          Text(
                            'VIDEO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
            // ── Video Card ──
            Align(
              alignment: _getAlignment(widget.videoNode.alignment),
              child: GestureDetector(
                onTap: widget.readOnly
                    ? null
                    : () {
                        _focusNode.requestFocus();
                        widget.onTap();
                      },
                child: videoContent,
              ),
            ),

            // ── Optional Caption ──
            if (widget.videoNode.caption != null &&
                widget.videoNode.caption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  widget.videoNode.caption!,
                  textAlign: widget.videoNode.alignment == SmartTextAlign.center
                      ? TextAlign.center
                      : (widget.videoNode.alignment == SmartTextAlign.right
                          ? TextAlign.right
                          : TextAlign.left),
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    color: widget.isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),

            // ── Contextual Action Toolbar ──
            if (widget.isSelected && !widget.readOnly) ...[
              const SizedBox(height: 8),
              Align(
                alignment: _getAlignment(widget.videoNode.alignment),
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
                        // Remove Video
                        IconButton(
                          tooltip: 'Remove Video',
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

  Widget _buildDefaultVideoBackdrop() {
    return Container(
      color: const Color(0xFF1E293B),
      child: Center(
        child: Icon(
          Icons.movie_creation_outlined,
          size: 48,
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
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
