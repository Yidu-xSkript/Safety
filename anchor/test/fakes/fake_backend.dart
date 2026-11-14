// An in-memory "server" two phones can share, enforcing the same rules as supabase/migrations/0001_init.sql
// (those rules are proven by supabase/tests/rls.sql; this keeps the Dart side honest against them).
import 'dart:async';
import 'dart:math';

import 'package:anchor/core/backend/pod_backend.dart';
import 'package:anchor/core/local_day.dart';
import 'package:anchor/features/today/domain/models.dart';

const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

class FakePod {
  FakePod(this.id, this.creator, this.code, this.expires);
  final String id;
  final String creator;
  String? code;
  final DateTime expires; // fixed when the code is issued
  String? member2;
  PodStatus status = PodStatus.open;
  final left = <String>{}; // users who left: they keep no membership, like left_at in the real schema
}

class FakeUrge {
  FakeUrge(this.id, this.user, this.createdAt);
  final String id;
  final String user;
  final DateTime createdAt;
  bool retracted = false;
  String? outcome;
  bool get resolved => outcome != null;
}

class FakeReply {
  FakeReply(this.id, this.from, this.to, this.template, this.urgeId, this.createdAt);
  final String id;
  final String from;
  final String to;
  final String template;
  final String? urgeId;
  final DateTime createdAt;
}

class FakeServer {
  FakeServer({DateTime Function()? now, DateTime? start})
      : _clock = now,
        _t = start ?? DateTime.now();

  final DateTime Function()? _clock;
  DateTime _t;

  /// The server's clock. Tests either hand it the app's clock, or start it somewhere and [advance] it.
  DateTime now() => _clock?.call() ?? _t;
  void advance(Duration d) => _t = _t.add(d);
  final _pods = <String, FakePod>{};
  final names = <String, String>{};
  final habits = <String, Map<String, Habit>>{}; // user -> id -> habit
  final checkIns = <String, Map<String, CheckIn>>{}; // user -> dayKey -> pledge
  final ticks = <String, Map<String, Set<String>>>{}; // user -> dayKey -> habit ids
  final urges = <String, FakeUrge>{};
  final replies = <FakeReply>[];
  final devices = <String, ({String user, String platform})>{}; // token -> owner
  final _attempts = <String, int>{};
  final _changes = <String, StreamController<void>>{};
  final _rng = Random(7);
  int _next = 0;

  /// Every op the server accepted, in order. Lets tests assert replays do not duplicate.
  final accepted = <String>[];

  Stream<void> changes(String pod) => (_changes[pod] ??= StreamController<void>.broadcast()).stream;
  void notify(String pod) => _changes[pod]?.add(null);

  FakePod? podOf(String user) =>
      _pods.values.where((p) => (p.creator == user || p.member2 == user) && !p.left.contains(user)).firstOrNull;
}

class FakeBackend implements PodBackend {
  FakeBackend(this.server, this.userId);

  final FakeServer server;
  final String userId;

  /// Flip to simulate no connectivity: every call throws [PodErrorKind.offline].
  bool online = true;

  void _net() {
    if (!online) throw const PodError(PodErrorKind.offline);
  }

  @override
  bool get configured => true;

  @override
  Future<void> ensureSignedIn() async => _net();

  @override
  Future<void> setProfile(String name, int utcOffsetMin) async {
    _net();
    server.names[userId] = name;
  }

  PodInfo _info(FakePod p) {
    final partner = p.creator == userId ? p.member2 : p.creator;
    return PodInfo(
      podId: p.id,
      status: p.status,
      inviteCode: p.code,
      inviteExpiresAt: p.code == null ? null : p.expires,
      partnerId: partner,
      partnerName: partner == null ? null : server.names[partner],
    );
  }

  @override
  Future<PodInfo?> myPod() async {
    _net();
    final p = server.podOf(userId);
    return p == null ? null : _info(p);
  }

  @override
  Future<PodInfo> createPod() async {
    _net();
    if (server.podOf(userId) != null) throw const PodError(PodErrorKind.alreadyInPod);
    final code = List.generate(6, (_) => _alphabet[server._rng.nextInt(_alphabet.length)]).join();
    final p = FakePod('pod-${server._next++}', userId, code, server.now().add(const Duration(hours: 24)));
    server._pods[p.id] = p;
    return _info(p);
  }

