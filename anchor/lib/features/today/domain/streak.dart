// Pure rules (docs/ARCHITECTURE.md → Domain rules). One implementation, unit-tested, works offline.
import '../../../core/local_day.dart';
import '../../rings/ring_model.dart';
import 'models.dart';

typedef PledgeLookup = PledgeState? Function(DateTime day);

/// Consecutive `held` days ending today, or yesterday when today is still pending.
///
/// - Today with no check-in is *pending*: it neither counts nor breaks.
/// - A `slipped` day, or a past day with no check-in (closed unchecked), ends the run.
/// - Days before [since] did not happen and are never read.
int streak(PledgeLookup pledgeOn, {required DateTime today, required DateTime since}) {
  var day = today;
  final t = pledgeOn(today);
  if (t == null || t == PledgeState.unchecked) {
    day = addDays(today, -1);
  } else if (t == PledgeState.slipped) {
    return 0;
  }
  var count = 0;
  while (!day.isBefore(since) && pledgeOn(day) == PledgeState.held) {
    count++;
    day = addDays(day, -1);
  }
  return count;
}

/// Days on which *both* people held. A slip by either ends the run; either person's silence on a past day does too.
int podStreak(PledgeLookup a, PledgeLookup b, {required DateTime today, required DateTime since}) {
  PledgeState? both(DateTime d) {
    final x = a(d), y = b(d);
    if (x == PledgeState.slipped || y == PledgeState.slipped) return PledgeState.slipped;
    if (x == PledgeState.held && y == PledgeState.held) return PledgeState.held;
    return null;
  }

  return streak(both, today: today, since: since);
}

/// Builds the slab: last seven completed days (those since [since]), today outermost, streak as the day count.
SlabData buildSlab({
  required String initial,
  required DateTime today,
  required DateTime since,
  required PledgeLookup pledgeOn,
  required ({int done, int total}) Function(DateTime day) countsOn,
}) {
  DayRing ring(DateTime d) {
    final c = countsOn(d);
    return DayRing(pledge: pledgeOn(d) ?? PledgeState.unchecked, done: c.done, total: c.total);
  }

  return SlabData(
    initial: initial,
    daysHeld: streak(pledgeOn, today: today, since: since),
    lastDays: [
      for (var i = kRingDays; i >= 1; i--)
        if (!addDays(today, -i).isBefore(since)) ring(addDays(today, -i)),
    ],
    today: ring(today),
  );
}

extension SoloSlab on SoloData {
  SlabData slab(DateTime today) => buildSlab(
        initial: name.isEmpty ? '·' : String.fromCharCode(name.runes.first).toUpperCase(),
        today: today,
        since: startDay ?? today,
        pledgeOn: pledgeOn,
        countsOn: countsOn,
      );
}
