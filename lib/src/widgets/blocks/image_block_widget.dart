import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/editor_settings.dart';
import '../../models/enums.dart';
import '../../models/nodes/image_node_model.dart';
import '../cropper/smart_image_cropper.dart';

/// Interactive widget representing an image block in [SmartEditor].
///
/// Supports:
/// - Tap to select / deselect.
/// - Highlight border when selected.
/// - Contextual floating bar with **✂️ Crop**, **🗑️ Remove**, **↔️ Align**, and **📐 Resize**.
/// - Both remote URLs and base64 Data URLs.
class ImageBlockWidget extends StatefulWidget {
  const ImageBlockWidget({
    super.key,
    required this.imageNode,
    required this.blockIndex,
    required this.isSelected,
    this.editorSettings,
    this.isDarkMode = false,
    this.readOnly = false,
    this.showDragHandle = true,
    this.dragIndex,
    required this.onTap,
    required this.onRemove,
    required this.onAlignmentChanged,
    required this.onResize,
    required this.onCrop,
    required this.onHideResizeHandles,
  });

  final ImageNode imageNode;
  final int blockIndex;
  final bool isSelected;
  final SmartEditorSettings? editorSettings;
  final bool isDarkMode;
  final bool readOnly;
  final bool showDragHandle;
  final int? dragIndex;

  final VoidCallback onTap;
  final VoidCallback onRemove;
  final ValueChanged<SmartTextAlign> onAlignmentChanged;
  final void Function(double? width, double? height) onResize;
  final ValueChanged<String> onCrop;
  final VoidCallback onHideResizeHandles;

  @override
  State<ImageBlockWidget> createState() => _ImageBlockWidgetState();
}

class _ImageBlockWidgetState extends State<ImageBlockWidget> {
  late final FocusNode _focusNode = FocusNode();
  ImageProvider? _imageProvider;

  /// Tracks the src that was used to build the current [_imageProvider].
  /// Needed because [ImageNode] is mutated in-place, so
  /// `oldWidget.imageNode.src == widget.imageNode.src` is always true
  /// inside [didUpdateWidget].
  String _lastResolvedSrc = '';

  @override
  void initState() {
    super.initState();
    _initImageProvider();
  }

