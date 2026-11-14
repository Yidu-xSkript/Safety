// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Anchor';

  @override
  String get tabToday => 'Today';

  @override
  String get tabHistory => 'History';

  @override
  String get tabPod => 'Pod';

  @override
  String get urge => 'Urge';

  @override
  String get urgeTooltip => 'Reach out to your partner';

  @override
  String get daysHeld => 'days held';

  @override
  String podStreak(int count) {
    return 'Pod streak $count';
  }

  @override
  String get ringStateHeld => 'held';

  @override
  String get ringStateSlipped => 'slipped';

  @override
  String get ringStateUnchecked => 'not checked in';

  @override
  String slabSemantics(
    String name,
    int days,
    int done,
    int total,
    String pledge,
    String history,
  ) {
    return '$name: $days days held. Today: habits $done of $total, pledge $pledge. Last days: $history.';
  }

  @override
  String slabSemanticsNoHistory(
    String name,
    int days,
    int done,
    int total,
    String pledge,
  ) {
    return '$name: $days days held. Today: habits $done of $total, pledge $pledge.';
  }

  @override
  String get urgePlaceholderTitle => 'The Urge flow arrives in a later phase.';

  @override
  String get close => 'Close';

  @override
  String get historyPlaceholder => 'Your first ring forms tonight.';

  @override
  String get podPlaceholder => 'Your pod will live here.';
}
