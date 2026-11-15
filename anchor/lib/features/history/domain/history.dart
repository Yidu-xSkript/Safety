// Pure rules for the History tab. No Flutter imports.
import '../../../core/local_day.dart';
import '../../rings/ring_model.dart';
import '../../today/domain/streak.dart';

/// The cells of a month grid, row by row. Leading nulls push day 1 under the right weekday; trailing nulls
/// complete the last week. [firstWeekday] is the weekday of the first column (1 = Monday ... 7 = Sunday).
List<DateTime?> monthCells(DateTime anyDayInMonth, {required int firstWeekday}) {
  final first = dayOf(anyDayInMonth.year, anyDayInMonth.month, 1);
  final count = dayOf(anyDayInMonth.year, anyDayInMonth.month + 1, 0).day;
  final lead = (first.weekday - firstWeekday + 7) % 7;
  final cells = <DateTime?>[
    for (var i = 0; i < lead; i++) null,
    for (var d = 1; d <= count; d++) dayOf(first.year, first.month, d),
  ];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return cells;
}

DateTime monthStart(DateTime d) => dayOf(d.year, d.month, 1);

/// The longest run of consecutive `held` days between [since] and [until] inclusive.
/// A day with no check-in or a slip ends a run; a day that is still pending (today, no answer yet) is simply not counted.
int bestStreak(PledgeLookup pledgeOn, {required DateTime since, required DateTime until}) {
  var best = 0, run = 0;
  for (var d = since; !d.isAfter(until); d = addDays(d, 1)) {
    if (pledgeOn(d) == PledgeState.held) {
      run++;
      if (run > best) best = run;
    } else {
      run = 0;
    }
  }
  return best;
}

/// How many days in [month] were `held`, counting only days from [since] up to [until].
int daysHeldIn(PledgeLookup pledgeOn, DateTime month, {required DateTime since, required DateTime until}) {
  final start = monthStart(month);
  final end = dayOf(month.year, month.month + 1, 0);
  var n = 0;
  for (var d = start; !d.isAfter(end); d = addDays(d, 1)) {
    if (d.isBefore(since) || d.isAfter(until)) continue;
    if (pledgeOn(d) == PledgeState.held) n++;
  }
  return n;
}
