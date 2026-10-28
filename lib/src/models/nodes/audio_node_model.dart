import 'package:flutter/widgets.dart';
import '../../core/document/document.dart';
import '../enums.dart';

/// Builder signature for custom audio players.
typedef AudioNodeBuilder = Widget Function(
    BuildContext context, AudioNode node);

/// An audio block (`<audio>`).
///
/// Supports network audio URLs or local audio file paths.
/// A custom player widget can be supplied via [builder].
class AudioNode extends BlockNode {
  String src;
  String? title;
  String? author;
  bool controls;
  AudioNodeBuilder? builder;

  AudioNode({
    super.id,
    required this.src,
    this.title,
    this.author,
    this.controls = true,
    this.builder,
    super.alignment = SmartTextAlign.left,
  }) : super(spans: [TextFormatSpan.plain(title ?? '')]);

  @override
  String get tag => 'audio';

  @override
  BlockType get blockType => BlockType.audio;

  @override
  String get plainText => title?.isNotEmpty == true ? title! : '[Audio: $src]';

  @override
  BlockNode deepCopy() => AudioNode(
        id: id,
        src: src,
        title: title,
        author: author,
        controls: controls,
        builder: builder,
        alignment: alignment,
      );

  @override
  String toString() =>
      'AudioNode(src: $src, title: $title, author: $author, alignment: $alignment)';
}
