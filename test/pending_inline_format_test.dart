import 'package:flutter/material.dart';
import 'package:flutter_smart_editor/src/core/document_controller.dart';
import 'package:flutter_smart_editor/src/models/enums.dart';
import 'package:flutter_smart_editor/src/models/pending_inline_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PendingInlineFormat', () {
    test('mergeIntoToolbarMap clears foreground when inherit is false and color null',
        () {
      final formats = DocumentController().getFormatAt(0, 0);
      formats[SmartButtonType.foregroundColor] = const Color(0xFFFF0000);

      const pending = PendingInlineFormat(
        isBold: false,
        isItalic: false,
        isUnderline: false,
        isStrikethrough: false,
        inheritForegroundColor: false,
        foregroundColor: null,
        inheritBackgroundColor: true,
        inheritFontSize: true,
        inheritFontFamily: true,
      );
      pending.mergeIntoToolbarMap(formats);

      expect(formats[SmartButtonType.foregroundColor], isNull);
    });
  });
}
