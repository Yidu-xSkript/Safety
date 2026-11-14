import 'package:anchor/features/rings/ring_model.dart';
import 'package:flutter_test/flutter_test.dart';

DayRing d(int done, int total, [PledgeState p = PledgeState.held]) => DayRing(pledge: p, done: done, total: total);

SlabData slab(List<DayRing> days, {DayRing? today}) => SlabData(
      initial: 'M',
      daysHeld: 3,
      lastDays: days,
      today: today ?? d(0, 4, PledgeState.unchecked),
    );

void main() {
  group('DayRing.fill', () {
    for (final (done, total, want) in [(0, 4, 0.0), (1, 4, 0.25), (4, 4, 1.0), (0, 0, 0.0), (9, 4, 1.0)]) {
      test('$done of $total -> $want', () => expect(d(done, total).fill, want));
    }
  });

  test('ring width runs from 2dp (nothing done) to 5dp (all done)', () {
    expect(ringWidth(0), kRingMinWidth);
    expect(ringWidth(1), kRingMaxWidth);
    expect(ringWidth(0.5), closeTo(3.5, 1e-9));
    expect(ringWidth(7), kRingMaxWidth); // clamped
  });

  group('layoutRings', () {
    test('worst case (7 full days + today) still fits inside the base slab', () {
      final strokes = layoutRings(slab(List.generate(7, (_) => d(4, 4)), today: d(4, 4)));
      expect(strokes.length, 8);
      expect(strokes.last.outer, lessThanOrEqualTo(kSlabBase / 2));
    });

    test('rings never overlap: each starts at least one gap past the previous', () {
      final strokes = layoutRings(slab([d(4, 4), d(0, 4), d(2, 4), d(4, 4)], today: d(1, 4)));
      for (var i = 1; i < strokes.length; i++) {
        final prevOuter = strokes[i - 1].outer;
        final innerEdge = strokes[i].radius - strokes[i].width / 2;
        expect(innerEdge - prevOuter, closeTo(kRingGap, 1e-9));
      }
      expect(strokes.first.radius - strokes.first.width / 2, greaterThan(kHeartwoodRadius));
    });

    test('today is last and the only today ring; past rings run oldest to newest', () {
      final strokes = layoutRings(slab([d(1, 4), d(4, 4)]));
      expect(strokes.map((s) => s.isToday), [false, false, true]);
      expect(strokes[0].width, lessThan(strokes[1].width));
    });

    test('a new tree has only today ring', () {
      expect(layoutRings(slab([])).length, 1);
    });

    test('geometry scales linearly with diameter', () {
      final data = slab([d(4, 4), d(2, 4)]);
      final big = layoutRings(data);
      final small = layoutRings(data, diameter: kSlabBase / 2);
      for (var i = 0; i < big.length; i++) {
        expect(small[i].radius, closeTo(big[i].radius / 2, 1e-9));
        expect(small[i].width, closeTo(big[i].width / 2, 1e-9));
      }
    });
  });

  test('SlabData keeps only the newest seven days', () {
    final days = [for (var i = 0; i < 10; i++) d(i % 5, 4)];
    final data = slab(days);
    expect(data.lastDays.length, kRingDays);
    expect(data.lastDays.first.done, days[3].done);
    expect(data.lastDays.last.done, days.last.done);
  });

  test('each pledge state has its own word (state is never colour alone)', () {
    expect({for (final s in PledgeState.values) wordFor(s)}.length, PledgeState.values.length);
  });
}
