import 'package:anchor/features/urge/grounding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('breath', () {
    test('4 seconds in, 6 seconds out, repeating', () {
      final cases = {0: BreathPhase.inhale, 3: BreathPhase.inhale, 4: BreathPhase.exhale, 9: BreathPhase.exhale, 10: BreathPhase.inhale, 14: BreathPhase.exhale};
      cases.forEach((t, want) => expect(breathPhase(t), want, reason: 'at $t s'));
    });

    test('the ring grows over the in-breath and shrinks over the out-breath, smoothly', () {
      expect(breathScale(0), 0);
      expect(breathScale(4), closeTo(1, 1e-9));
      expect(breathScale(10), closeTo(0, 1e-9)); // the cycle closes where it began
      expect(breathScale(2), closeTo(0.5, 1e-9)); // symmetric around the middle of the in-breath
      for (var t = 0.0; t < 10; t += 0.25) {
        expect(breathScale(t), inInclusiveRange(0, 1));
        // no jumps: in 0.25 s the ring moves by at most a few percent of its range
        expect((breathScale(t + 0.25) - breathScale(t)).abs(), lessThan(0.25));
      }
    });
  });

  group('three minutes', () {
    test('one instruction per minute, the last one stays', () {
      final cases = {0: 0, 59: 0, 60: 1, 119: 1, 120: 2, 179: 2, 400: 2};
      cases.forEach((t, want) => expect(stepIndex(t), want, reason: 'at $t s'));
    });

    test('the countdown reads 3:00 down to 0:00 and stops', () {
      expect(countdown(0), '3:00');
      expect(countdown(1), '2:59');
      expect(countdown(60), '2:00');
      expect(countdown(179), '0:01');
      expect(countdown(180), '0:00');
      expect(countdown(500), '0:00');
    });

    test('it is done at exactly 180 seconds', () {
      expect(groundingDone(179), isFalse);
      expect(groundingDone(180), isTrue);
    });
  });
}
