import 'dart:convert';

import 'package:anchor/app/theme.dart';
import 'package:anchor/features/today/domain/models.dart';
import 'package:anchor/features/today/solo_controller.dart';
import 'package:anchor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Frozen "now" for tests: noon on Nov 14, 2026 (local day 2026-11-14).
final testNow = DateTime(2026, 11, 14, 12);

/// Puts [data] (or nothing) in the fake preferences, as if the app had stored it earlier.
void seedSolo([SoloData? data]) => SharedPreferences.setMockInitialValues(
      data == null ? {} : {'anchor.solo.v1': jsonEncode(data.toJson())},
    );

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
}) {
  return ProviderScope(
    overrides: [clockProvider.overrideWithValue(clock ?? () => testNow)],
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
