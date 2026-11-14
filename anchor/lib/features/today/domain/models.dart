import '../../../core/local_day.dart';
import '../../rings/ring_model.dart';

class Habit {
  const Habit({required this.id, required this.title, required this.createdDay, this.archivedDay});

  final String id;
  final String title;
  final DateTime createdDay;
  final DateTime? archivedDay;

  /// Archiving never reshapes the past: a habit counts on every day from creation up to (not including) archival.
  bool activeOn(DateTime day) =>
      !day.isBefore(createdDay) && (archivedDay == null || day.isBefore(archivedDay!));

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'created': dayKey(createdDay),
        if (archivedDay != null) 'archived': dayKey(archivedDay!),
      };

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'] as String,
        title: j['title'] as String,
        createdDay: parseDayKey(j['created'] as String),
        archivedDay: j['archived'] == null ? null : parseDayKey(j['archived'] as String),
      );
}

/// The daily pledge. Only `held` and `slipped` are ever stored: silence is "unchecked", not a slip.
class CheckIn {
  const CheckIn({required this.state, required this.at, this.note});

  final PledgeState state;
  final DateTime at;
  final String? note;

  Map<String, Object?> toJson() => {'state': state.name, 'at': at.toIso8601String(), if (note != null) 'note': note};

  factory CheckIn.fromJson(Map<String, dynamic> j) => CheckIn(
        state: PledgeState.values.byName(j['state'] as String),
        at: DateTime.parse(j['at'] as String),
        note: j['note'] as String?,
      );
}

/// Everything the solo loop stores. Phase 2 moves this to Supabase.
class SoloData {
  const SoloData({
    this.name = '',
    this.onboarded = false,
    this.startDay,
    this.habits = const [],
    this.checkIns = const {},
    this.logs = const {},
  });

  final String name;
  final bool onboarded;

  /// First day with any record. Days before it are not "unchecked", they simply did not happen.
  final DateTime? startDay;
  final List<Habit> habits;
  final Map<String, CheckIn> checkIns; // by dayKey
  final Map<String, Set<String>> logs; // dayKey -> ids of habits ticked that day

  SoloData copyWith({
    String? name,
    bool? onboarded,
    DateTime? startDay,
    List<Habit>? habits,
    Map<String, CheckIn>? checkIns,
    Map<String, Set<String>>? logs,
  }) =>
      SoloData(
        name: name ?? this.name,
        onboarded: onboarded ?? this.onboarded,
        startDay: startDay ?? this.startDay,
        habits: habits ?? this.habits,
        checkIns: checkIns ?? this.checkIns,
        logs: logs ?? this.logs,
      );

  PledgeState? pledgeOn(DateTime day) => checkIns[dayKey(day)]?.state;

  /// Habits ticked vs habits that existed on [day].
  ({int done, int total}) countsOn(DateTime day) {
    final active = habits.where((h) => h.activeOn(day));
    final ticked = logs[dayKey(day)] ?? const <String>{};
    return (done: active.where((h) => ticked.contains(h.id)).length, total: active.length);
  }

  Map<String, Object?> toJson() => {
        'name': name,
        'onboarded': onboarded,
        if (startDay != null) 'start': dayKey(startDay!),
        'habits': [for (final h in habits) h.toJson()],
        'checkIns': {for (final e in checkIns.entries) e.key: e.value.toJson()},
        'logs': {for (final e in logs.entries) e.key: e.value.toList()},
      };

  factory SoloData.fromJson(Map<String, dynamic> j) => SoloData(
        name: j['name'] as String? ?? '',
        onboarded: j['onboarded'] as bool? ?? false,
        startDay: j['start'] == null ? null : parseDayKey(j['start'] as String),
        habits: [for (final h in (j['habits'] as List? ?? const [])) Habit.fromJson(h as Map<String, dynamic>)],
        checkIns: {
          for (final e in (j['checkIns'] as Map? ?? const {}).entries)
            e.key as String: CheckIn.fromJson(e.value as Map<String, dynamic>),
        },
        logs: {
          for (final e in (j['logs'] as Map? ?? const {}).entries)
            e.key as String: {for (final id in e.value as List) id as String},
        },
      );
}
