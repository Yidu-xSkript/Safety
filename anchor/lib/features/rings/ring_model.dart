// Pure Dart: what a slab shows and where its rings sit. No Flutter imports, so it is table-testable.
// Spec: DESIGN.md → Shapes → "Signature: The Growth Ring".
import 'dart:math' as math;

enum PledgeState { held, slipped, unchecked }

/// One day: the pledge plus how many of that day's habits were done.
class DayRing {
  const DayRing({required this.pledge, required this.done, required this.total});

  final PledgeState pledge;
  final int done;
  final int total;

  /// 0..1. A day with no habits has fill 0 (and still draws a 2dp ring).
  double get fill => total <= 0 ? 0 : (done / total).clamp(0.0, 1.0);
}

/// Everything a slab needs. `lastDays` is oldest → newest, at most [kRingDays] completed days.
class SlabData {
  SlabData({required this.initial, required this.daysHeld, required List<DayRing> lastDays, required this.today})
      : lastDays = List.unmodifiable(lastDays.length > kRingDays ? lastDays.sublist(lastDays.length - kRingDays) : lastDays);

  final String initial;
  final int daysHeld;
  final List<DayRing> lastDays;
  final DayRing today;
}

const kRingDays = 7;

// Geometry at the base slab size (dp). Everything scales with diameter / kSlabBase.
const kSlabBase = 156.0;
const kHeartwoodRadius = 20.0;
const kRingGap = 1.5;
const kRingMinWidth = 2.0;
const kRingMaxWidth = 5.0;
const kTodayWidth = 5.0;
const kNotchDegrees = 14.0; // the scar on a slab ring
const kGlyphNotchDegrees = 50.0; // same idea, readable at 20dp

/// One ring's centre radius and stroke width, in dp at the *requested* diameter.
class RingStroke {
  const RingStroke({required this.radius, required this.width, required this.day, required this.isToday});

  final double radius;
  final double width;
  final DayRing day;
  final bool isToday;

  double get outer => radius + width / 2;
}

double ringWidth(double fill) => kRingMinWidth + (kRingMaxWidth - kRingMinWidth) * fill.clamp(0.0, 1.0);

/// Lays rings from the heartwood outward: past days oldest-first, then today outermost.
List<RingStroke> layoutRings(SlabData data, {double diameter = kSlabBase}) {
  final s = diameter / kSlabBase;
  final strokes = <RingStroke>[];
  var inner = (kHeartwoodRadius + kRingGap) * s;

  void add(DayRing day, double widthDp, {required bool isToday}) {
    final w = widthDp * s;
    strokes.add(RingStroke(radius: inner + w / 2, width: w, day: day, isToday: isToday));
    inner += w + kRingGap * s;
  }

  for (final d in data.lastDays) {
    add(d, ringWidth(d.fill), isToday: false);
  }
  add(data.today, kTodayWidth, isToday: true);
  return strokes;
}

/// Angle (radians, canvas convention, 0 = 3 o'clock) where a ring starts: 12 o'clock.
const kTop = -math.pi / 2;

/// Words for the semantics label. Localised by the caller.
enum RingWord { held, slipped, unchecked }

RingWord wordFor(PledgeState s) => switch (s) {
      PledgeState.held => RingWord.held,
      PledgeState.slipped => RingWord.slipped,
      PledgeState.unchecked => RingWord.unchecked,
    };
