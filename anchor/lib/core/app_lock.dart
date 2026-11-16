// Device-level privacy: the lock (Face / fingerprint / the phone's own passcode) and the "hide in app switcher" cover.
// Both sit behind small interfaces so tests run without a platform. NOT yet exercised on a device.
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

abstract class AppLockService {
  /// True when this phone has a biometric or a passcode the app can ask for.
  Future<bool> isSupported();

  /// Shows the system prompt. False when it failed or was cancelled; never throws.
  Future<bool> authenticate(String reason);
}

class LocalAuthLock implements AppLockService {
  final _auth = LocalAuthentication();

  @override
  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false; // no platform channel (tests, desktop): no lock rather than a lock nobody can open
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason);
    } catch (_) {
      return false;
    }
  }
}

final appLockServiceProvider = Provider<AppLockService>((_) => LocalAuthLock());

final lockSupportedProvider = FutureProvider<bool>((ref) => ref.read(appLockServiceProvider).isSupported());

/// Android: FLAG_SECURE blocks screenshots and the recents thumbnail. (iOS is covered in Dart on `inactive`.)
abstract class PrivacyService {
  Future<void> setSecure(bool on);
}

class NativePrivacy implements PrivacyService {
  static const _channel = MethodChannel('com.anchor/privacy');

  @override
  Future<void> setSecure(bool on) async {
    try {
      await _channel.invokeMethod<void>('setSecure', on);
    } catch (_) {
      // iOS and tests have no such channel; the Dart cover still applies
    }
  }
}

final privacyServiceProvider = Provider<PrivacyService>((_) => NativePrivacy());
