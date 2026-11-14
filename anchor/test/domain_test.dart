import 'dart:convert';

import 'package:anchor/core/local_day.dart';
import 'package:anchor/features/rings/ring_model.dart';
import 'package:anchor/features/today/domain/models.dart';
import 'package:anchor/features/today/domain/streak.dart';
import 'package:flutter_test/flutter_test.dart';

const H = PledgeState.held, S = PledgeState.slipped;
final today = dayOf(2026, 11, 14);

/// Lookup from offsets (0 = today, -1 = yesterday, ...). Missing = no check-in. Reading a day before
/// [since] fails the test: those days did not happen and must never be consulted.
PledgeLookup lookup(Map<int, PledgeState> m, {int? since}) => (d) {
      final off = d.difference(today).inDays;
      if (since != null) expect(off, greaterThanOrEqualTo(since), reason: 'read a day before the start');
      return m[off];
    };

int run(Map<int, PledgeState> m, {int since = -30}) =>
    streak(lookup(m, since: since), today: today, since: addDays(today, since));

void main() {
  group('local day (04:00 rollover)', () {
    final cases = <(String, DateTime, DateTime)>[
      ('noon', DateTime(2026, 11, 14, 12), dayOf(2026, 11, 14)),
      ('04:00 sharp is the new day', DateTime(2026, 11, 14, 4), dayOf(2026, 11, 14)),
      ('03:59 still belongs to yesterday', DateTime(2026, 11, 14, 3, 59), dayOf(2026, 11, 13)),
      ('01:30 urge is last evening', DateTime(2026, 11, 14, 1, 30), dayOf(2026, 11, 13)),
      ('00:00 is yesterday', DateTime(2026, 11, 14), dayOf(2026, 11, 13)),
      ('23:59 is the same day', DateTime(2026, 11, 14, 23, 59), dayOf(2026, 11, 14)),
      ('crosses month', DateTime(2026, 12, 1, 2), dayOf(2026, 11, 30)),
      ('crosses year', DateTime(2027, 1, 1, 2), dayOf(2026, 12, 31)),
    ];
    for (final (name, now, want) in cases) {
      test(name, () => expect(localDate(now), want));
    }
    test('addDays and day keys round-trip across month ends', () {
      expect(addDays(dayOf(2026, 3, 1), -1), dayOf(2026, 2, 28));
      expect(addDays(dayOf(2028, 3, 1), -1), dayOf(2028, 2, 29)); // leap year
      expect(dayKey(dayOf(2026, 1, 5)), '2026-01-05');
      expect(parseDayKey('2026-01-05'), dayOf(2026, 1, 5));
    });
  });

  group('streak', () {
    test('held every day through today', () => expect(run({0: H, -1: H, -2: H, -3: H, -4: H}), 5));
    test('today pending does not break or count', () => expect(run({-1: H, -2: H, -3: H}), 3));
    test('today unchecked explicitly is pending too', () {
      final n = streak((d) => d == today ? PledgeState.unchecked : (d == addDays(today, -1) ? H : null),
          today: today, since: addDays(today, -30));
      expect(n, 1);
    });
    test('yesterday silent and today pending: the run is over', () => expect(run({-2: H, -3: H}), 0));
    test('slipped today is 0 whatever came before', () => expect(run({0: S, -1: H, -2: H}), 0));
    test('slipped yesterday then held today is 1', () => expect(run({0: H, -1: S, -2: H, -3: H}), 1));
    test('a slip in the middle ends the run at the newer side', () => expect(run({0: H, -1: H, -2: S, -3: H}), 2));
    test('a closed silent day ends the run (silence is not a slip, but it is not held)', () {
      expect(run({0: H, -1: H, -3: H, -4: H}), 2);
    });
    test('does not read days before the start, and the run stops there', () {
      expect(run({0: H, -1: H, -2: H}, since: -2), 3);
    });
    test('first day, nothing yet', () => expect(run({}, since: 0), 0));
    test('first day, held', () => expect(run({0: H}, since: 0), 1));
  });

  group('pod streak', () {
    int pod(Map<int, PledgeState> a, Map<int, PledgeState> b) =>
        podStreak(lookup(a), lookup(b), today: today, since: addDays(today, -30));

    test('both held three days', () => expect(pod({0: H, -1: H, -2: H}, {0: H, -1: H, -2: H}), 3));
    test('partner pending today: counts from yesterday', () => expect(pod({0: H, -1: H, -2: H}, {-1: H, -2: H}), 2));
    test('a slip by either person ends it', () {
      expect(pod({0: H, -1: H, -2: H}, {0: H, -1: S, -2: H}), 1);
      expect(pod({0: H, -1: S, -2: H}, {0: H, -1: H, -2: H}), 1);
    });
    test('slipped today by either person is 0', () => expect(pod({0: H, -1: H}, {0: S, -1: H}), 0));
    test('one person silent on a past day ends it', () => expect(pod({0: H, -1: H, -2: H}, {0: H, -2: H}), 1));
    test('never longer than the shorter run', () => expect(pod({0: H, -1: H, -2: H, -3: H}, {0: H, -1: H}), 2));
  });

  group('buildSlab', () {
    SlabData slab(Map<int, PledgeState> m, {required int since, Map<int, int>? done}) => buildSlab(
          initial: 'M',
          today: today,
          since: addDays(today, since),
          pledgeOn: lookup(m, since: since),
          countsOn: (d) => (done: done?[d.difference(today).inDays] ?? 0, total: 4),
        );

    test('a brand-new user has no past rings, only today', () {
      final s = slab({}, since: 0);
      expect(s.lastDays, isEmpty);
      expect(s.today.pledge, PledgeState.unchecked);
      expect(s.daysHeld, 0);
    });

    test('only days since the start become rings, oldest first, silence shown as unchecked', () {
      final s = slab({-3: H, -1: S, 0: H}, since: -3, done: {-3: 4, -2: 1, -1: 2, 0: 3});
      expect(s.lastDays.map((r) => r.pledge), [H, PledgeState.unchecked, S]);
      expect(s.lastDays.map((r) => r.done), [4, 1, 2]);
      expect(s.today.pledge, H);
      expect(s.today.done, 3);
    });

    test('caps at seven completed days', () {
      final s = slab({for (var i = -20; i <= 0; i++) i: H}, since: -20);
      expect(s.lastDays.length, kRingDays);
      expect(s.daysHeld, 21);
    });
  });

  group('habits and counts', () {
    final h1 = Habit(id: 'a', title: 'Reading', createdDay: dayOf(2026, 11, 1));
    final h2 = Habit(id: 'b', title: 'Workout', createdDay: dayOf(2026, 11, 10), archivedDay: dayOf(2026, 11, 12));

    SoloData data() => SoloData(
          habits: [h1, h2],
          logs: {
            '2026-11-09': {'a'},
            '2026-11-11': {'a', 'b'},
            '2026-11-13': {'a', 'b'}, // b was archived on the 12th: a stale tick must not count
          },
        );

    test('a habit created later does not change earlier days', () {
      expect(data().countsOn(dayOf(2026, 11, 9)), (done: 1, total: 1));
    });
    test('archiving keeps the past exactly as it was', () {
      expect(data().countsOn(dayOf(2026, 11, 11)), (done: 2, total: 2));
    });
    test('after archival the habit is gone from totals and ticks', () {
      expect(data().countsOn(dayOf(2026, 11, 13)), (done: 1, total: 1));
    });
    test('day with no habits is 0 of 0 (the ring still draws at minimum width)', () {
      expect(const SoloData().countsOn(today), (done: 0, total: 0));
      expect(const DayRing(pledge: H, done: 0, total: 0).fill, 0);
    });
  });

  test('SoloData survives a JSON round trip, including notes, ticks and archived habits', () {
    final d = SoloData(
      name: 'Mika',
      onboarded: true,
      startDay: dayOf(2026, 11, 1),
      habits: [
        Habit(id: 'a', title: 'Reading', createdDay: dayOf(2026, 11, 1), archivedDay: dayOf(2026, 11, 8)),
      ],
      checkIns: {'2026-11-02': CheckIn(state: S, at: DateTime.utc(2026, 11, 2, 21, 30), note: 'Hard night')},
      logs: {'2026-11-02': {'a'}},
    );
    final back = SoloData.fromJson(jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>);
    expect(jsonEncode(back.toJson()), jsonEncode(d.toJson()));
    expect(back.habits.single.archivedDay, dayOf(2026, 11, 8));
    expect(back.checkIns['2026-11-02']!.note, 'Hard night');
  });
}
