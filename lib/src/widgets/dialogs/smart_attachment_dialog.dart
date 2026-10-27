import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/attachment_data.dart';
import '../../models/enums.dart';

/// Comprehensive unified modal dialog for inserting attachments of any type
/// (Image, Video, Audio, Document).
///
/// Adapts dynamically based on [type]:
/// - **Image:** Supports live image preview, alt text, caption, and dual actions:
///   `[Crop & Insert]` and `[Insert Directly]`.
/// - **Video / Audio / Document:** Focused, lightweight inputs and device pickers
///   with NO preview rendering, and a single `[Insert <Type>]` action.
class SmartAttachmentDialog extends StatefulWidget {
  final SmartAttachmentType type;
  final bool isDarkMode;
  final String? initialUrl;
  final String? initialName;
  final String? initialCaption;
  final String? initialAlt;
  final Future<SmartAttachmentData?> Function()? onPickFromDevice;

  const SmartAttachmentDialog({
    super.key,
    required this.type,
    required this.isDarkMode,
    this.initialUrl,
    this.initialName,
    this.initialCaption,
    this.initialAlt,
    this.onPickFromDevice,
  });

  static Future<SmartAttachmentData?> show(
    BuildContext context, {
    required SmartAttachmentType type,
    required bool isDarkMode,
    String? initialUrl,
    String? initialName,
    String? initialCaption,
    String? initialAlt,
    Future<SmartAttachmentData?> Function()? onPickFromDevice,
  }) {
    return showDialog<SmartAttachmentData>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SmartAttachmentDialog(
        type: type,
        isDarkMode: isDarkMode,
        initialUrl: initialUrl,
        initialName: initialName,
        initialCaption: initialCaption,
        initialAlt: initialAlt,
        onPickFromDevice: onPickFromDevice,
      ),
    );
  }

  @override
  State<SmartAttachmentDialog> createState() => _SmartAttachmentDialogState();
}

