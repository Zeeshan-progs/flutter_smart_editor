import 'package:flutter/widgets.dart';
import '../../core/document/document.dart';
import '../enums.dart';

/// Builder signature for custom video players.
typedef VideoNodeBuilder = Widget Function(
    BuildContext context, VideoNode node);

/// A video block (`<video>`).
///
/// Supports network URLs, local video paths, or stream links.
/// Can be resized, aligned, and captioned.
/// A custom player widget can be supplied via [builder].
class VideoNode extends BlockNode {
  String src;
  String? caption;
  double? width;
  double? height;
  String? poster;
  bool controls;
  VideoNodeBuilder? builder;

  VideoNode({
    super.id,
    required this.src,
    this.caption,
    this.width,
    this.height,
    this.poster,
    this.controls = true,
    this.builder,
    super.alignment = SmartTextAlign.center,
  }) : super(spans: [TextFormatSpan.plain(caption ?? '')]);

  @override
  String get tag => 'video';

  @override
  BlockType get blockType => BlockType.video;

  @override
  String get plainText =>
      caption?.isNotEmpty == true ? caption! : '[Video: $src]';

  @override
  BlockNode deepCopy() => VideoNode(
        id: id,
        src: src,
        caption: caption,
        width: width,
        height: height,
        poster: poster,
        controls: controls,
        builder: builder,
        alignment: alignment,
      );

  @override
  String toString() =>
      'VideoNode(src: $src, caption: $caption, width: $width, height: $height, alignment: $alignment)';
}
