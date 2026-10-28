import 'enums.dart';

/// Represents picked or inserted media or document data.
class SmartAttachmentData {
  /// The resource URL, local file path, or base64 data URI.
  final String src;

  /// The type of attachment (image, video, audio, document).
  final SmartAttachmentType type;

  /// Optional display name or filename (e.g. `report.pdf`, `song.mp3`).
  final String? name;

  /// Optional file size in bytes (e.g. 1048576 for 1MB).
  final int? sizeInBytes;

  /// Optional MIME type (e.g. `application/pdf`, `video/mp4`).
  final String? mimeType;

  /// Optional text alternative or description.
  final String? alt;

  /// Optional caption.
  final String? caption;

  /// Optional width for visual media (images, videos).
  final double? width;

  /// Optional height for visual media.
  final double? height;

  /// Optional duration for audio/video media.
  final Duration? duration;

  /// Whether cropping was requested prior to insertion (for images).
  final bool shouldCrop;

  const SmartAttachmentData({
    required this.src,
    required this.type,
    this.name,
    this.sizeInBytes,
    this.mimeType,
    this.alt,
    this.caption,
    this.width,
    this.height,
    this.duration,
    this.shouldCrop = false,
  });

  /// Formats the file size into a human-readable string (e.g., "1.2 MB").
  String get formattedSize {
    if (sizeInBytes == null || sizeInBytes! <= 0) return '';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double size = sizeInBytes!.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1).replaceAll('.0', '')} ${suffixes[i]}';
  }

  /// Alias for [sizeInBytes].
  int? get fileSize => sizeInBytes;

  /// Inferred file extension from [name] or null.
  String? get fileExtension =>
      name != null && name!.contains('.') ? name!.split('.').last : null;
}
