import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backend/pod_backend.dart';
import '../../core/kv.dart';
import '../../core/local_day.dart';
import '../../core/uuid.dart';
import '../pod/pod_controller.dart';
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
    _store = SoloStore(await ref.watch(kvProvider.future));
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
    return _set(state.requireValue.data.copyWith(
      name: name.trim(),
      onboarded: true,
      startDay: today,
      habits: [
        for (var i = 0; i < habitTitles.length; i++)
          Habit(id: newUuid(), title: habitTitles[i].trim(), createdDay: today),
      ],
    ));
  }

  Future<void> toggleHabit(Habit h) {
    final d = state.requireValue.data;
    final key = dayKey(localDate(_now()));
    final ticked = {...(d.logs[key] ?? const <String>{})};
    final on = !ticked.contains(h.id);
    on ? ticked.add(h.id) : ticked.remove(h.id);
    final day = localDate(_now());
    final saved = _set(d.copyWith(logs: {...d.logs, key: ticked}));
    ref.read(podProvider.notifier).record((pod) => TickOp(podId: pod, habitId: h.id, day: day, on: on));
    return saved;
  }

  /// Today's pledge. Replaces an earlier answer from the same day; past days are never touched.
  Future<void> setPledge(PledgeState state_, {String? note}) {
    assert(state_ != PledgeState.unchecked, 'silence is not stored');
    final d = state.requireValue.data;
    final now = _now();
    final n = note?.trim();
    final cleaned = n == null || n.isEmpty ? null : n;
    final day = localDate(now);
    final saved = _set(d.copyWith(checkIns: {...d.checkIns, dayKey(day): CheckIn(state: state_, at: now, note: cleaned)}));
    ref.read(podProvider.notifier).record((pod) => CheckInOp(podId: pod, day: day, state: state_, note: cleaned));
    return saved;
  }

  /// When a pod becomes active: give every habit a real UUID (the server's key), then list what to upload.
  /// Only today and yesterday go up; the server rejects older days, so earlier solo history stays on this phone.
  Future<List<SyncOp>> prepareBackfill(String podId) async {
    var d = state.requireValue.data;
    final remap = {for (final h in d.habits) if (!isUuid(h.id)) h.id: newUuid()};
    if (remap.isNotEmpty) {
      d = d.copyWith(
        habits: [
          for (final h in d.habits)
            Habit(id: remap[h.id] ?? h.id, title: h.title, createdDay: h.createdDay, archivedDay: h.archivedDay),
        ],
        logs: {for (final e in d.logs.entries) e.key: {for (final id in e.value) remap[id] ?? id}},
      );
      await _set(d);
    }
    final today = localDate(_now());
    return [
      for (final h in d.habits)
        HabitOp(podId: podId, id: h.id, title: h.title, createdDay: h.createdDay, archivedDay: h.archivedDay),
      for (final day in [addDays(today, -1), today]) ...[
        if (d.checkIns[dayKey(day)] case final c?) CheckInOp(podId: podId, day: day, state: c.state, note: c.note),
        for (final id in d.logs[dayKey(day)] ?? const <String>{}) TickOp(podId: podId, habitId: id, day: day, on: true),
      ],
    ];
  }
}

final soloProvider = AsyncNotifierProvider<SoloController, SoloState>(SoloController.new);

/// What the Today screen draws, derived from our data plus the partner's cached data.
class TodayView {
  TodayView(SoloState s, PodState? pod)
      : name = s.data.name,
        partnerName = pod?.pod?.partnerName ?? '',
        you = s.data.slab(s.today),
        partner = (pod?.partner ?? const SoloData()).copyWith(name: pod?.pod?.partnerName ?? '').slab(s.today),
        today = s.today,
        podStreak = rules.podStreak(
          s.data.pledgeOn,
          (pod?.partner ?? const SoloData()).pledgeOn,
          today: s.today,
          since: _later(s.data.startDay ?? s.today, pod?.partner?.startDay ?? s.today),
        ),
        week = _week(s.today, s.data, pod?.partner ?? const SoloData());

  static DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  static List<({DateTime day, PledgeState? you, PledgeState? partner})> _week(DateTime today, SoloData me, SoloData them) {
    PledgeState? on(SoloData d, DateTime day) =>
        day.isBefore(d.startDay ?? today) ? null : (d.pledgeOn(day) ?? PledgeState.unchecked);
    return [
      for (var i = 6; i >= 0; i--) (day: addDays(today, -i), you: on(me, addDays(today, -i)), partner: on(them, addDays(today, -i))),
    ];
  }

  final String name;
  final String partnerName;
  final SlabData you;
  final SlabData partner;
  final int podStreak;
  final DateTime today;

  /// Seven days ending today. A null means that person had not started yet (nothing to show, not "unchecked").
  final List<({DateTime day, PledgeState? you, PledgeState? partner})> week;
}

final todayViewProvider = Provider<TodayView?>((ref) {
  final s = ref.watch(soloProvider).value;
  if (s == null) return null;
  return TodayView(s, ref.watch(podProvider).value);
});
