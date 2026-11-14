// What the app needs from a server, and nothing about how it is reached. Supabase implements it for
// real; tests implement it in memory. UI and controllers only ever see this file.
import '../../features/rings/ring_model.dart';
import '../../features/today/domain/models.dart';
import '../local_day.dart';

enum PodStatus { open, active, archived }

class PodInfo {
  const PodInfo({required this.podId, required this.status, this.inviteCode, this.inviteExpiresAt, this.partnerId, this.partnerName});

  final String podId;
  final PodStatus status;
  final String? inviteCode;
  final DateTime? inviteExpiresAt;
  final String? partnerId;
  final String? partnerName;

  bool get active => status == PodStatus.active;

  Map<String, Object?> toJson() => {
        'podId': podId,
        'status': status.name,
        'code': inviteCode,
        'expires': inviteExpiresAt?.toIso8601String(),
        'partnerId': partnerId,
        'partnerName': partnerName,
      };

  factory PodInfo.fromJson(Map<String, dynamic> j) => PodInfo(
        podId: j['podId'] as String,
        status: PodStatus.values.byName(j['status'] as String),
        inviteCode: j['code'] as String?,
        inviteExpiresAt: j['expires'] == null ? null : DateTime.parse(j['expires'] as String),
        partnerId: j['partnerId'] as String?,
        partnerName: j['partnerName'] as String?,
      );
}

enum PodErrorKind { alreadyInPod, invalidCode, tooManyAttempts, offline, notConfigured, other }

/// Every failure the UI can show, already sorted. Anything unrecognised is [PodErrorKind.other].
class PodError implements Exception {
  const PodError(this.kind);

  final PodErrorKind kind;

  @override
  String toString() => 'PodError($kind)';
}

/// A change made on this phone that the server must hear about. Idempotent by design, so a replay is
/// harmless; [key] lets a newer op replace an older pending one for the same thing.
sealed class SyncOp {
  const SyncOp();

  String get key;
  Map<String, Object?> toJson();

  factory SyncOp.fromJson(Map<String, dynamic> j) => switch (j['type']) {
        'checkIn' => CheckInOp(
            podId: j['pod'] as String,
            day: parseDayKey(j['day'] as String),
            state: PledgeState.values.byName(j['state'] as String),
            note: j['note'] as String?,
          ),
        'habit' => HabitOp(
            podId: j['pod'] as String,
            id: j['id'] as String,
            title: j['title'] as String,
            createdDay: parseDayKey(j['created'] as String),
            archivedDay: j['archived'] == null ? null : parseDayKey(j['archived'] as String),
          ),
        'tick' => TickOp(podId: j['pod'] as String, habitId: j['habit'] as String, day: parseDayKey(j['day'] as String), on: j['on'] as bool),
        _ => throw FormatException('unknown op ${j['type']}'),
      };
}

class CheckInOp extends SyncOp {
  const CheckInOp({required this.podId, required this.day, required this.state, this.note});

  final String podId;
  final DateTime day;
  final PledgeState state;
  final String? note;

  @override
  String get key => 'ci:$podId:${dayKey(day)}';

  @override
  Map<String, Object?> toJson() => {'type': 'checkIn', 'pod': podId, 'day': dayKey(day), 'state': state.name, 'note': note};
}

class HabitOp extends SyncOp {
  const HabitOp({required this.podId, required this.id, required this.title, required this.createdDay, this.archivedDay});

  final String podId;
  final String id;
  final String title;
  final DateTime createdDay;
  final DateTime? archivedDay;

  @override
  String get key => 'h:$id';

  @override
  Map<String, Object?> toJson() => {
        'type': 'habit',
        'pod': podId,
        'id': id,
        'title': title,
        'created': dayKey(createdDay),
        'archived': archivedDay == null ? null : dayKey(archivedDay!),
      };
}

class TickOp extends SyncOp {
  const TickOp({required this.podId, required this.habitId, required this.day, required this.on});

  final String podId;
  final String habitId;
  final DateTime day;
  final bool on;

  @override
  String get key => 't:$habitId:${dayKey(day)}';

  @override
  Map<String, Object?> toJson() => {'type': 'tick', 'pod': podId, 'habit': habitId, 'day': dayKey(day), 'on': on};
}

abstract class PodBackend {
  /// False when no server is configured (a bare `flutter run`). Pairing then fails with [PodErrorKind.notConfigured].
  bool get configured;

  /// Anonymous session, created on first use and kept.
  Future<void> ensureSignedIn();
  Future<void> setProfile(String name, int utcOffsetMin);

  Future<PodInfo?> myPod();
  Future<PodInfo> createPod();
  Future<void> joinPod(String code);
  Future<void> leavePod();

  /// The partner's name, habits, pledges and ticks since 60 days before [today], shaped like [SoloData].
  Future<SoloData> fetchPartner(PodInfo pod, DateTime today);

  /// Fires when anything in the pod changes; the caller refetches. No payloads on purpose.
  Stream<void> changes(String podId);

  /// Delivers one op. Throws [PodErrorKind.offline] when the server could not be reached (keep the op);
  /// any other [PodError] means the server refused it for good (drop the op).
  Future<void> send(SyncOp op);
}

/// Used when SUPABASE_URL / SUPABASE_ANON_KEY were not provided.
class UnconfiguredBackend implements PodBackend {
  @override
  bool get configured => false;

  Never _no() => throw const PodError(PodErrorKind.notConfigured);

  @override
  Future<void> ensureSignedIn() async => _no();
  @override
  Future<void> setProfile(String name, int utcOffsetMin) async => _no();
  @override
  Future<PodInfo?> myPod() async => _no();
  @override
  Future<PodInfo> createPod() async => _no();
  @override
  Future<void> joinPod(String code) async => _no();
  @override
  Future<void> leavePod() async => _no();
  @override
  Future<SoloData> fetchPartner(PodInfo pod, DateTime today) async => _no();
  @override
  Stream<void> changes(String podId) => const Stream.empty();
  @override
  Future<void> send(SyncOp op) async => _no();
}
