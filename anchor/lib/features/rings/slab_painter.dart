import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'ring_model.dart';

/// Which person-hue a slab uses. `you` is always the viewer (teal), on both phones.
enum Person { you, partner }

Color personColor(AnchorPalette p, Person who) => who == Person.you ? p.you : p.partner;
Color personDeep(AnchorPalette p, Person who) => who == Person.you ? p.youDeep : p.partnerDeep;

/// Draws heartwood + day rings + today ring. Flat ink only: no gradient, glow or shadow.
class SlabPainter extends CustomPainter {
  SlabPainter({required this.data, required this.person, required this.palette});

  final SlabData data;
  final Person person;
  final AnchorPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final diameter = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final s = diameter / kSlabBase;
    final hue = personColor(palette, person);

    // Heartwood: the older days, compressed. Hairlines suggest grain, not texture.
    canvas.drawCircle(center, kHeartwoodRadius * s, Paint()..color = personDeep(palette, person));
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75 * s
      ..color = palette.onDeep.withValues(alpha: 0.22);
    for (final r in const [8.0, 12.5, 16.5]) {
      canvas.drawCircle(center, r * s, grain);
    }

    for (final ring in layoutRings(data, diameter: diameter)) {
      ring.isToday ? _today(canvas, center, ring, hue, s) : _past(canvas, center, ring, hue, s);
    }
  }

  void _past(Canvas canvas, Offset c, RingStroke ring, Color hue, double s) {
    switch (ring.day.pledge) {
      case PledgeState.held:
        _arc(canvas, c, ring.radius, 0, 360, Paint()..style = PaintingStyle.stroke..strokeWidth = ring.width..color = hue);
      case PledgeState.slipped:
        _notched(canvas, c, ring.radius, Paint()..style = PaintingStyle.stroke..strokeWidth = ring.width..color = palette.frost);
      case PledgeState.unchecked:
        _dashed(canvas, c, ring.radius, s);
    }
  }

  void _today(Canvas canvas, Offset c, RingStroke ring, Color hue, double s) {
    final pledge = ring.day.pledge;
    final color = pledge == PledgeState.slipped ? palette.frost : hue;
    final stroke = Paint()..style = PaintingStyle.stroke..strokeWidth = ring.width..color = color;
    final track = Paint()..style = PaintingStyle.stroke..strokeWidth = ring.width..color = color.withValues(alpha: 0.28);

    switch (pledge) {
      case PledgeState.unchecked:
        _dashed(canvas, c, ring.radius, s);
        _arc(canvas, c, ring.radius, 0, ring.day.fill * 360, stroke);
      case PledgeState.held:
        _arc(canvas, c, ring.radius, 0, 360, track);
        _arc(canvas, c, ring.radius, 0, ring.day.fill * 360, stroke);
      case PledgeState.slipped:
        _notched(canvas, c, ring.radius, track);
        _arc(canvas, c, ring.radius, kNotchDegrees / 2, ring.day.fill * (360 - kNotchDegrees), stroke);
    }
  }

  /// Arc from 12 o'clock + [startDeg], clockwise by [sweepDeg].
  void _arc(Canvas canvas, Offset c, double r, double startDeg, double sweepDeg, Paint paint) {
    if (sweepDeg <= 0) return;
    final rect = Rect.fromCircle(center: c, radius: r);
    final start = kTop + startDeg * math.pi / 180;
    canvas.drawArc(rect, start, sweepDeg >= 360 ? 2 * math.pi : sweepDeg * math.pi / 180, false, paint);
  }

  /// The scar: a full ring with a [kNotchDegrees] gap centred on 12 o'clock.
  void _notched(Canvas canvas, Offset c, double r, Paint paint) =>
      _arc(canvas, c, r, kNotchDegrees / 2, 360 - kNotchDegrees, paint);

  /// Not checked in: a hollow dashed outline (2dp dash / 3dp gap).
  void _dashed(Canvas canvas, Offset c, double r, double s) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * s
      ..color = palette.hollow;
    final dash = (2.0 * s) / r;
    final period = (5.0 * s) / r;
    final count = (2 * math.pi / period).floor();
    final step = 2 * math.pi / count;
    final rect = Rect.fromCircle(center: c, radius: r);
    for (var i = 0; i < count; i++) {
      canvas.drawArc(rect, kTop + i * step, dash, false, paint);
    }
  }

  @override
  bool shouldRepaint(SlabPainter old) => old.data != data || old.person != person || old.palette != palette;
}
