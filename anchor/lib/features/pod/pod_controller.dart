import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/backend/pod_backend.dart';
import '../../core/backend/supabase_backend.dart';
import '../../core/kv.dart';
import '../../core/local_day.dart';
import '../today/domain/models.dart';
import '../today/solo_controller.dart';

/// Overridden in tests with an in-memory backend.
final backendProvider = Provider<PodBackend>((_) => supabaseConfigured ? SupabaseBackend() : UnconfiguredBackend());

class PodState {
  const PodState({this.pod, this.partner, this.pending = 0, this.justPaired = false});

  final PodInfo? pod;

  /// The partner's data, shaped like our own. Cached so Today opens instantly and offline.
  final SoloData? partner;

  /// Local changes the server has not acknowledged yet.
  final int pending;

  /// True from the moment two people are paired until the "X is here." moment has been shown.
  final bool justPaired;

  bool get active => pod?.active ?? false;

  PodState copyWith({PodInfo? pod, SoloData? partner, int? pending, bool? justPaired, bool clearPod = false}) => PodState(
        pod: clearPod ? null : (pod ?? this.pod),
        partner: clearPod ? null : (partner ?? this.partner),
        pending: pending ?? this.pending,
        justPaired: justPaired ?? this.justPaired,
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
    return PodState(pod: c.pod, partner: c.partner, pending: _outbox.length);
  }

  Future<void> _set(PodState s) async {
    state = AsyncData(s);
    await _store.save(s.pod, s.partner, _backfilled);
  }

  Future<void> _persistOutbox() async {
    await _store.saveOutbox(_outbox);
    final cur = state.value;
    if (cur != null && cur.pending != _outbox.length) state = AsyncData(cur.copyWith(pending: _outbox.length));
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
      final becameActive = info.active && !cur.active;
      await _set(PodState(pod: info, partner: partner, pending: _outbox.length, justPaired: cur.justPaired || becameActive));
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
    await _set(PodState(pod: pod, pending: _outbox.length));
    _watch(pod.podId);
  }

  /// A code that expired or was lost: archive the empty pod and start another.
  Future<void> newCode() async {
    await _backend.leavePod();
    final pod = await _backend.createPod();
    await _set(PodState(pod: pod, pending: _outbox.length));
    _watch(pod.podId);
  }

  Future<void> joinPod(String code) async {
    final name = ref.read(soloProvider).requireValue.data.name;
    await _backend.ensureSignedIn();
    await _backend.setProfile(name, _now().timeZoneOffset.inMinutes);
    await _backend.joinPod(code);
    final info = (await _backend.myPod())!;
    final partner = await _backend.fetchPartner(info, localDate(_now()));
    await _set(PodState(pod: info, partner: partner, pending: _outbox.length, justPaired: true));
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
  void record(SyncOp Function(String podId) make) {
    final pod = state.value?.pod;
    if (pod == null || !pod.active) return;
    final op = make(pod.podId);
    _outbox.removeWhere((o) => o.key == op.key); // a newer answer for the same thing replaces the pending one
    _outbox.add(op);
    unawaited(_persistOutbox().then((_) => flush()));
  }

  /// Sends pending ops in order. Stops at the first one the server could not be reached for; drops ops
  /// the server refused for good so they cannot block the queue.
  Future<void> flush() async {
    if (_flushing || !_backend.configured) return;
    _flushing = true;
    try {
      while (_outbox.isNotEmpty) {
        final op = _outbox.first;
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
