import '../../core/document/document.dart';
import '../enums.dart';

/// A document / generic file attachment block.
///
/// Serializes to an `<a>` download link or document embed tag.
class DocumentNode extends BlockNode {
  String src;
  String fileName;
  int? fileSize;
  String? fileExtension;

  DocumentNode({
    super.id,
    required this.src,
    required this.fileName,
    this.fileSize,
    this.fileExtension,
    super.alignment = SmartTextAlign.left,
  }) : super(spans: [TextFormatSpan.plain(fileName)]);

  @override
  String get tag => 'a';

  @override
  BlockType get blockType => BlockType.document;

  @override
  String get plainText => '[File: $fileName]';

  /// Formats the file size into a human-readable string (e.g. "2.4 MB").
  String get formattedSize {
    if (fileSize == null || fileSize! <= 0) return '';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double size = fileSize!.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1).replaceAll('.0', '')} ${suffixes[i]}';
  }

  @override
  BlockNode deepCopy() => DocumentNode(
        id: id,
        src: src,
        fileName: fileName,
        fileSize: fileSize,
        fileExtension: fileExtension,
        alignment: alignment,
      );

  @override
  String toString() =>
      'DocumentNode(fileName: $fileName, src: $src, fileSize: $fileSize, alignment: $alignment)';
}
