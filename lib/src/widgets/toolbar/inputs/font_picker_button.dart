import 'package:flutter/material.dart';

class FontPickerButton extends StatelessWidget {
  final String? currentFont;
  final ValueChanged<String?> onFontChanged;
  final String tooltip;

  const FontPickerButton({
    super.key,
    this.currentFont,
    required this.onFontChanged,
    this.tooltip = 'Font Family',
    this.enabled = true,
  });

  final bool enabled;

  static const List<String> defaultFonts = [
    'Arial',
    'Courier New',
    'Georgia',
    'Lato',
    'Roboto',
    'Times New Roman',
    'Trebuchet MS',
    'Verdana',
  ];

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: enabled ? tooltip : '',
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: defaultFonts.contains(currentFont) ? currentFont : null,
          hint: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text('Font'),
          ),
          icon: Icon(
            Icons.arrow_drop_down,
            size: 20,
            color: enabled ? null : Theme.of(context).disabledColor,
          ),
          onChanged: enabled ? onFontChanged : null,
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text('Default'),
              ),
            ),
            ...defaultFonts.map((font) {
              return DropdownMenuItem<String>(
                value: font,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(font, style: TextStyle(fontFamily: font)),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
