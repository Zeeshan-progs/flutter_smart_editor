import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

/// Cropper utility powered by the official [image_cropper] package.
class SmartImageCropper {
  /// Crops an image using the official [image_cropper] plugin.
  ///
  /// Supports:
  /// - Base64 Data URLs (`data:image/png;base64,...`)
  /// - Remote URLs (`http://...`, `https://...`)
  /// - Local file paths
  ///
  /// Returns the cropped image as a base64 Data URL, or null if cancelled.
  static Future<String?> crop({
    required BuildContext context,
    required String imageSrc,
    bool isDarkMode = false,
  }) async {
    try {
      String? localFilePath;
      bool isTempFile = false;

      if (imageSrc.startsWith('data:image')) {
        final commaIdx = imageSrc.indexOf(',');
        final base64Data =
            commaIdx >= 0 ? imageSrc.substring(commaIdx + 1) : imageSrc;
        final bytes = base64Decode(base64Data.replaceAll(RegExp(r'\s+'), ''));

        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
            '${tempDir.path}/crop_src_${DateTime.now().millisecondsSinceEpoch}.png');
        await tempFile.writeAsBytes(bytes);
        localFilePath = tempFile.path;
        isTempFile = true;
      } else if (imageSrc.startsWith('http://') ||
          imageSrc.startsWith('https://')) {
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(imageSrc));
        final response = await request.close();
        final bytes = await consolidateHttpClientResponseBytes(response);

        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
            '${tempDir.path}/crop_remote_${DateTime.now().millisecondsSinceEpoch}.png');
        await tempFile.writeAsBytes(bytes);
        localFilePath = tempFile.path;
        isTempFile = true;
      } else {
        localFilePath = imageSrc;
      }

      final theme = Theme.of(context);
      final primaryColor = theme.colorScheme.primary;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: localFilePath,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop & Adjust Image',
            toolbarColor: isDarkMode ? const Color(0xFF1E1E1E) : primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
          IOSUiSettings(
            title: 'Crop & Adjust Image',
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
            size: const CropperSize(width: 520, height: 520),
          ),
        ],
      );

      // Clean up temporary input file
      if (isTempFile) {
        try {
          final f = File(localFilePath);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }

      if (croppedFile == null) return null;

      final croppedBytes = await croppedFile.readAsBytes();
      final base64String = base64Encode(croppedBytes);
      return 'data:image/png;base64,$base64String';
    } catch (e) {
      debugPrint('SmartImageCropper error: $e');
      return null;
    }
  }

  /// Convenience alias for [crop].
  static Future<String?> show(
    BuildContext context, {
    required String imageSrc,
    bool isDarkMode = false,
  }) =>
      crop(context: context, imageSrc: imageSrc, isDarkMode: isDarkMode);
}
