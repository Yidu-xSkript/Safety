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
  String daysHeld(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'days held',
      one: 'day held',
    );
    return '$_temp0';
  }

  @override
  String daysHeldPhrase(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days held',
      one: '1 day held',
    );
    return '$_temp0';
  }

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
    String days,
    int done,
    int total,
    String pledge,
    String history,
  ) {
    return '$name: $days. Today: habits $done of $total, pledge $pledge. Last days: $history.';
  }

  @override
  String slabSemanticsNoHistory(
    String name,
    String days,
    int done,
    int total,
    String pledge,
  ) {
    return '$name: $days. Today: habits $done of $total, pledge $pledge.';
  }

  @override
  String get urgePlaceholderTitle => 'The Urge flow arrives in a later phase.';

  @override
  String get close => 'Close';

  @override
  String get historyPlaceholder => 'Your first ring forms tonight.';

  @override
  String get podPlaceholder => 'Your pod will live here.';

  @override
  String get genericError =>
      'Something went wrong on our side. Nothing was lost.';

  @override
  String get welcomeTitle => 'Two people. One honest line a day.';

  @override
  String get welcomeBody => 'A quiet pod for you and one person you trust.';

  @override
  String get getStarted => 'Get started';

  @override
  String get notTreatment =>
      'Anchor supports recovery. It isn\'t treatment or a crisis service.';

  @override
  String get continueLabel => 'Continue';

  @override
  String get nameTitle => 'What should we call you?';

  @override
  String get nameHint => 'A nickname is fine.';

  @override
  String get nameHelper =>
      'Your partner will see this. It also appears on notifications.';

  @override
  String get habitsTitle => 'Pick a few daily habits';

  @override
  String get habitsBody =>
      'Optional. They sit beside your pledge so the day is more than not-doing.';

  @override
  String get habitMorningPrayer => 'Morning prayer';

  @override
  String get habitNightPrayer => 'Night prayer';

  @override
  String get habitWorkout => 'Workout (30 min)';

  @override
  String get habitReading => 'Reading';

  @override
  String get habitPhoneAway => 'Phone away by 22:00';

  @override
  String get addYourOwn => 'Add your own';

  @override
  String get addHabitHint => 'Habit name';

  @override
  String get add => 'Add';

  @override
  String get habitsLimit => 'That\'s the most you can add: 8.';

  @override
  String get justThePledge => 'Just the pledge for now';

  @override
  String get startToday => 'Start';

  @override
  String podTitle(String you, String partner) {
    return '$you & $partner';
  }

  @override
  String get pledgePrompt => 'How was today?';

  @override
  String get heldTheLine => 'Held the line';

  @override
  String get iSlipped => 'I slipped';

  @override
  String heldAt(String time) {
    return 'Held the line · $time';
  }

  @override
  String slippedAt(String time) {
    return 'Slipped · $time';
  }

  @override
  String get slipSaved =>
      'Saved. Tomorrow is a new ring. The tree keeps growing.';

  @override
  String get changeAnswer => 'Change today\'s answer';

  @override
  String get habitsHeading => 'Habits';

  @override
  String habitsProgress(int done, int total) {
    return '$done of $total';
  }

  @override
  String get slipTitle => 'Thank you for telling the truth.';

  @override
  String get slipBody => 'That takes more than holding a streak does.';

  @override
  String get slipNoteHint => 'Add a note (optional)';

  @override
  String get slipSave => 'Save';

  @override
  String get slipNotYet => 'Not yet';

  @override
  String get weekHeading => 'This week';

  @override
  String weekPersonState(String name, String state) {
    return '$name $state';
  }

  @override
  String weekDayLabel(String date, String summary) {
    return '$date: $summary';
  }
}
