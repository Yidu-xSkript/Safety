// Draws the app icon (the growth-ring slab) with the same palette as the app.
//   flutter test tool/make_icon.dart
// writes assets/icon/icon.png (full bleed, for iOS and legacy Android) and assets/icon/icon_foreground.png
// (transparent, inside Android's adaptive-icon safe zone). Then: dart run flutter_launcher_icons
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _ground = ui.Color(0xFF0F1A17);
const _heart = ui.Color(0xFF1E6B5C);
const _cambium = ui.Color(0xFF4CCDB0);
const _sap = ui.Color(0xFFE9A94A);
const _frost = ui.Color(0xFF9DB3C6);

Future<void> _write(String path, {required bool background, required double radius}) async {
  const size = 1024.0;
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec, const ui.Rect.fromLTWH(0, 0, size, size));
  if (background) c.drawRect(const ui.Rect.fromLTWH(0, 0, size, size), ui.Paint()..color = _ground);

  const center = ui.Offset(size / 2, size / 2);
  final k = radius / 440; // everything scales with the outer radius
  c.drawCircle(center, 92 * k, ui.Paint()..color = _heart);

  // Seven rings, oldest inside. Ring 4 carries the scar (a notch at 12 o'clock): the tree grew past it.
  for (var i = 0; i < 7; i++) {
    final r = (140 + i * 46) * k;
    final paint = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 28 * k
      ..color = i == 3 ? _frost : (i == 6 ? _sap : _cambium);
    final notch = i == 3 ? 26 * math.pi / 180 : 0.0;
    final sweep = i == 6 ? 1.5 * math.pi : 2 * math.pi; // the newest ring is still growing
    c.drawArc(ui.Rect.fromCircle(center: center, radius: r), -math.pi / 2 + notch / 2, sweep - notch, false, paint);
  }

  final image = await rec.endRecording().toImage(size.toInt(), size.toInt());
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes.buffer.asUint8List());
}

void main() {
  testWidgets('draw the icon', (t) async {
    await t.runAsync(() async {
      await _write('assets/icon/icon.png', background: true, radius: 440);
      await _write('assets/icon/icon_foreground.png', background: false, radius: 300); // inside the adaptive safe zone
    });
  });
}
