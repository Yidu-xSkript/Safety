import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_lock.dart';
import '../pod/pod_controller.dart';
import '../pod/settings_controller.dart';
import '../today/solo_controller.dart';

/// Locked again after this long away from the app.
const kLockAfter = Duration(seconds: 30);

/// Whether the app is locked right now. The lock exists only once there is something to protect (onboarded and
/// in a pod), only when this phone can lock, and only unless you turned it off. A phone with no passcode is
/// never locked: a lock nobody can open is worse than none.
class LockController extends AsyncNotifier<bool> {
  DateTime? _away;

  AppLockService get _service => ref.read(appLockServiceProvider);
  DateTime _now() => ref.read(clockProvider)();

  @override
  Future<bool> build() async => _shouldLock();

  Future<bool> _shouldLock() async {
    final settings = await ref.read(settingsProvider.future);
    final solo = await ref.read(soloProvider.future);
    final pod = await ref.read(podProvider.future);
    if (!solo.data.onboarded || pod.pod == null) return false;
    return (settings.appLock ?? true) && await _service.isSupported();
  }

  /// Asks the system. On success the app opens.
  Future<bool> unlock(String reason) async {
    final ok = await _service.authenticate(reason);
    if (ok) {
      _away = null;
      state = const AsyncData(false);
    }
    return ok;
  }

  /// The app left the screen.
  void leaving() => _away = _now();

  /// The app came back: lock if it was away long enough.
  Future<void> returned() async {
    final away = _away;
    if (away == null || state.value != false) return;
    if (_now().difference(away) < kLockAfter) return;
    if (await _shouldLock()) state = const AsyncData(true);
  }
}

final lockProvider = AsyncNotifierProvider<LockController, bool>(LockController.new);

/// Keeps Android's FLAG_SECURE in step with the "hide in app switcher" setting.
final privacySyncProvider = Provider<void>((ref) {
  final hide = ref.watch(settingsProvider.select((s) => s.value?.hideInSwitcher));
  if (hide != null) ref.read(privacyServiceProvider).setSecure(hide);
});
