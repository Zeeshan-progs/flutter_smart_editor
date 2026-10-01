import '../../core/document/document.dart';
import '../enums.dart';

/// An image block (`<img>`).
///
/// Supports network URLs, local file paths, and base64 data URIs.
/// Can be resized and aligned (left, center, right).
class ImageNode extends BlockNode {
  String src;
  String? alt;
  double? width;
  double? height;
  String? caption;

  ImageNode({
    super.id,
    required this.src,
    this.alt,
    this.width,
    this.height,
    this.caption,
    super.alignment = SmartTextAlign.center,
  }) : super(spans: [TextFormatSpan.plain(alt ?? '')]);

  @override
  String get tag => 'img';

  @override
  BlockType get blockType => BlockType.image;

  @override
  String get plainText => alt?.isNotEmpty == true ? alt! : '[Image]';

  @override
  BlockNode deepCopy() => ImageNode(
        id: id,
        src: src,
        alt: alt,
        width: width,
        height: height,
        caption: caption,
        alignment: alignment,
      );

  @override
  String toString() =>
      'ImageNode(src: $src, alt: $alt, width: $width, height: $height, alignment: $alignment)';
}
