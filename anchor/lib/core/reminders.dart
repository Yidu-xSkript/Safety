// The daily "your check-in is open" reminder: a local notification, so it needs no server and says nothing about
// what the app is for. NOT yet exercised on a device (docs/PUSH.md); the schedule rules are tested in care.dart.
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../features/pod/domain/care.dart';

abstract class ReminderService {
  /// Asks the operating system (Android 13+ / iOS). True when reminders may be shown.
  Future<bool> requestPermission();

  /// Makes the scheduled reminder match [at] (null = off). [skipToday] when today's check-in is already done.
  Future<void> sync(TimeOfDay? at, {required bool skipToday, required String title, required String body});
}

class NoReminders implements ReminderService {
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> sync(TimeOfDay? at, {required bool skipToday, required String title, required String body}) async {}
}

class LocalReminders implements ReminderService {
  static const _id = 1;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    try {
      await _init();
      final android = await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      final ios = await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, sound: true);
      return (android ?? ios) ?? false;
    } catch (_) {
      return false; // no platform channel (tests, desktop)
    }
  }

  @override
  Future<void> sync(TimeOfDay? at, {required bool skipToday, required String title, required String body}) async {
    try {
      await _init();
      await _plugin.cancel(id: _id);
      if (at == null) return;
      final next = nextReminder(DateTime.now(), at.hour, at.minute, skipToday: skipToday);
      await _plugin.zonedSchedule(
        id: _id,
        title: title,
        body: body,
        // ponytail: scheduled in UTC so no timezone plugin is needed. After a daylight-saving change the reminder is an
        // hour off until the app is next opened (every open reschedules it from the phone's current offset).
        scheduledDate: tz.TZDateTime.from(next, tz.UTC),
        matchDateTimeComponents: DateTimeComponents.time, // then repeat every day at that time
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, // no exact-alarm permission needed; may drift by minutes
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('reminders', 'Reminders', importance: Importance.low, priority: Priority.low),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {
      // reminders are a convenience: a scheduling failure must never break the app
    }
  }
}

final reminderServiceProvider = Provider<ReminderService>((_) => LocalReminders());
