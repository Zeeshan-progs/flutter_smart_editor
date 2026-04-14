import 'package:flutter/material.dart';
import '../../../models/enums.dart';
import '../../../models/toolbar/toolbar_index.dart';
import '../../../core/document/document_controller.dart';

class BulletStylePicker extends StatelessWidget {
  const BulletStylePicker({
    super.key,
    required this.group,
    required this.activeColor,
    required this.documentController,
    required this.getFocusedBlockIndex,
    this.onFormatApplied,
  });

  final SmartListButtons group;
  final Color activeColor;
  final DocumentController documentController;
  final int Function() getFocusedBlockIndex;
  final VoidCallback? onFormatApplied;

  static void show(
    BuildContext context, {
    required SmartListButtons group,
    required Color activeColor,
    required DocumentController documentController,
    required int Function() getFocusedBlockIndex,
    VoidCallback? onFormatApplied,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => BulletStylePicker(
        group: group,
        activeColor: activeColor,
        documentController: documentController,
        getFocusedBlockIndex: getFocusedBlockIndex,
        onFormatApplied: onFormatApplied,
      ),
    );
  }

  String getSymbol(SmartBulletStyle style) {
    switch (style) {
      case SmartBulletStyle.filledCircle:
        return '\u2022';
      case SmartBulletStyle.hollowCircle:
        return '\u25e6';
      case SmartBulletStyle.filledSquare:
        return '\u25aa';
      case SmartBulletStyle.hollowSquare:
        return '\u25a1';
      case SmartBulletStyle.diamond:
        return '\u25c6';
      case SmartBulletStyle.hollowDiamond:
        return '\u25c7';
      case SmartBulletStyle.arrow:
        return '\u2192';
      case SmartBulletStyle.doubleArrow:
        return '\u00bb';
      case SmartBulletStyle.dash:
        return '\u2013';
      case SmartBulletStyle.star:
        return '\u2605';
      case SmartBulletStyle.hollowStar:
        return '\u2606';
      case SmartBulletStyle.checkmark:
        return '\u2713';
      case SmartBulletStyle.triangle:
        return '\u25b6';
    }
  }

  @override
  Widget build(BuildContext context) {
    final styles = group.availableStyles ?? SmartBulletStyle.values;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bullet Style',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(styles.length, (i) {
              return GestureDetector(
                onTap: () {
                  final blockIndex = getFocusedBlockIndex();
                  documentController.setBulletStyle(blockIndex, styles[i]);
                  onFormatApplied?.call();
                  Navigator.pop(context);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: activeColor.withValues(alpha: 0.2)),
                  ),
                  child: Center(
                    child: Text(getSymbol(styles[i]),
                        style: const TextStyle(fontSize: 20)),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
