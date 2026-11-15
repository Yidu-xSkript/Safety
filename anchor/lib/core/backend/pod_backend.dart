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

/// A partner's open urge: reaching out, not retracted, not resolved, recent.
class UrgeInfo {
  const UrgeInfo({required this.id, required this.createdAt});

  final String id;
  final DateTime createdAt;
}

/// A prepared reply between the two partners. [template] is the server key (`here`, `call_me`, ...).
class ReplyInfo {
  const ReplyInfo({required this.id, required this.fromMe, required this.template, required this.createdAt, this.urgeId});

  final String id;
  final bool fromMe;
  final String template;
  final String? urgeId;
  final DateTime createdAt;
}

/// Things the partner did that this phone should react to.
class PodActivity {
  const PodActivity({this.partnerUrge, this.replies = const []});

  final UrgeInfo? partnerUrge;
  final List<ReplyInfo> replies; // involving me, newest first, last ~2 days
}

/// How far back the partner's and our own history is fetched (History shows months).
const kHistoryDays = 366;

/// An urge older than this is stale: a ping that sat in the queue for hours must not arrive as an alarm.
const kUrgeFreshness = Duration(minutes: 30);

enum PodErrorKind { alreadyInPod, invalidCode, tooManyAttempts, invalidOtp, emailInUse, offline, notConfigured, other }

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
        'urge' => UrgeOp(podId: j['pod'] as String, id: j['id'] as String, at: DateTime.parse(j['at'] as String)),
        'urgeUpdate' => UrgeUpdateOp(
            id: j['id'] as String,
            retract: j['retract'] as bool,
            outcome: j['outcome'] as String?,
          ),
        'reply' => ReplyOp(
            podId: j['pod'] as String,
            id: j['id'] as String,
            toUser: j['to'] as String,
            kind: j['kind'] as String,
            template: j['template'] as String,
            urgeId: j['urge'] as String?,
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

/// Reaching out. Created the instant the Urge button is pressed; the client picks the id so a replay is harmless.
class UrgeOp extends SyncOp {
  const UrgeOp({required this.podId, required this.id, required this.at});

  final String podId;
  final String id;
  final DateTime at;

  @override
  String get key => 'u:$id';

  @override
  Map<String, Object?> toJson() => {'type': 'urge', 'pod': podId, 'id': id, 'at': at.toUtc().toIso8601String()};
}

/// "That was a mistake" ([retract]) or how it ended ([outcome]: passed / slipped / need_more).
class UrgeUpdateOp extends SyncOp {
  const UrgeUpdateOp({required this.id, this.retract = false, this.outcome});

  final String id;
  final bool retract;
  final String? outcome;

  @override
  String get key => 'uu:$id';

  @override
  Map<String, Object?> toJson() => {'type': 'urgeUpdate', 'id': id, 'retract': retract, 'outcome': outcome};
}

/// A prepared reply to the partner. Never free text.
class ReplyOp extends SyncOp {
  const ReplyOp({required this.podId, required this.id, required this.toUser, required this.kind, required this.template, this.urgeId});

  final String podId;
  final String id;
  final String toUser;
  final String kind; // urge_reply | slip_reply
  final String template;
  final String? urgeId;

  @override
  String get key => 'r:$id';

  @override
  Map<String, Object?> toJson() =>
      {'type': 'reply', 'pod': podId, 'id': id, 'to': toUser, 'kind': kind, 'template': template, 'urge': urgeId};
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

  /// The email this account is secured with, or null while it is still anonymous.
  Future<String?> accountEmail();

  /// Secure the anonymous account: sends a code to [email], then [confirmEmailLink] with that code.
  Future<void> requestEmailLink(String email);
  Future<void> confirmEmailLink(String email, String code);

  /// After a reinstall: sign back in to an existing account with an emailed code.
  Future<void> requestSignIn(String email);
  Future<void> confirmSignIn(String email, String code);

  /// Our own name, habits, pledges and ticks as the server has them (restoring after a reinstall).
  Future<SoloData> fetchMine(DateTime today);

  /// The partner's open urge (if any) and the replies between us. Called on every refresh.
  Future<PodActivity> fetchActivity(PodInfo pod, DateTime now);

  /// Tells the server where to send this phone's notifications.
  Future<void> registerDevice(String platform, String token);

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
  Future<String?> accountEmail() async => _no();
  @override
  Future<void> requestEmailLink(String email) async => _no();
  @override
  Future<void> confirmEmailLink(String email, String code) async => _no();
  @override
  Future<void> requestSignIn(String email) async => _no();
  @override
  Future<void> confirmSignIn(String email, String code) async => _no();
  @override
  Future<SoloData> fetchMine(DateTime today) async => _no();
  @override
  Future<PodActivity> fetchActivity(PodInfo pod, DateTime now) async => _no();
  @override
  Future<void> registerDevice(String platform, String token) async => _no();
  @override
  Stream<void> changes(String podId) => const Stream.empty();
  @override
  Future<void> send(SyncOp op) async => _no();
}
