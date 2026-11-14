// Notifications, behind a small interface. Firebase (FCM) carries them on both platforms; when Firebase is not
// configured the app runs with NoPush and nothing breaks.
import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where a tapped notification should land. Carries ids only, never names or content.
enum PushRouteKind { urge, today, pod }

class PushRoute {
  const PushRoute(this.kind, [this.id]);

  final PushRouteKind kind;
  final String? id;

  /// From the FCM `data` map the `notify` function sends: `{route: urge|today|pod, id?: <uuid>}`.
  static PushRoute? fromData(Map<String, dynamic> data) {
    final kind = PushRouteKind.values.where((k) => k.name == data['route']).firstOrNull;
    return kind == null ? null : PushRoute(kind, data['id'] as String?);
  }
}

abstract class PushService {
  /// False when Firebase is not set up on this build: the app then never asks for permission.
  bool get supported;

  /// Asks the operating system. True when notifications may be shown.
  Future<bool> requestPermission();

  Future<String?> token();
  Stream<String> get onTokenRefresh;

  /// The user tapped a notification while the app was running or in the background.
  Stream<PushRoute> get onOpened;

  /// The app was launched by tapping a notification.
  Future<PushRoute?> initialRoute();
}

class NoPush implements PushService {
  @override
  bool get supported => false;
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<String?> token() async => null;
  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
  @override
  Stream<PushRoute> get onOpened => const Stream.empty();
  @override
  Future<PushRoute?> initialRoute() async => null;
}

/// NOT yet exercised on a device: needs a Firebase project (docs/PUSH.md).
// ponytail: firebase_messaging 17 deprecates getToken/onTokenRefresh for an installation-id flow (register/onRegistered).
// This uses the classic registration token, which FCM HTTP v1 `message.token` accepts today; revisit when it is removed.
class FirebasePush implements PushService {
  FirebaseMessaging get _m => FirebaseMessaging.instance;

  @override
  bool get supported => true;

  @override
  Future<bool> requestPermission() async {
    final s = await _m.requestPermission(alert: true, badge: false, sound: true);
    return s.authorizationStatus == AuthorizationStatus.authorized || s.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> token() async {
    try {
      // ignore: deprecated_member_use
      return await _m.getToken();
    } catch (_) {
      return null; // iOS before the APNs token arrives; the refresh stream delivers it
    }
  }

  @override
  // ignore: deprecated_member_use
  Stream<String> get onTokenRefresh => _m.onTokenRefresh;

  @override
  Stream<PushRoute> get onOpened =>
      FirebaseMessaging.onMessageOpenedApp.map((m) => PushRoute.fromData(m.data)).where((r) => r != null).cast<PushRoute>();

  @override
  Future<PushRoute?> initialRoute() async {
    final m = await _m.getInitialMessage();
    return m == null ? null : PushRoute.fromData(m.data);
  }
}

/// Overridden in main() when Firebase initialises, and in tests.
final pushServiceProvider = Provider<PushService>((_) => NoPush());
