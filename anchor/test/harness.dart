import 'dart:convert';

import 'package:anchor/app/theme.dart';
import 'package:anchor/core/backend/pod_backend.dart';
import 'package:anchor/core/local_day.dart';
import 'package:anchor/features/pod/pod_controller.dart';
import 'package:anchor/features/rings/ring_model.dart';
import 'package:anchor/features/today/domain/models.dart';
import 'package:anchor/features/today/solo_controller.dart';
import 'package:anchor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Frozen "now" for tests: noon on Nov 14, 2026 (local day 2026-11-14).
final testNow = DateTime(2026, 11, 14, 12);

/// A synthetic partner (Teo): held on each of the 21 days before today and today, so a 22-day streak.
SoloData teoData(DateTime today) {
  final start = addDays(today, -21);
  final habits = [for (var i = 0; i < 4; i++) Habit(id: 'teo-h$i', title: 'Habit $i', createdDay: start)];
  return SoloData(
    name: 'Teo',
    onboarded: true,
    startDay: start,
    habits: habits,
    checkIns: {
      for (var i = 0; i <= 21; i++)
        dayKey(addDays(start, i)): CheckIn(state: PledgeState.held, at: DateTime.utc(2026, 1, 1)),
    },
    logs: {
      for (var i = 0; i <= 21; i++)
        dayKey(addDays(start, i)): {for (final h in habits.take(2 + addDays(start, i).day % 3)) h.id},
    },
  );
}

/// Puts [data] (or nothing) in the fake preferences, as if the app had stored it earlier. [paired] also
/// stores an active pod with Teo, so the app opens straight onto Today.
void seedSolo([SoloData? data, bool paired = false]) => SharedPreferences.setMockInitialValues({
      if (data != null) 'anchor.solo.v1': jsonEncode(data.toJson()),
      if (paired)
        'anchor.pod.v1': jsonEncode({
          'pod': const PodInfo(podId: 'pod-1', status: PodStatus.active, partnerId: 'teo', partnerName: 'Teo').toJson(),
          'partner': teoData(localDate(testNow)).toJson(),
          'backfilled': 'pod-1',
        }),
    });

/// A user who finished onboarding on [started] with two habits.
SoloData onboardedMika({required DateTime started, Map<String, CheckIn> checkIns = const {}, Map<String, Set<String>> logs = const {}}) =>
    SoloData(
      name: 'Mika',
      onboarded: true,
      startDay: started,
      habits: [
        Habit(id: 'read', title: 'Reading', createdDay: started),
        Habit(id: 'gym', title: 'Workout (30 min)', createdDay: started),
      ],
      checkIns: checkIns,
      logs: logs,
    );

/// App-like wrapper for widget and golden tests. Wraps in a ProviderScope with a controllable clock.
Widget harness(
  Widget child, {
  Brightness brightness = Brightness.light,
  TargetPlatform platform = TargetPlatform.android,
  double textScale = 1,
  bool disableAnimations = false,
  DateTime Function()? clock,
  PodBackend? backend,
}) {
  return ProviderScope(
    overrides: [
      clockProvider.overrideWithValue(clock ?? () => testNow),
      backendProvider.overrideWithValue(backend ?? UnconfiguredBackend()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: anchorTheme(brightness, platform: platform),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: disableAnimations),
        child: c!,
      ),
      home: child,
    ),
  );
}
