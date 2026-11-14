import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/local_day.dart';
import '../rings/demo_data.dart';
import '../rings/ring_model.dart';
import 'data/solo_store.dart';
import 'domain/models.dart';
import 'domain/streak.dart';
import 'domain/streak.dart' as rules show podStreak;

/// Overridden in tests to freeze time.
final clockProvider = Provider<DateTime Function()>((_) => DateTime.now);

class SoloState {
  const SoloState(this.data, this.today);

  final SoloData data;
  final DateTime today; // local day (04:00 rollover)

  SoloState copyWith({SoloData? data, DateTime? today}) => SoloState(data ?? this.data, today ?? this.today);

  CheckIn? get pledge => data.checkIns[dayKey(today)];
  ({int done, int total}) get habitsToday => data.countsOn(today);
  bool isTicked(Habit h) => (data.logs[dayKey(today)] ?? const {}).contains(h.id);
  List<Habit> get habits => data.habits.where((h) => h.activeOn(today)).toList();
}

class SoloController extends AsyncNotifier<SoloState> {
  late SoloStore _store;

  DateTime _now() => ref.read(clockProvider)();

  @override
  Future<SoloState> build() async {
    _store = SoloStore(await SharedPreferences.getInstance());
    return SoloState(_store.load(), localDate(_now()));
  }

  Future<void> _set(SoloData data) async {
    final cur = state.requireValue;
    state = AsyncData(cur.copyWith(data: data, today: localDate(_now())));
    await _store.save(data);
  }

  /// Call when the app resumes: the day may have rolled over while it was in the background.
  void refreshDay() {
    final cur = state.value;
    if (cur == null) return;
    final today = localDate(_now());
    if (today != cur.today) state = AsyncData(cur.copyWith(today: today));
  }

  Future<void> completeOnboarding(String name, List<String> habitTitles) {
    final today = localDate(_now());
    final stamp = _now().microsecondsSinceEpoch;
    return _set(state.requireValue.data.copyWith(
      name: name.trim(),
      onboarded: true,
      startDay: today,
      habits: [
        for (var i = 0; i < habitTitles.length; i++)
          Habit(id: 'h$stamp-$i', title: habitTitles[i].trim(), createdDay: today),
      ],
    ));
  }

  Future<void> toggleHabit(Habit h) {
    final d = state.requireValue.data;
    final key = dayKey(localDate(_now()));
    final ticked = {...(d.logs[key] ?? const <String>{})};
    ticked.contains(h.id) ? ticked.remove(h.id) : ticked.add(h.id);
    return _set(d.copyWith(logs: {...d.logs, key: ticked}));
  }

  /// Today's pledge. Replaces an earlier answer from the same day; past days are never touched.
  Future<void> setPledge(PledgeState state_, {String? note}) {
    assert(state_ != PledgeState.unchecked, 'silence is not stored');
    final d = state.requireValue.data;
    final now = _now();
    final n = note?.trim();
    return _set(d.copyWith(checkIns: {
      ...d.checkIns,
      dayKey(localDate(now)): CheckIn(state: state_, at: now, note: n == null || n.isEmpty ? null : n),
    }));
  }
}

final soloProvider = AsyncNotifierProvider<SoloController, SoloState>(SoloController.new);

/// What the Today screen draws, derived from [SoloState].
class TodayView {
  TodayView(SoloState s)
      : name = s.data.name,
        you = s.data.slab(s.today),
        partner = demoPartnerSlab(s.today),
        podStreak = rules.podStreak(
          s.data.pledgeOn,
          (d) => demoPartnerPledgeOn(s.today, d),
          today: s.today,
          since: s.data.startDay ?? s.today,
        ),
        today = s.today,
        week = [
          for (var i = 6; i >= 0; i--)
            (
              day: addDays(s.today, -i),
              you: (!addDays(s.today, -i).isBefore(s.data.startDay ?? s.today))
                  ? (s.data.pledgeOn(addDays(s.today, -i)) ?? PledgeState.unchecked)
                  : null,
              partner: demoPartnerPledgeOn(s.today, addDays(s.today, -i)) ?? PledgeState.unchecked,
            ),
        ];

  final String name;
  final SlabData you;
  final SlabData partner;
  final int podStreak;
  final DateTime today;

  /// Seven days ending today. `you` is null for days before the user started (nothing to show).
  final List<({DateTime day, PledgeState? you, PledgeState partner})> week;
}

final todayViewProvider = Provider<TodayView?>((ref) {
  final s = ref.watch(soloProvider).value;
  return s == null ? null : TodayView(s);
});
