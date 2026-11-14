import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/backend/pod_backend.dart';
import '../../core/backend/supabase_backend.dart';
import '../../core/kv.dart';
import '../../core/local_day.dart';
import '../../core/uuid.dart';
import '../today/domain/models.dart';
import '../urge/replies.dart';
import '../today/solo_controller.dart';

/// Overridden in tests with an in-memory backend.
final backendProvider = Provider<PodBackend>((_) => supabaseConfigured ? SupabaseBackend() : UnconfiguredBackend());

class PodState {
  const PodState({
    this.pod,
    this.partner,
    this.pendingKeys = const {},
    this.justPaired = false,
    this.partnerUrge,
    this.replies = const [],
  });

  final PodInfo? pod;

  /// The partner's data, shaped like our own. Cached so Today opens instantly and offline.
  final SoloData? partner;

  /// Keys of local changes the server has not acknowledged yet (the screens ask "is my ping still queued?").
  final Set<String> pendingKeys;

  /// True from the moment two people are paired until the "X is here." moment has been shown.
  final bool justPaired;

  /// The partner is reaching out right now (open, recent, not retracted).
  final UrgeInfo? partnerUrge;

  /// Prepared replies between us, newest first.
  final List<ReplyInfo> replies;

  int get pending => pendingKeys.length;
  bool get active => pod?.active ?? false;

  PodState copyWith({PodInfo? pod, SoloData? partner, Set<String>? pendingKeys, bool? justPaired}) => PodState(
        pod: pod ?? this.pod,
        partner: partner ?? this.partner,
        pendingKeys: pendingKeys ?? this.pendingKeys,
        justPaired: justPaired ?? this.justPaired,
        partnerUrge: partnerUrge,
        replies: replies,
      );
}

/// Pod + partner cache and the outbox, in key-value storage. Both are small.
// ponytail: the Supabase session lives in supabase_flutter's default storage; move it to secure storage with app lock (Phase 5).
class PodStore {
  PodStore(this._p);

  static const _podKey = 'anchor.pod.v1';
  static const _outboxKey = 'anchor.outbox.v1';
  final KV _p;

  ({PodInfo? pod, SoloData? partner, String? backfilled}) load() {
    try {
      final j = jsonDecode(_p.get(_podKey) ?? 'null') as Map<String, dynamic>?;
      if (j == null) return (pod: null, partner: null, backfilled: null);
      return (
        pod: j['pod'] == null ? null : PodInfo.fromJson(j['pod'] as Map<String, dynamic>),
        partner: j['partner'] == null ? null : SoloData.fromJson(j['partner'] as Map<String, dynamic>),
        backfilled: j['backfilled'] as String?,
      );
    } catch (_) {
      return (pod: null, partner: null, backfilled: null);
    }
  }

  Future<void> save(PodInfo? pod, SoloData? partner, String? backfilled) =>
      _p.set(_podKey, jsonEncode({'pod': pod?.toJson(), 'partner': partner?.toJson(), 'backfilled': backfilled}));

  List<SyncOp> loadOutbox() {
    try {
      return [for (final j in jsonDecode(_p.get(_outboxKey) ?? '[]') as List) SyncOp.fromJson(j as Map<String, dynamic>)];
    } catch (_) {
      return [];
    }
  }

  Future<void> saveOutbox(List<SyncOp> ops) => _p.set(_outboxKey, jsonEncode([for (final o in ops) o.toJson()]));
}

class PodController extends AsyncNotifier<PodState> {
  late PodStore _store;
  late List<SyncOp> _outbox;
  String? _backfilled;
  StreamSubscription<void>? _sub;
  String? _subPod;
  Timer? _retry;
  Timer? _debounce;
  bool _flushing = false;

  Set<String> get _keys => {for (final o in _outbox) o.key};

  PodBackend get _backend => ref.read(backendProvider);
  DateTime _now() => ref.read(clockProvider)();

  @override
  Future<PodState> build() async {
    _store = PodStore(await ref.watch(kvProvider.future));
    final c = _store.load();
    _outbox = _store.loadOutbox();
    _backfilled = c.backfilled;
    ref.onDispose(() {
      _sub?.cancel();
      _retry?.cancel();
      _debounce?.cancel();
    });
    if (c.pod != null) Future(refresh); // after this build has published its state
    return PodState(pod: c.pod, partner: c.partner, pendingKeys: _keys);
  }

  Future<void> _set(PodState s) async {
    state = AsyncData(s);
    await _store.save(s.pod, s.partner, _backfilled);
  }

  Future<void> _persistOutbox() async {
    await _store.saveOutbox(_outbox);
    final cur = state.value;
    if (cur != null && cur.pending != _outbox.length) state = AsyncData(cur.copyWith(pendingKeys: _keys));
  }

  /// Pulls pod + partner from the server. Offline or refused: keeps what we have.
  Future<void> refresh() async {
    final cur = state.value;
    if (cur == null || cur.pod == null) return;
    try {
      final info = await _backend.myPod();
      if (info == null) {
        await _set(const PodState());
        return;
      }
      final partner = info.active ? await _backend.fetchPartner(info, localDate(_now())) : cur.partner;
      final activity = info.active ? await _backend.fetchActivity(info, _now()) : null;
      final becameActive = info.active && !cur.active;
      await _set(PodState(
        pod: info,
        partner: partner,
        pendingKeys: _keys,
        justPaired: cur.justPaired || becameActive,
        partnerUrge: activity?.partnerUrge,
        replies: activity?.replies ?? const [],
      ));
      _watch(info.podId);
      if (info.active) {
        await _backfillOnce(info.podId);
        unawaited(flush());
      }
    } on PodError {
      // keep the cache; the next resume or realtime event tries again
    }
  }

