// SYNTHETIC demo data (Mika and Teo are not real people). Phase 0/1 only; replaced by the repository in Phase 2.
import 'ring_model.dart';

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
