// SYNTHETIC demo data (Mika and Teo are not real people). Phase 0/1 only; replaced by the repository in Phase 2.
import '../../core/local_day.dart';
import '../today/domain/streak.dart';
import 'ring_model.dart';

/// Phase 1 stand-in partner: held every day for 22 days, relative to whatever "today" is.
const kDemoPartnerName = 'Teo';
const _demoPartnerDays = 21; // held on each of the 21 days before today and today itself: a 22-day streak

DateTime demoPartnerSince(DateTime today) => addDays(today, -_demoPartnerDays);

PledgeState? demoPartnerPledgeOn(DateTime today, DateTime day) =>
    day.isAfter(today) || day.isBefore(demoPartnerSince(today)) ? null : PledgeState.held;

SlabData demoPartnerSlab(DateTime today) => buildSlab(
      initial: kDemoPartnerName[0],
      today: today,
      since: demoPartnerSince(today),
      pledgeOn: (d) => demoPartnerPledgeOn(today, d),
      countsOn: (d) => (done: 2 + d.day % 3, total: 4),
    );

const _h = PledgeState.held;

DayRing _day(int done, [PledgeState p = _h]) => DayRing(pledge: p, done: done, total: 4);

final demoYou = SlabData(
  initial: 'M',
  daysHeld: 14,
  lastDays: [_day(4), _day(3), _day(4), _day(4), _day(2), _day(4), _day(3)],
  today: const DayRing(pledge: PledgeState.unchecked, done: 3, total: 4),
);

final demoPartner = SlabData(
  initial: 'T',
  daysHeld: 22,
  lastDays: [_day(4), _day(4), _day(3), _day(4), _day(4), _day(1), _day(4)],
  today: const DayRing(pledge: PledgeState.held, done: 2, total: 4),
);
