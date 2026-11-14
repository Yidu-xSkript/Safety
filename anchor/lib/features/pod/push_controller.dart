import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backend/pod_backend.dart';
import '../../core/kv.dart';
import '../../core/push/push_service.dart';
import 'pod_controller.dart';

const kPushAskedKey = 'anchor.push.asked'; // absent = never asked, 'yes', 'no'

class PushState {
  const PushState({required this.supported, this.asked});

  final bool supported;
  final String? asked;

  /// Ask once, with a reason first, and only when notifications can work at all.
  bool get shouldPrompt => supported && asked == null;
  bool get enabled => asked == 'yes';
}

/// Notification permission and this phone's token. We never ask cold: the Today screen shows why first
/// (SECURITY.md: notifications say nothing about what the app is for), and "Not now" is remembered.
class PushController extends AsyncNotifier<PushState> {
  KV? _kv;
  StreamSubscription<String>? _refresh;

  PushService get _push => ref.read(pushServiceProvider);

  @override
  Future<PushState> build() async {
    _kv = await ref.watch(kvProvider.future);
    ref.onDispose(() => _refresh?.cancel());
    // A new pod, or a restart, is a moment to make sure the server has our token.
    ref.listen(podProvider.select((s) => s.value?.active ?? false), (_, active) {
      if (active) unawaited(sync());
    });
    _refresh = _push.onTokenRefresh.listen((t) => unawaited(_register(t)));
    final s = PushState(supported: _push.supported, asked: _kv!.get(kPushAskedKey));
    if (s.enabled) Future(sync);
    return s;
  }

  Future<void> _remember(String answer) async {
    await _kv!.set(kPushAskedKey, answer);
    state = AsyncData(PushState(supported: _push.supported, asked: answer));
  }

  /// "Turn on notifications": the only place the operating system is asked.
  Future<void> enable() async {
    final granted = await _push.requestPermission();
    await _remember(granted ? 'yes' : 'no');
    if (granted) await sync();
  }

  Future<void> dismiss() => _remember('no');

  /// Tells the server our current token. Idempotent; safe to call on every launch and resume.
  Future<void> sync() async {
    if (!(state.value?.enabled ?? false)) return;
    if (!(ref.read(podProvider).value?.active ?? false)) return;
    final token = await _push.token();
    if (token != null) await _register(token);
  }

  Future<void> _register(String token) async {
    if (!(state.value?.enabled ?? false)) return;
    try {
      await ref.read(backendProvider).registerDevice(defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android', token);
    } on PodError {
      // offline or not paired yet: the next launch or token refresh tries again
    }
  }
}

final pushProvider = AsyncNotifierProvider<PushController, PushState>(PushController.new);
