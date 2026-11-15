import 'package:anchor/core/local_day.dart';
import 'package:anchor/features/history/domain/history.dart';
import 'package:anchor/features/pod/domain/care.dart';
import 'package:anchor/features/rings/ring_model.dart';
import 'package:flutter_test/flutter_test.dart';

const H = PledgeState.held, S = PledgeState.slipped;

void main() {
  group('monthCells', () {
    test('November 2026 starts on a Sunday: Monday-first grid has six leading blanks', () {
      final cells = monthCells(dayOf(2026, 11, 14), firstWeekday: DateTime.monday);
      expect(cells.take(6), everyElement(isNull));
      expect(cells[6], dayOf(2026, 11, 1));
      expect(cells.whereType<DateTime>().length, 30);
      expect(cells.length % 7, 0);
    });

    test('Sunday-first grid for the same month has no leading blanks', () {
      final cells = monthCells(dayOf(2026, 11, 14), firstWeekday: DateTime.sunday);
      expect(cells.first, dayOf(2026, 11, 1));
      expect(cells.length, 35);
    });

    test('February in a leap year and a non-leap year', () {
      expect(monthCells(dayOf(2028, 2, 10), firstWeekday: DateTime.monday).whereType<DateTime>().length, 29);
      expect(monthCells(dayOf(2027, 2, 10), firstWeekday: DateTime.monday).whereType<DateTime>().length, 28);
    });

    test('a month that fills exactly four weeks has no padding at all (Feb 2027 starts on a Monday)', () {
      final cells = monthCells(dayOf(2027, 2, 1), firstWeekday: DateTime.monday);
      expect(cells.length, 28);
      expect(cells.every((c) => c != null), isTrue);
    });

    test('December rolls into the next year correctly', () {
      final cells = monthCells(dayOf(2026, 12, 31), firstWeekday: DateTime.monday).whereType<DateTime>().toList();
      expect(cells.first, dayOf(2026, 12, 1));
      expect(cells.last, dayOf(2026, 12, 31));
    });
  });

  group('best streak and days held', () {
    final since = dayOf(2026, 11, 1), until = dayOf(2026, 11, 14);
    PledgeState? Function(DateTime) days(Set<int> held, {Set<int> slipped = const {}}) =>
        (d) => held.contains(d.day) ? H : (slipped.contains(d.day) ? S : null);

    test('longest run, not the current one', () {
      expect(bestStreak(days({1, 2, 3, 4, 5, 8, 9}), since: since, until: until), 5);
    });
    test('a slip and a silent day both end a run', () {
      expect(bestStreak(days({1, 2, 4, 5, 6}, slipped: {3}), since: since, until: until), 3);
      expect(bestStreak(days({1, 2, 4, 5}), since: since, until: until), 2);
    });
    test('nothing held is zero', () => expect(bestStreak(days({}), since: since, until: until), 0));
    test('a pending today neither counts nor breaks the best', () {
      expect(bestStreak(days({10, 11, 12, 13}), since: since, until: until), 4);
    });

    test('days held this month ignores days before the start and after today', () {
      final lookup = days({1, 2, 3, 20, 21});
      expect(daysHeldIn(lookup, dayOf(2026, 11, 5), since: dayOf(2026, 11, 2), until: until), 2, reason: 'the 1st predates the start, the 20th is in the future');
      expect(daysHeldIn(lookup, dayOf(2026, 10, 5), since: since, until: until), 0, reason: 'another month');
    });
  });

  group('sync state', () {
    test('both checked in recently', () => expect(syncState(meToday: H, meYesterday: null, partnerToday: null, partnerYesterday: H), SyncState.inSync));
    test('the partner has not: waiting on them', () => expect(syncState(meToday: H, meYesterday: H, partnerToday: null, partnerYesterday: null), SyncState.waitingOnPartner));
    test('only I am missing: no chip, no scolding', () => expect(syncState(meToday: null, meYesterday: null, partnerToday: H, partnerYesterday: H), SyncState.none));
    test('a slip counts as having checked in', () => expect(syncState(meToday: S, meYesterday: null, partnerToday: S, partnerYesterday: null), SyncState.inSync));
  });

  group('hello (nudge)', () {
    final evening = DateTime(2026, 11, 14, 19), morning = DateTime(2026, 11, 14, 9);
    test('offered in the evening when they have not checked in', () => expect(nudgeAvailable(partnerToday: null, sentToday: false, now: evening), isTrue));
    test('not before 18:00', () => expect(nudgeAvailable(partnerToday: null, sentToday: false, now: morning), isFalse));
    test('not once they have checked in, held or slipped', () {
      expect(nudgeAvailable(partnerToday: H, sentToday: false, now: evening), isFalse);
      expect(nudgeAvailable(partnerToday: S, sentToday: false, now: evening), isFalse);
    });
    test('once a day', () => expect(nudgeAvailable(partnerToday: null, sentToday: true, now: evening), isFalse));
  });

  group('next reminder', () {
    test('later today when the time has not passed', () => expect(nextReminder(DateTime(2026, 11, 14, 12), 21, 30, skipToday: false), DateTime(2026, 11, 14, 21, 30)));
    test('tomorrow when it has', () => expect(nextReminder(DateTime(2026, 11, 14, 22), 21, 30, skipToday: false), DateTime(2026, 11, 15, 21, 30)));
    test('tomorrow when you already checked in today', () => expect(nextReminder(DateTime(2026, 11, 14, 12), 21, 30, skipToday: true), DateTime(2026, 11, 15, 21, 30)));
    test('skipping when it is already tomorrow changes nothing', () => expect(nextReminder(DateTime(2026, 11, 14, 22), 21, 30, skipToday: true), DateTime(2026, 11, 15, 21, 30)));
    test('month and year ends', () => expect(nextReminder(DateTime(2026, 12, 31, 23), 21, 30, skipToday: false), DateTime(2027, 1, 1, 21, 30)));
  });
}