  @override
  Future<void> joinPod(String code) async {
    _net();
    if ((server._attempts[userId] ?? 0) >= 5) throw const PodError(PodErrorKind.tooManyAttempts);
    if (server.podOf(userId) != null) throw const PodError(PodErrorKind.alreadyInPod);
    final p = server._pods.values.where((p) => p.status == PodStatus.open && p.code == code.trim().toUpperCase()).firstOrNull;
    if (p == null) {
      server._attempts[userId] = (server._attempts[userId] ?? 0) + 1;
      throw const PodError(PodErrorKind.invalidCode);
    }
    p
      ..member2 = userId
      ..status = PodStatus.active
      ..code = null;
    server.notify(p.id);
  }

  @override
  Future<void> leavePod() async {
    _net();
    final p = server.podOf(userId);
    if (p == null) return;
    p.left.add(userId);
    p.status = PodStatus.archived;
    p.code = null;
    server.notify(p.id);
  }

  @override
  Future<SoloData> fetchPartner(PodInfo pod, DateTime today) async {
    _net();
    final id = pod.partnerId!;
    final hs = server.habits[id]?.values.toList() ?? [];
    final cis = server.checkIns[id] ?? {};
    final days = [...cis.keys.map(parseDayKey), ...hs.map((h) => h.createdDay)]..sort();
    return SoloData(
      name: pod.partnerName ?? '',
      onboarded: true,
      startDay: days.isEmpty ? null : days.first,
      habits: hs,
      checkIns: Map.of(cis),
      logs: {for (final e in (server.ticks[id] ?? {}).entries) e.key: Set.of(e.value)},
    );
  }

  @override
  Future<PodActivity> fetchActivity(PodInfo pod, DateTime now) async {
    _net();
    final partner = pod.partnerId!;
    final fresh = server.now().subtract(kUrgeFreshness);
    final u = server.urges.values
        .where((u) => u.user == partner && !u.retracted && !u.resolved && u.createdAt.isAfter(fresh))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final since = server.now().subtract(const Duration(days: 2));
    return PodActivity(
      partnerUrge: u.isEmpty ? null : UrgeInfo(id: u.first.id, createdAt: u.first.createdAt),
      replies: [
        for (final r in server.replies.reversed)
          if ((r.from == userId || r.to == userId) && r.createdAt.isAfter(since))
            ReplyInfo(id: r.id, fromMe: r.from == userId, template: r.template, urgeId: r.urgeId, createdAt: r.createdAt),
      ],
    );
  }

  @override
  Future<void> registerDevice(String platform, String token) async {
    _net();
    server.devices[token] = (user: userId, platform: platform); // newest registration owns the token
  }

  @override
  Stream<void> changes(String podId) => server.changes(podId);

  @override
  Future<void> send(SyncOp op) async {
    _net();
    final pod = server.podOf(userId);
    if (pod == null || pod.status != PodStatus.active) throw const PodError(PodErrorKind.other); // RLS: not in an active pod
    switch (op) {
      case CheckInOp():
        (server.checkIns[userId] ??= {})[dayKey(op.day)] = CheckIn(state: op.state, at: DateTime.now(), note: op.note);
      case HabitOp():
        (server.habits[userId] ??= {})[op.id] =
            Habit(id: op.id, title: op.title, createdDay: op.createdDay, archivedDay: op.archivedDay);
      case UrgeOp():
        server.urges.putIfAbsent(op.id, () => FakeUrge(op.id, userId, server.now()));
      case UrgeUpdateOp():
        final u = server.urges[op.id];
        if (u == null || u.user != userId) throw const PodError(PodErrorKind.other);
        op.retract ? u.retracted = true : u.outcome = op.outcome;
      case ReplyOp():
        if (!server.replies.any((r) => r.id == op.id)) {
          server.replies.add(FakeReply(op.id, userId, op.toUser, op.template, op.urgeId, server.now()));
        }
      case TickOp():
        final day = (server.ticks[userId] ??= {}).putIfAbsent(dayKey(op.day), () => {});
        op.on ? day.add(op.habitId) : day.remove(op.habitId);
    }
    server.accepted.add(op.key);
    server.notify(pod.id);
  }
}
