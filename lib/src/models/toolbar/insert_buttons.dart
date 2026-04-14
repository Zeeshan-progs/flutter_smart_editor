import 'toolbar_group.dart';

/// Insert buttons (Link, Image, Table, etc.)
class SmartInsertButtons extends SmartToolbarGroup {
  final bool link;
  final bool picture;
  final bool audio;
  final bool video;
  final bool otherFile;
  final bool table;

  const SmartInsertButtons({
    this.link = true,
    this.picture = true,
    this.audio = true,
    this.video = true,
    this.otherFile = false,
    this.table = true,
  });
}
