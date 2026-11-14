// The three minutes after Urge is pressed, as pure rules: what second it is, what to say, how big the breath is.
import 'dart:math' as math;

const kGroundingSeconds = 180;
const kBreathInSeconds = 4;
const kBreathOutSeconds = 6;
const kBreathCycleSeconds = kBreathInSeconds + kBreathOutSeconds;

/// One instruction per minute, one at a time (Stand up -> Water -> Put the phone away).
const kStepCount = 3;

enum BreathPhase { inhale, exhale }

BreathPhase breathPhase(int elapsedSeconds) =>
    elapsedSeconds % kBreathCycleSeconds < kBreathInSeconds ? BreathPhase.inhale : BreathPhase.exhale;

/// Which instruction is showing: 0 for the first minute, 1 for the second, 2 from the third on.
int stepIndex(int elapsedSeconds) => math.min(elapsedSeconds ~/ 60, kStepCount - 1);

bool groundingDone(int elapsedSeconds) => elapsedSeconds >= kGroundingSeconds;

/// `3:00` counting down to `0:00`.
String countdown(int elapsedSeconds) {
  final left = math.max(0, kGroundingSeconds - elapsedSeconds);
  return '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
}

/// 0 (smallest) .. 1 (fullest) at [t] seconds into the session: 4 s in, 6 s out, eased at both ends so
/// the ring never jerks. Slow on purpose: nothing in a crisis state moves faster than a breath.
double breathScale(double t) {
  double ease(double x) => x * x * (3 - 2 * x); // smoothstep
  final c = t % kBreathCycleSeconds;
  return c < kBreathInSeconds ? ease(c / kBreathInSeconds) : 1 - ease((c - kBreathInSeconds) / kBreathOutSeconds);
}