class _SmartAttachmentDialogState extends State<SmartAttachmentDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _urlController;
  late final TextEditingController _nameController;
  late final TextEditingController _captionController;
  late final TextEditingController _altController;

  String? _previewUrl;
  SmartAttachmentData? _pickedDeviceData;
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _captionController =
        TextEditingController(text: widget.initialCaption ?? '');
    _altController = TextEditingController(text: widget.initialAlt ?? '');

    _previewUrl = widget.initialUrl?.trim();
    _urlController.addListener(_onUrlChanged);
    _captionController.addListener(_onFieldChanged);
    _altController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _urlController.removeListener(_onUrlChanged);
    _captionController.removeListener(_onFieldChanged);
    _altController.removeListener(_onFieldChanged);
    _urlController.dispose();
    _nameController.dispose();
    _captionController.dispose();
    _altController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  void _onUrlChanged() {
    final trimmed = _urlController.text.trim();
    if (widget.type == SmartAttachmentType.image) {
      if (trimmed.isNotEmpty &&
          (trimmed.startsWith('http://') ||
              trimmed.startsWith('https://') ||
              trimmed.startsWith('data:image') ||
              trimmed.startsWith('/'))) {
        if (_previewUrl != trimmed) {
          setState(() => _previewUrl = trimmed);
        }
      } else {
        if (_previewUrl != null) {
          setState(() => _previewUrl = null);
        }
      }
    } else {
      if (mounted) setState(() {});
    }
  }

  String get _typeName {
    switch (widget.type) {
      case SmartAttachmentType.image:
        return 'Image';
      case SmartAttachmentType.video:
        return 'Video';
      case SmartAttachmentType.audio:
        return 'Audio';
      case SmartAttachmentType.document:
        return 'Document';
    }
  }

  IconData get _typeIcon {
    switch (widget.type) {
      case SmartAttachmentType.image:
        return Icons.image_outlined;
      case SmartAttachmentType.video:
        return Icons.videocam_outlined;
      case SmartAttachmentType.audio:
        return Icons.audiotrack_outlined;
      case SmartAttachmentType.document:
        return Icons.description_outlined;
    }
  }

  Color get _accentColor {
    switch (widget.type) {
      case SmartAttachmentType.image:
        return const Color(0xFF38BDF8);
      case SmartAttachmentType.video:
        return const Color(0xFFF43F5E);
      case SmartAttachmentType.audio:
        return const Color(0xFF10B981);
      case SmartAttachmentType.document:
        return const Color(0xFFA855F7);
    }
  }

  // ── Permission Helper ──

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
              '$name access is permanently denied. Please enable it in system settings to select media.',
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

  // ── Device Pickers ──

  Future<void> _pickImage(ImageSource source) async {
    final granted = await _requestPermission(
      source == ImageSource.camera ? Permission.camera : Permission.photos,
      source == ImageSource.camera ? 'Camera' : 'Photos',
    );
    if (!granted) return;

    setState(() => _isPicking = true);
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (picked != null && mounted) {
        final bytes = await picked.readAsBytes();
        final mime = picked.mimeType ?? 'image/png';
        final base64String = base64Encode(bytes);
        setState(() {
          _pickedDeviceData = SmartAttachmentData(
            src: 'data:$mime;base64,$base64String',
            type: SmartAttachmentType.image,
            name: picked.name,
            sizeInBytes: bytes.length,
          );
          if (_altController.text.isEmpty) {
            _altController.text = picked.name;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    final granted = await _requestPermission(
      source == ImageSource.camera ? Permission.camera : Permission.photos,
      source == ImageSource.camera ? 'Camera' : 'Photos',
    );
    if (!granted) return;

    setState(() => _isPicking = true);
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickVideo(source: source);
      if (picked != null && mounted) {
        final length = await picked.length();
        setState(() {
          _pickedDeviceData = SmartAttachmentData(
            src: picked.path,
            type: SmartAttachmentType.video,
            name: picked.name,
            sizeInBytes: length,
          );
          if (_nameController.text.isEmpty) {
            _nameController.text = picked.name;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick video: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _pickAudio() async {
    setState(() => _isPicking = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty && mounted) {
        final file = result.files.first;
        final src = file.path ?? file.name;
        setState(() {
          _pickedDeviceData = SmartAttachmentData(
            src: src,
            type: SmartAttachmentType.audio,
            name: file.name,
            sizeInBytes: file.size,
          );
          if (_nameController.text.isEmpty) {
            _nameController.text = file.name;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick audio: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _pickDocument() async {
    setState(() => _isPicking = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty && mounted) {
        final file = result.files.first;
        final src = file.path ?? file.name;
        setState(() {
          _pickedDeviceData = SmartAttachmentData(
            src: src,
            type: SmartAttachmentType.document,
            name: file.name,
            sizeInBytes: file.size,
          );
          if (_nameController.text.isEmpty) {
            _nameController.text = file.name;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick document: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _handleCustomDelegatePick() async {
    if (widget.onPickFromDevice == null) return;
    setState(() => _isPicking = true);
    try {
      final data = await widget.onPickFromDevice!();
      if (data != null && mounted) {
        setState(() {
          _pickedDeviceData = data;
          if (_nameController.text.isEmpty && data.name != null) {
            _nameController.text = data.name!;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Picker error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  // ── Submission Handlers ──

  void _submitUrl({bool shouldCrop = false}) {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (widget.type == SmartAttachmentType.document
            ? url.split('/').last
            : null);
    final caption = _captionController.text.trim().isNotEmpty
        ? _captionController.text.trim()
        : null;
    final alt = _altController.text.trim().isNotEmpty
        ? _altController.text.trim()
        : null;

    final result = SmartAttachmentData(
      src: url,
      type: widget.type,
      name: name,
      caption: caption,
      alt: alt ?? name,
      shouldCrop: shouldCrop,
    );
    Navigator.of(context).pop(result);
  }

  void _submitDevice({bool shouldCrop = false}) {
    if (_pickedDeviceData == null) return;

    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : _pickedDeviceData!.name;
    final caption = _captionController.text.trim().isNotEmpty
        ? _captionController.text.trim()
        : _pickedDeviceData!.caption;
    final alt = _altController.text.trim().isNotEmpty
        ? _altController.text.trim()
        : _pickedDeviceData!.alt;

    final result = SmartAttachmentData(
      src: _pickedDeviceData!.src,
      type: widget.type,
      name: name,
      caption: caption,
      alt: alt ?? name,
      sizeInBytes: _pickedDeviceData!.sizeInBytes,
      shouldCrop: shouldCrop,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDarkMode ? const Color(0xFF1E232E) : Colors.white;
    final fg = widget.isDarkMode ? Colors.white : const Color(0xFF1E293B);
    final sub =
        widget.isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border =
        widget.isDarkMode ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0);
    final inputBg =
        widget.isDarkMode ? const Color(0xFF131722) : const Color(0xFFF8FAFC);

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_typeIcon, color: _accentColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Insert $_typeName',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: fg,
                          ),
                        ),
                        Text(
                          'Web URL or choose from your device',
                          style: TextStyle(fontSize: 12, color: sub),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: sub, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tabs
              Container(
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                padding: const EdgeInsets.all(3),
                child: TabBar(
                  controller: _tabController,
                  onTap: (index) => setState(() {}),
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  labelColor: _accentColor,
                  unselectedLabelColor: sub,
                  labelStyle:
                      const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: const [
                    Tab(
                      iconMargin: EdgeInsets.only(bottom: 2),
                      icon: Icon(Icons.link, size: 18),
                      text: 'From Web URL',
                    ),
                    Tab(
                      iconMargin: EdgeInsets.only(bottom: 2),
                      icon: Icon(Icons.devices, size: 18),
                      text: 'From Device',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tab Views
              Flexible(
                child: SingleChildScrollView(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, _) {
                        return _tabController.index == 0
                            ? _buildUrlTab(inputBg, border, fg, sub)
                            : _buildDeviceTab(inputBg, border, fg, sub);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab 1: Web URL ──

  Widget _buildUrlTab(Color inputBg, Color border, Color fg, Color sub) {
    final hasValidUrl = widget.type == SmartAttachmentType.image
        ? (_previewUrl != null && _previewUrl!.isNotEmpty)
        : _urlController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          // URL field
          TextField(
            controller: _urlController,
            style: TextStyle(color: fg, fontSize: 14),
            decoration: InputDecoration(
              labelText: '$_typeName Web URL *',
              hintText: widget.type == SmartAttachmentType.image
                  ? 'https://example.com/photo.jpg'
                  : (widget.type == SmartAttachmentType.video
                      ? 'https://example.com/video.mp4'
                      : (widget.type == SmartAttachmentType.audio
                          ? 'https://example.com/audio.mp3'
                          : 'https://example.com/file.pdf')),
              prefixIcon: Icon(Icons.link, color: _accentColor, size: 20),
              suffixIcon: _urlController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _urlController.clear();
                        _onUrlChanged();
                      },
                    )
                  : null,
              filled: true,
              fillColor: inputBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _accentColor, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),

          // Type-specific fields
          if (widget.type == SmartAttachmentType.image) ...[
            TextField(
              controller: _captionController,
              style: TextStyle(color: fg, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Caption (Optional)',
                hintText: 'Visible text displayed below the image',
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _accentColor, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _altController,
              style: TextStyle(color: fg, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Alt Text (Optional)',
                hintText: 'Accessible description for screen readers',
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _accentColor, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // ONLY Image shows preview
            _buildImageLivePreview(inputBg, border, fg, sub),
          ] else if (widget.type == SmartAttachmentType.video) ...[
            TextField(
              controller: _nameController,
              style: TextStyle(color: fg, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Video Title (Optional)',
                hintText: 'Title of the video',
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _accentColor, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _captionController,
              style: TextStyle(color: fg, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Caption / Description (Optional)',
                hintText: 'Optional video description',
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _accentColor, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ] else if (widget.type == SmartAttachmentType.audio) ...[
            TextField(
              controller: _nameController,
              style: TextStyle(color: fg, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Track Title / Name (Optional)',
                hintText: 'Title of the audio track',
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _accentColor, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _captionController,
              style: TextStyle(color: fg, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Artist / Caption (Optional)',
                hintText: 'Artist name or subtitle',
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _accentColor, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ] else if (widget.type == SmartAttachmentType.document) ...[
            TextField(
              controller: _nameController,
              style: TextStyle(color: fg, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Document Title / File Name (Optional)',
                hintText: 'e.g. Annual_Report_2026.pdf',
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _accentColor, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Action Buttons
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel', style: TextStyle(color: sub)),
              ),

              // Image has dual action: Crop & Insert OR Insert Directly
              if (widget.type == SmartAttachmentType.image) ...[
                OutlinedButton.icon(
                  onPressed:
                      hasValidUrl ? () => _submitUrl(shouldCrop: true) : null,
                  icon: const Icon(Icons.crop, size: 16),
                  label: const Text('Crop & Insert'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accentColor,
                    side:
                        BorderSide(color: hasValidUrl ? _accentColor : border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                FilledButton.icon(
                  onPressed:
                      hasValidUrl ? () => _submitUrl(shouldCrop: false) : null,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Insert Directly'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ] else ...[
                // Video, Audio, Document: Direct Insert
                FilledButton.icon(
                  onPressed: hasValidUrl ? () => _submitUrl() : null,
                  icon: const Icon(Icons.check, size: 16),
                  label: Text('Insert $_typeName'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
        ],
      );
  }

  Widget _buildImageLivePreview(
      Color inputBg, Color border, Color fg, Color sub) {
    if (_previewUrl == null || _previewUrl!.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: inputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, size: 36, color: sub),
            const SizedBox(height: 6),
            Text('Paste an image URL above to preview',
                style: TextStyle(color: sub, fontSize: 12)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Image.network(
              _previewUrl!,
              fit: BoxFit.contain,
              loadingBuilder: (ctx, child, progress) {
                if (progress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (_, __, ___) => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image_outlined,
                        size: 32, color: Colors.redAccent),
                    SizedBox(height: 4),
                    Text('Unable to load image from URL',
                        style:
                            TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_captionController.text.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _captionController.text.trim(),
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: fg.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  // ── Tab 2: From Device ──

  Widget _buildDeviceTab(Color inputBg, Color border, Color fg, Color sub) {
    if (_isPicking) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _accentColor),
          const SizedBox(height: 12),
          Text('Selecting $_typeName...',
              style: TextStyle(color: sub, fontSize: 13)),
        ],
      );
    }

    // ── When a File IS Picked ──
    if (_pickedDeviceData != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            // If Image: show preview
            if (widget.type == SmartAttachmentType.image) ...[
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: _pickedDeviceData!.src.startsWith('data:image')
                          ? Image.memory(
                              base64Decode(_pickedDeviceData!.src.substring(
                                  _pickedDeviceData!.src.indexOf(',') + 1)),
                              fit: BoxFit.contain,
                            )
                          : Image.network(
                              _pickedDeviceData!.src,
                              fit: BoxFit.contain,
                            ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Material(
                        elevation: 2,
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.black87,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => setState(() => _pickedDeviceData = null),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text('Change',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _captionController,
                style: TextStyle(color: fg, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Caption (Optional)',
                  hintText: 'Visible text displayed below the image',
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: border),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _altController,
                style: TextStyle(color: fg, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Alt Text (Optional)',
                  hintText: 'Accessible description for screen readers',
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: border),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ] else ...[
              // Video / Audio / Document: Compact Info Card (NO PREVIEW)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: _accentColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _accentColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_typeIcon, color: _accentColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pickedDeviceData!.name ?? 'Selected $_typeName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: fg,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _pickedDeviceData!.formattedSize.isNotEmpty
                                ? _pickedDeviceData!.formattedSize
                                : 'Ready to insert',
                            style: TextStyle(color: sub, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _pickedDeviceData = null),
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                style: TextStyle(color: fg, fontSize: 14),
                decoration: InputDecoration(
                  labelText: widget.type == SmartAttachmentType.document
                      ? 'Document Title / File Name'
                      : 'Display Title / Name',
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: border),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              if (widget.type != SmartAttachmentType.document) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _captionController,
                  style: TextStyle(color: fg, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Caption (Optional)',
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
              ],
            ],

            const SizedBox(height: 18),

            // Action Buttons
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: TextStyle(color: sub)),
                ),
                if (widget.type == SmartAttachmentType.image) ...[
                  OutlinedButton.icon(
                    onPressed: () => _submitDevice(shouldCrop: true),
                    icon: const Icon(Icons.crop, size: 16),
                    label: const Text('Crop & Insert'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accentColor,
                      side: BorderSide(color: _accentColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _submitDevice(shouldCrop: false),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Insert Directly'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ] else ...[
                  FilledButton.icon(
                    onPressed: () => _submitDevice(),
                    icon: const Icon(Icons.check, size: 16),
                    label: Text('Insert $_typeName'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
    }

    // ── When NO File is Picked Yet ──
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onPickFromDevice != null) ...[
          _buildPickerTile(
            icon: Icons.upload_file,
            title: 'Choose from Device',
            subtitle: 'Use custom application picker',
            onTap: _handleCustomDelegatePick,
            fg: fg,
            sub: sub,
            inputBg: inputBg,
            border: border,
          ),
          const SizedBox(height: 10),
        ],
        if (widget.type == SmartAttachmentType.image) ...[
          _buildPickerTile(
            icon: Icons.camera_alt_outlined,
            title: 'Take Photo',
            subtitle: 'Capture a photo with your device camera',
            onTap: () => _pickImage(ImageSource.camera),
            fg: fg,
            sub: sub,
            inputBg: inputBg,
            border: border,
          ),
          const SizedBox(height: 10),
          _buildPickerTile(
            icon: Icons.photo_library_outlined,
            title: 'Photo Gallery',
            subtitle: 'Choose an existing image from gallery',
            onTap: () => _pickImage(ImageSource.gallery),
            fg: fg,
            sub: sub,
            inputBg: inputBg,
            border: border,
          ),
        ] else if (widget.type == SmartAttachmentType.video) ...[
          _buildPickerTile(
            icon: Icons.videocam_outlined,
            title: 'Record Video',
            subtitle: 'Capture a video with your device camera',
            onTap: () => _pickVideo(ImageSource.camera),
            fg: fg,
            sub: sub,
            inputBg: inputBg,
            border: border,
          ),
          const SizedBox(height: 10),
          _buildPickerTile(
            icon: Icons.video_library_outlined,
            title: 'Video Gallery',
            subtitle: 'Choose an existing video from gallery',
            onTap: () => _pickVideo(ImageSource.gallery),
            fg: fg,
            sub: sub,
            inputBg: inputBg,
            border: border,
          ),
        ] else if (widget.type == SmartAttachmentType.audio) ...[
          _buildPickerTile(
            icon: Icons.audiotrack_outlined,
            title: 'Audio Files',
            subtitle: 'Choose MP3, WAV, M4A or audio track',
            onTap: _pickAudio,
            fg: fg,
            sub: sub,
            inputBg: inputBg,
            border: border,
          ),
        ] else if (widget.type == SmartAttachmentType.document) ...[
          _buildPickerTile(
            icon: Icons.description_outlined,
            title: 'Browse Documents',
            subtitle: 'Choose PDF, DOCX, XLSX, TXT, or ZIP',
            onTap: _pickDocument,
            fg: fg,
            sub: sub,
            inputBg: inputBg,
            border: border,
          ),
        ],
      ],
    );
  }

  Widget _buildPickerTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color fg,
    required Color sub,
    required Color inputBg,
    required Color border,
  }) {
    return Material(
      color: inputBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _accentColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: sub),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: sub, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