  /// Starts a pod and returns once it has a code. Throws [PodError] for the screen to show.
  Future<void> createPod() async {
    final name = ref.read(soloProvider).requireValue.data.name;
    await _backend.ensureSignedIn();
    await _backend.setProfile(name, _now().timeZoneOffset.inMinutes);
    final pod = await _backend.createPod();
    await _set(PodState(pod: pod, pendingKeys: _keys));
    _watch(pod.podId);
  }

  /// A code that expired or was lost: archive the empty pod and start another.
  Future<void> newCode() async {
    await _backend.leavePod();
    final pod = await _backend.createPod();
    await _set(PodState(pod: pod, pendingKeys: _keys));
    _watch(pod.podId);
  }

  Future<void> joinPod(String code) async {
    final name = ref.read(soloProvider).requireValue.data.name;
    await _backend.ensureSignedIn();
    await _backend.setProfile(name, _now().timeZoneOffset.inMinutes);
    await _backend.joinPod(code);
    final info = (await _backend.myPod())!;
    final partner = await _backend.fetchPartner(info, localDate(_now()));
    await _set(PodState(pod: info, partner: partner, pendingKeys: _keys, justPaired: true));
    _watch(info.podId);
    await _backfillOnce(info.podId);
    unawaited(flush());
  }

  Future<void> acknowledgePaired() async {
    final cur = state.value;
    if (cur != null && cur.justPaired) state = AsyncData(cur.copyWith(justPaired: false));
  }

  void _watch(String podId) {
    if (_subPod == podId) return;
    _sub?.cancel();
    _subPod = podId;
    _sub = _backend.changes(podId).listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), refresh);
    }, onError: (_) {});
  }

  // ---- outbox -------------------------------------------------------------------------------

  /// Our data was empty on the server when the pod became active: upload habits and today's/yesterday's
  /// state once. (Older days predate the pod and stay on this phone: the server only accepts the last two days.)
  Future<void> _backfillOnce(String podId) async {
    if (_backfilled == podId) return;
    for (final op in await ref.read(soloProvider.notifier).prepareBackfill(podId)) {
      _outbox.removeWhere((o) => o.key == op.key);
      _outbox.add(op);
    }
    _backfilled = podId;
    await _persistOutbox();
    await _store.save(state.value?.pod, state.value?.partner, _backfilled);
  }

  /// Queue a change made on this phone. A no-op until the pod is active (solo data is just local).
  ///
  /// [urgent] ops (urges, replies) go ahead of ordinary ones so a crisis never waits behind a habit tick,
  /// but stay in order among themselves (an urge is created before it is retracted).
  void record(SyncOp Function(String podId) make, {bool urgent = false}) {
    final pod = state.value?.pod;
    if (pod == null || !pod.active) return;
    final op = make(pod.podId);
    _outbox.removeWhere((o) => o.key == op.key); // a newer answer for the same thing replaces the pending one
    if (urgent) {
      var i = 0;
      while (i < _outbox.length && _isUrgent(_outbox[i])) {
        i++;
      }
      _outbox.insert(i, op);
    } else {
      _outbox.add(op);
    }
    unawaited(_persistOutbox().then((_) => flush()));
  }

  static bool _isUrgent(SyncOp o) => o is UrgeOp || o is UrgeUpdateOp || o is ReplyOp;

  // ---- the hard moment ----------------------------------------------------------------------

  /// Called the instant Urge is pressed. Returns the id the screen keeps. The ping is queued (and sent at
  /// once when online); with no active pod nothing is queued and the grounding screen still works.
  String beginUrge() {
    final id = newUuid();
    record((pod) => UrgeOp(podId: pod, id: id, at: _now()), urgent: true);
    return id;
  }

  /// "That was a mistake": the partner is told it is okay.
  void retractUrge(String id) => record((pod) => UrgeUpdateOp(id: id, retract: true), urgent: true);

  /// How it ended: passed / slipped / need_more.
  void finishUrge(String id, String outcome) => record((pod) => UrgeUpdateOp(id: id, outcome: outcome));

  /// One tap, prepared words only. [urgeId] ties it to an urge (shown on their grounding screen).
  void reply(ReplyTemplate t, {String? urgeId}) {
    final partner = state.value?.pod?.partnerId;
    if (partner == null) return;
    record(
      (pod) => ReplyOp(
        podId: pod,
        id: newUuid(),
        toUser: partner,
        kind: urgeId != null ? 'urge_reply' : 'slip_reply',
        template: t.key,
        urgeId: urgeId,
      ),
      urgent: true,
    );
  }

  /// Sends pending ops in order. Stops at the first one the server could not be reached for; drops ops
  /// the server refused for good so they cannot block the queue.
  Future<void> flush() async {
    if (_flushing || !_backend.configured) return;
    _flushing = true;
    try {
      while (_outbox.isNotEmpty) {
        final op = _outbox.first;
        if (op is UrgeOp && _now().difference(op.at) > kUrgeFreshness) {
          _outbox.removeWhere((o) => identical(o, op)); // stale: arriving hours late it would read as a fresh alarm
          await _persistOutbox();
          continue;
        }
        try {
          await _backend.send(op);
        } on PodError catch (e) {
          if (e.kind == PodErrorKind.offline) {
            _retry?.cancel();
            _retry = Timer(const Duration(seconds: 30), flush);
            return;
          }
          // refused for good: fall through and drop it
        }
        _outbox.removeWhere((o) => identical(o, op)); // by identity: a newer op for the same key may have replaced it
        await _persistOutbox();
      }
    } finally {
      _flushing = false;
    }
  }
}

final podProvider = AsyncNotifierProvider<PodController, PodState>(PodController.new);
