import 'package:flutter/material.dart';

/// A modern, beautiful Material 3 dialog for inserting or editing hyperlinks.
class LinkDialog extends StatefulWidget {
  const LinkDialog({
    super.key,
    this.initialUrl,
    this.initialText,
    this.isDarkMode = false,
  });

  final String? initialUrl;
  final String? initialText;
  final bool isDarkMode;

  @override
  State<LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<LinkDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _textController;
  final _formKey = GlobalKey<FormState>();

  final _textFocus = FocusNode();
  final _linkFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
    _textController = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _textController.dispose();
    super.dispose();
  }

  String _normalizeUrl(String raw) {
    var trimmed = raw.trim();
    if (trimmed.startsWith('/') ||
        trimmed.startsWith('#') ||
        trimmed.startsWith('mailto:') ||
        trimmed.startsWith('tel:') ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop({
        'action': 'insert',
        'url': _normalizeUrl(_urlController.text),
        'text': _textController.text.trim(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing =
        widget.initialUrl != null && widget.initialUrl!.isNotEmpty;

    final dialogBg = widget.isDarkMode
        ? colorScheme.surfaceContainerHigh
        : colorScheme.surfaceContainerLow;
    final textStyle = TextStyle(
      color: widget.isDarkMode ? Colors.white : Colors.black87,
    );

    return AlertDialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Icon(
            isEditing ? Icons.edit_note : Icons.link,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            isEditing ? 'Edit Link' : 'Insert Link',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: widget.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
      content: Container(
        width: 320,
        padding: const EdgeInsets.only(top: 8),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _textController,
                focusNode: _textFocus,
                style: textStyle,
                decoration: InputDecoration(
                  labelText: 'Display Text',
                  hintText: 'Enter text to display',
                  labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.title),
                ),
                onFieldSubmitted: (_) => _submit(),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter display text';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _urlController,
                focusNode: _linkFocus,
                style: textStyle,
                keyboardType: TextInputType.url,
                autofocus: !isEditing,
                decoration: InputDecoration(
                  labelText: 'Link URL',
                  hintText: 'https://example.com',
                  labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.link),
                ),
                onFieldSubmitted: (_) => _submit(),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a URL';
                  }
                  final trimmed = val.trim();
                  if (!trimmed.contains('.') &&
                      !trimmed.startsWith('/') &&
                      !trimmed.startsWith('#') &&
                      !trimmed.startsWith('mailto:') &&
                      !trimmed.startsWith('tel:')) {
                    return 'Please enter a valid URL';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        Row(
          children: [
            if (isEditing)
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop({'action': 'remove'});
                },
                icon: const Icon(Icons.link_off, size: 18),
                label: const Text('Remove'),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.error,
                ),
              ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(isEditing ? 'Save' : 'Insert'),
            ),
          ],
        ),
      ],
    );
  }
}
