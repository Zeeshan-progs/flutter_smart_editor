import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../cropper/smart_image_cropper.dart';

/// Modal dialog for importing images into [SmartEditor].
///
/// Features:
/// - Tab 1: Web URL import with live preview, caption, and alt text.
/// - Tab 2: Device import with Camera and Gallery options, live preview, and permission handling.
/// - Direct insertion or pre-insertion cropping via [SmartImageCropper].
class ImageImportDialog extends StatefulWidget {
  const ImageImportDialog({
    super.key,
    this.initialUrl,
    this.initialAlt,
    this.initialCaption,
    this.isDarkMode = false,
    this.onPickFromDevice,
  });

  final String? initialUrl;
  final String? initialAlt;
  final String? initialCaption;
  final bool isDarkMode;
  final Future<String?> Function()? onPickFromDevice;

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    String? initialUrl,
    String? initialAlt,
    String? initialCaption,
    bool isDarkMode = false,
    Future<String?> Function()? onPickFromDevice,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ImageImportDialog(
        initialUrl: initialUrl,
        initialAlt: initialAlt,
        initialCaption: initialCaption,
        isDarkMode: isDarkMode,
        onPickFromDevice: onPickFromDevice,
      ),
    );
  }

  @override
  State<ImageImportDialog> createState() => _ImageImportDialogState();
}