  @override
  void didUpdateWidget(covariant ImageBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_lastResolvedSrc != widget.imageNode.src) {
      _initImageProvider();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _initImageProvider() {
    final src = widget.imageNode.src;
    _lastResolvedSrc = src;

    if (src.startsWith('data:image')) {
      try {
        final commaIdx = src.indexOf(',');
        final base64Str = commaIdx != -1 ? src.substring(commaIdx + 1) : src;
        final bytes = base64Decode(base64Str.replaceAll(RegExp(r'\s+'), ''));
        _imageProvider = MemoryImage(bytes);
      } catch (_) {
        _imageProvider = null;
      }
    } else if (src.startsWith('http://') || src.startsWith('https://')) {
      _imageProvider = NetworkImage(src);
    } else if (src.startsWith('file://')) {
      _imageProvider = FileImage(File(src.replaceFirst('file://', '')));
    } else if (src.isNotEmpty && !src.contains('://')) {
      _imageProvider = FileImage(File(src));
    } else {
      _imageProvider = null;
    }
  }

  Future<void> _handleCrop(BuildContext context) async {
    final croppedResult = await SmartImageCropper.show(
      context,
      imageSrc: widget.imageNode.src,
      isDarkMode: widget.isDarkMode,
    );

    if (croppedResult != null && croppedResult.isNotEmpty) {
      widget.onCrop(croppedResult);
    }
  }

  Widget _buildImage() {
    if (_imageProvider == null) {
      return _errorPlaceholder();
    }

    return Image(
      image: _imageProvider!,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => _errorPlaceholder(),
    );
  }

  Widget _errorPlaceholder() {
    final theme = Theme.of(context);
    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isDarkMode ? Colors.white24 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined,
              size: 40, color: theme.colorScheme.error),
          const SizedBox(height: 8),
          Text(
            'Image could not be loaded',
            style: TextStyle(
              fontSize: 13,
              color: widget.isDarkMode ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
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
                ?.contains(widget.imageNode.blockType) ??
            false)
        : widget.showDragHandle;
    final isDraggable = widget.showDragHandle && isBlockTypeDraggable;

    final content = Focus(
      focusNode: _focusNode,
      canRequestFocus: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image Display Container ──
            Align(
              alignment: _getAlignment(widget.imageNode.alignment),
              child: GestureDetector(
                onTap: widget.readOnly
                    ? null
                    : () {
                        _focusNode.requestFocus();
                        widget.onTap();
                      },
                child: Container(
                  width: widget.imageNode.width,
                  height: widget.imageNode.height,
                  constraints: const BoxConstraints(
                    maxWidth: double.infinity,
                    minWidth: 80,
                    minHeight: 60,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          widget.isSelected ? primaryColor : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: widget.isSelected
                        ? [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: _buildImage(),
                  ),
                ),
              ),
            ),

            // ── Optional Caption ──
            if (widget.imageNode.caption != null &&
                widget.imageNode.caption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  widget.imageNode.caption!,
                  textAlign: widget.imageNode.alignment == SmartTextAlign.center
                      ? TextAlign.center
                      : (widget.imageNode.alignment == SmartTextAlign.right
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

            // ── Contextual Action Toolbar (Appears on click/selection) ──
            if (widget.isSelected && !widget.readOnly) ...[
              const SizedBox(height: 8),
              Align(
                alignment: _getAlignment(widget.imageNode.alignment),
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
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        // ── Crop Button ──
                        TextButton.icon(
                          icon: const Icon(Icons.crop, size: 16),
                          label: const Text('Crop',
                              style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _handleCrop(context),
                        ),

                        // ── Divider ──
                        _buildMiniDivider(),

                        // ── Align Left ──
                        IconButton(
                          tooltip: 'Align Left',
                          icon: Icon(
                            Icons.format_align_left,
                            size: 16,
                            color: widget.imageNode.alignment ==
                                    SmartTextAlign.left
                                ? primaryColor
                                : null,
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              widget.onAlignmentChanged(SmartTextAlign.left),
                        ),

                        // ── Align Center ──
                        IconButton(
                          tooltip: 'Align Center',
                          icon: Icon(
                            Icons.format_align_center,
                            size: 16,
                            color: widget.imageNode.alignment ==
                                    SmartTextAlign.center
                                ? primaryColor
                                : null,
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              widget.onAlignmentChanged(SmartTextAlign.center),
                        ),

                        // ── Align Right ──
                        IconButton(
                          tooltip: 'Align Right',
                          icon: Icon(
                            Icons.format_align_right,
                            size: 16,
                            color: widget.imageNode.alignment ==
                                    SmartTextAlign.right
                                ? primaryColor
                                : null,
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              widget.onAlignmentChanged(SmartTextAlign.right),
                        ),

                        // ── Divider ──
                        _buildMiniDivider(),

                        // ── Quick Size Presets ──
                        _buildSizePill('25%', 150),
                        _buildSizePill('50%', 300),
                        _buildSizePill('100%', null),

                        // ── Divider ──
                        _buildMiniDivider(),

                        // ── Remove Button ──
                        IconButton(
                          tooltip: 'Remove Image',
                          icon: const Icon(Icons.delete_outline,
                              size: 16, color: Colors.redAccent),
                          visualDensity: VisualDensity.compact,
                          onPressed: widget.onRemove,
                        ),

                        // ── Divider ──
                        _buildMiniDivider(),

                        // ── Hide Toolbar / Deselect ──
                        IconButton(
                          tooltip: 'Hide Options',
                          icon: const Icon(Icons.close, size: 16),
                          visualDensity: VisualDensity.compact,
                          onPressed: widget.onHideResizeHandles,
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

  Widget _buildSizePill(String label, double? width) {
    final isCurrent = (width == null && widget.imageNode.width == null) ||
        (width != null && widget.imageNode.width == width);
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => widget.onResize(width, null),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isCurrent
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isCurrent
                ? theme.colorScheme.primary
                : (widget.isDarkMode ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }
}
