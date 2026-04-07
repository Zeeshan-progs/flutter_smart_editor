import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ColorPickerButton extends StatefulWidget {
  final IconData icon;
  final Color? currentColor;
  final String tooltip;
  final ValueChanged<Color?> onColorChanged;

  const ColorPickerButton({
    super.key,
    required this.icon,
    this.currentColor,
    required this.tooltip,
    required this.onColorChanged,
    this.enabled = true,
  });

  final bool enabled;

  @override
  State<ColorPickerButton> createState() => _ColorPickerButtonState();
}

class _ColorPickerButtonState extends State<ColorPickerButton> {
  Color _pickerColor = Colors.black;

  @override
  void initState() {
    super.initState();
    _pickerColor = widget.currentColor ?? Colors.black;
  }

  void _changeColor(Color color) {
    setState(() => _pickerColor = color);
  }

  void _showColorPicker() {
    _pickerColor = widget.currentColor ?? Colors.black;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(widget.tooltip),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: _pickerColor,
              onColorChanged: _changeColor,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Reset'),
              onPressed: () {
                widget.onColorChanged(null);
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Select'),
              onPressed: () {
                widget.onColorChanged(_pickerColor);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            widget.icon,
            color: widget.enabled ? null : Theme.of(context).disabledColor,
          ),
          if (widget.currentColor != null)
            Positioned(
              bottom: 0,
              child: Container(
                height: 4,
                width: 16,
                color: widget.enabled
                    ? widget.currentColor
                    : Theme.of(context).disabledColor,
              ),
            ),
        ],
      ),
      tooltip: widget.enabled ? widget.tooltip : null,
      onPressed: widget.enabled ? _showColorPicker : null,
    );
  }
}