class _ImageImportDialogState extends State<ImageImportDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _urlController;
  late final TextEditingController _altController;
  late final TextEditingController _captionController;

  String? _previewUrl;
  String? _deviceImageSrc;
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
    _altController = TextEditingController(text: widget.initialAlt ?? '');
    _captionController =
        TextEditingController(text: widget.initialCaption ?? '');
    _captionController.addListener(_onCaptionChanged);
    _previewUrl = widget.initialUrl?.trim();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _altController.dispose();
    _captionController.removeListener(_onCaptionChanged);
    _captionController.dispose();
    super.dispose();
  }

  void _onCaptionChanged() {
    if (mounted) setState(() {});
  }

  void _onUrlChanged(String val) {
    final trimmed = val.trim();
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:image')) {
      setState(() => _previewUrl = trimmed);
    } else {
      setState(() => _previewUrl = null);
    }
  }

  Future<bool> _requestPermission(Permission permission, String name) async {
    if (kIsWeb) return true;
    final status = await permission.request();
    if (status.isGranted || status.isLimited) {
      return true;
    }
    if (status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('$name Permission Required'),
            content: Text(
              '$name access is permanently denied. Please enable it in system settings to pick images.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
      return false;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name permission was denied.')),
      );
    }
    return false;
  }

  Future<void> _pickFromCamera() async {
    final granted = await _requestPermission(Permission.camera, 'Camera');
    if (!granted) return;
    await _pickWithSource(ImageSource.camera);
  }

  Future<void> _pickFromGallery() async {
    if (!kIsWeb) {
      final photoStatus = await Permission.photos.request();
      if (!photoStatus.isGranted && !photoStatus.isLimited) {
        final storageStatus = await Permission.storage.request();
        if (!storageStatus.isGranted && !storageStatus.isLimited) {
          if (photoStatus.isPermanentlyDenied ||
              storageStatus.isPermanentlyDenied) {
            if (mounted) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Photos Permission Required'),
                  content: const Text(
                    'Photos access is permanently denied. Please enable it in system settings.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        openAppSettings();
                      },
                      child: const Text('Open Settings'),
                    ),
                  ],
                ),
              );
            }
            return;
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Photos permission was denied.')),
            );
          }
          return;
        }
      }
    }
    await _pickWithSource(ImageSource.gallery);
  }

  Future<void> _pickWithSource(ImageSource source) async {
    setState(() => _isPicking = true);
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (file != null && mounted) {
        final bytes = await file.readAsBytes();
        final mime = file.mimeType ?? 'image/png';
        final base64String = base64Encode(bytes);
        setState(() {
          _deviceImageSrc = 'data:$mime;base64,$base64String';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _pickFromDevice() async {
    if (widget.onPickFromDevice != null) {
      setState(() => _isPicking = true);
      try {
        final result = await widget.onPickFromDevice!();
        if (result != null && mounted) {
          setState(() => _deviceImageSrc = result);
        }
      } finally {
        if (mounted) setState(() => _isPicking = false);
      }
    } else {
      // Default: show picker sheet (Camera or Gallery)
      _showSourcePickerSheet();
    }
  }

  void _showSourcePickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo (Camera)'),
              onTap: () {
                if (Navigator.of(ctx).canPop()) {
                  Navigator.of(ctx).pop();
                }
                _pickFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () {
                if (Navigator.of(ctx).canPop()) {
                  Navigator.of(ctx).pop();
                }
                _pickFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _proceedToCrop(String src) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop({
        'action': 'crop',
        'src': src,
        'alt': _altController.text.trim().isNotEmpty
            ? _altController.text.trim()
            : null,
        'caption': _captionController.text.trim().isNotEmpty
            ? _captionController.text.trim()
            : null,
      });
    }
  }

  void _insertDirect(String src) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop({
        'action': 'insert',
        'src': src,
        'alt': _altController.text.trim().isNotEmpty
            ? _altController.text.trim()
            : null,
        'caption': _captionController.text.trim().isNotEmpty
            ? _captionController.text.trim()
            : null,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final surfaceColor =
        isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F7);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Header ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      color: Theme.of(context).colorScheme.primary, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Insert Image',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop(null);
                      }
                    },
                  ),
                ],
              ),
            ),

            // ─── Tabs ─────────────────────────────────────────
            TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(icon: Icon(Icons.link, size: 18), text: 'From Web URL'),
                Tab(icon: Icon(Icons.devices, size: 18), text: 'From Device'),
              ],
            ),
            const Divider(height: 1),

            // ─── Tab Content ──────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUrlTab(textColor, surfaceColor),
                  _buildDeviceTab(textColor, surfaceColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlTab(Color textColor, Color surfaceColor) {
    final hasValidUrl = _previewUrl != null && _previewUrl!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _urlController,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: 'Image URL',
              hintText: 'https://example.com/photo.jpg',
              prefixIcon: const Icon(Icons.link, size: 20),
              suffixIcon: _urlController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _urlController.clear();
                        _onUrlChanged('');
                      },
                    )
                  : null,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
            onChanged: _onUrlChanged,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _captionController,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: 'Caption (Optional)',
              hintText: 'Visible text displayed below the image',
              prefixIcon: const Icon(Icons.subtitles_outlined, size: 20),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _altController,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: 'Alt Text (Optional)',
              hintText: 'Accessible description for screen readers',
              prefixIcon: const Icon(Icons.description_outlined, size: 20),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),

          // Preview area
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.isDarkMode ? Colors.white12 : Colors.black12,
              ),
            ),
            child: hasValidUrl
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.network(
                      _previewUrl!,
                      fit: BoxFit.contain,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (ctx, err, stack) => const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image_outlined,
                                size: 36, color: Colors.redAccent),
                            SizedBox(height: 6),
                            Text(
                              'Unable to load image from URL',
                              style: TextStyle(
                                  color: Colors.redAccent, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_outlined,
                            size: 40,
                            color: widget.isDarkMode
                                ? Colors.white38
                                : Colors.black38),
                        const SizedBox(height: 6),
                        Text(
                          'Paste an image URL above to preview',
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.isDarkMode
                                ? Colors.white38
                                : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (hasValidUrl && _captionController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _captionController.text.trim(),
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                color: widget.isDarkMode ? Colors.white70 : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),

          // Actions
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.crop, size: 18),
                label: const Text('Crop & Insert'),
                onPressed:
                    hasValidUrl ? () => _proceedToCrop(_previewUrl!) : null,
              ),
              FilledButton.icon(
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Insert Directly'),
                onPressed:
                    hasValidUrl ? () => _insertDirect(_previewUrl!) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceTab(Color textColor, Color surfaceColor) {
    final hasDeviceImage =
        _deviceImageSrc != null && _deviceImageSrc!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Camera and Gallery Selection Options ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.camera_alt_outlined, size: 20),
                  label: const Text('Camera'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isPicking ? null : _pickFromCamera,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.photo_library_outlined, size: 20),
                  label: const Text('Gallery'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isPicking ? null : _pickFromGallery,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Image Preview or Dropzone Card ──
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _isPicking ? null : _pickFromDevice,
            child: Container(
              height: 170,
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: _isPicking
                  ? const Center(child: CircularProgressIndicator())
                  : hasDeviceImage
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: _deviceImageSrc!.startsWith('data:image')
                                  ? Image.memory(
                                      base64Decode(_deviceImageSrc!
                                          .substring(
                                              _deviceImageSrc!.indexOf(',') + 1)
                                          .replaceAll(RegExp(r'\s+'), '')),
                                      fit: BoxFit.contain,
                                    )
                                  : Image.network(
                                      _deviceImageSrc!,
                                      fit: BoxFit.contain,
                                    ),
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Material(
                                elevation: 3,
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.black87,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: _showSourcePickerSheet,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit,
                                            size: 14, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text('Change',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_upload_outlined,
                              size: 44,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Choose Image from Device',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap to open camera or browse gallery',
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.isDarkMode
                                    ? Colors.white60
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
            ),
          ),
          if (hasDeviceImage && _captionController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _captionController.text.trim(),
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                color: widget.isDarkMode ? Colors.white70 : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),

          TextField(
            controller: _captionController,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: 'Caption (Optional)',
              hintText: 'Visible text displayed below the image',
              prefixIcon: const Icon(Icons.subtitles_outlined, size: 20),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _altController,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: 'Alt Text (Optional)',
              hintText: 'Accessible description for screen readers',
              prefixIcon: const Icon(Icons.description_outlined, size: 20),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 20),

          // Actions
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.crop, size: 18),
                label: const Text('Crop & Insert'),
                onPressed: hasDeviceImage
                    ? () => _proceedToCrop(_deviceImageSrc!)
                    : null,
              ),
              FilledButton.icon(
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Insert Directly'),
                onPressed: hasDeviceImage
                    ? () => _insertDirect(_deviceImageSrc!)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
