import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'ring_model.dart';
import 'slab_painter.dart';

String ringWordText(AppLocalizations l, PledgeState s) => switch (s) {
      PledgeState.held => l.ringStateHeld,
      PledgeState.slipped => l.ringStateSlipped,
      PledgeState.unchecked => l.ringStateUnchecked,
    };

/// A person's tree slab. One semantic label carries the whole picture; the paint is decorative.
class Slab extends StatelessWidget {
  const Slab({super.key, required this.name, required this.data, required this.person, this.diameter = kSlabBase});

  final String name;
  final SlabData data;
  final Person person;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final palette = context.palette;
    final today = data.today;
    final pledge = ringWordText(l, today.pledge);
    final label = data.lastDays.isEmpty
        ? l.slabSemanticsNoHistory(name, data.daysHeld, today.done, today.total, pledge)
        : l.slabSemantics(
            name,
            data.daysHeld,
            today.done,
            today.total,
            pledge,
            data.lastDays.map((d) => ringWordText(l, d.pledge)).join(', '),
          );
    final s = diameter / kSlabBase;

    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(diameter),
                painter: SlabPainter(data: data, person: person, palette: palette),
              ),
              Text(
                data.initial,
                textScaler: TextScaler.noScaling, // sits inside a fixed-size heartwood
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: palette.onDeep, fontSize: 18 * s),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glyph for lists and the heatmap: the same three states as a ring, at 20dp by default.
class RingGlyph extends StatelessWidget {
  const RingGlyph({super.key, required this.state, required this.person, this.size = 20});

  final PledgeState state;
  final Person person;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      label: ringWordText(l, state),
      image: true,
      child: ExcludeSemantics(
        child: CustomPaint(
          size: Size.square(size),
          painter: GlyphPainter(state: state, person: person, palette: context.palette),
        ),
      ),
    );
  }
}

// Kept beside RingGlyph so the shape language lives in one place.
class GlyphPainter extends CustomPainter {
  GlyphPainter({required this.state, required this.person, required this.palette});

  final PledgeState state;
  final Person person;
  final AnchorPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 1; // 1dp margin for the hairline
    final hue = personColor(palette, person);
    switch (state) {
      case PledgeState.held:
        canvas.drawCircle(c, r, Paint()..color = hue);
      case PledgeState.slipped:
        // Frost disc with a wedge removed at 12 o'clock.
        final notch = kGlyphNotchDegrees * math.pi / 180;
        final path = Path()
          ..moveTo(c.dx, c.dy)
          ..arcTo(Rect.fromCircle(center: c, radius: r), kTop + notch / 2, 2 * math.pi - notch, false)
          ..close();
        canvas.drawPath(path, Paint()..color = palette.frost);
      case PledgeState.unchecked:
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.75
          ..color = palette.hollow;
        final dash = 3.0 / r, period = 6.0 / r; // longer dashes than the slab: legible at 20dp
        final count = (2 * math.pi / period).floor();
        final step = 2 * math.pi / count;
        final rect = Rect.fromCircle(center: c, radius: r - 0.75);
        for (var i = 0; i < count; i++) {
          canvas.drawArc(rect, kTop + i * step, dash, false, paint);
        }
    }
  }

  @override
  bool shouldRepaint(GlyphPainter old) => old.state != state || old.person != person || old.palette != palette;
}
