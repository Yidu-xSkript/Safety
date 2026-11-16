import 'package:anchor/core/app_lock.dart';

/// A phone's lock, scripted. Real platform channels never answer in widget tests, so every test that
/// pumps the whole app overrides [appLockServiceProvider] with one of these (unsupported = no lock at all).
class FakeAppLock implements AppLockService {
  FakeAppLock({this.supported = false, this.result = true});

  bool supported;

  /// What the system prompt answers.
  bool result;
  final reasons = <String>[];

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> authenticate(String reason) async {
    reasons.add(reason);
    return result;
  }
}

class FakePrivacy implements PrivacyService {
  final calls = <bool>[];

  @override
  Future<void> setSecure(bool on) async => calls.add(on);
}
