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
  String get close => 'Close';

  @override
  String get historyPlaceholder => 'Your first ring forms tonight.';

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
      'Told. Tomorrow is a new ring. The tree keeps growing.';

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

  @override
  String slipBody(String name) {
    return 'That takes more than holding a streak does. $name will see this and can answer you.';
  }

  @override
  String slipNoteHint(String name) {
    return 'Add a note for $name (optional)';
  }

  @override
  String slipTell(String name) {
    return 'Tell $name';
  }

  @override
  String heldSeen(String name) {
    return '$name can see it.';
  }

  @override
  String get queuedNote => 'Saved. Will send when you\'re back online.';

  @override
  String get pairTitle => 'Pair with one person you trust';

  @override
  String get pairBody =>
      'A pod is exactly two people. Nobody else can ever see it.';

  @override
  String get createPod => 'Create a pod';

  @override
  String get haveCode => 'I have a code';

  @override
  String get joinTitle => 'Enter your partner\'s code';

  @override
  String get joinHint => '6-character code';

  @override
  String get joinButton => 'Join';

  @override
  String get waitingTitle => 'Share this code with the one person you trust.';

  @override
  String get codeNote => 'Single use. Expires in 24 hours.';

  @override
  String get codeExpired => 'This code has expired.';

  @override
  String get newCode => 'Get a new code';

  @override
  String get copyCode => 'Copy';

  @override
  String get copiedCode => 'Copied';

  @override
  String get shareCode => 'Share';

  @override
  String shareText(String code) {
    return 'Join me on Anchor: $code';
  }

  @override
  String pairedMoment(String name) {
    return '$name is here.';
  }

  @override
  String get errInvalidCode =>
      'That code doesn\'t match a pod. Check it with your partner and try again.';

  @override
  String get errTooManyAttempts => 'Let\'s pause a bit. Try again in an hour.';

  @override
  String get errAlreadyInPod => 'You\'re already in a pod.';

  @override
  String get errOffline => 'No connection. Check your internet and try again.';

  @override
  String get errNotConfigured => 'Anchor isn\'t connected to a server yet.';

  @override
  String urgeToldYes(String name) {
    return '$name has been told.';
  }

  @override
  String urgeQueued(String name) {
    return '$name will be told the moment you\'re back online. The next three minutes are yours.';
  }

  @override
  String get urgeStay => 'Stay with me for three minutes.';

  @override
  String get urgeStep1 => 'Stand up.';

  @override
  String get urgeStep2 => 'Drink a glass of water.';

  @override
  String get urgeStep3 => 'Put the phone in another room, or face down.';

  @override
  String get breathIn => 'In.';

  @override
  String get breathOut => 'Out.';

  @override
  String get urgeMistake => 'That was a mistake';

  @override
  String get urgeMistakeSent => 'All clear sent.';

  @override
  String urgeReplyLine(String name, String text) {
    return '$name: $text';
  }

  @override
  String get urgeCall => 'Call';

  @override
  String get urgeText => 'Text';

  @override
  String get urgeEndTitle => 'How are you now?';

  @override
  String get urgeEndPassed => 'It passed';

  @override
  String get urgeEndMore => 'I need more time';

  @override
  String get urgeEndSlipped => 'I slipped';

  @override
  String get urgeHelp => 'Need more than a partner?';

  @override
  String reachingOut(String name) {
    return '$name is reaching out.';
  }

  @override
  String postedUpdate(String name) {
    return '$name posted an update.';
  }

  @override
  String get replyAction => 'Reply';

  @override
  String get replySent => 'Sent.';

  @override
  String get replyHere => 'I\'m here.';

  @override
  String get replyCallMe => 'I\'m here. Call me?';

  @override
  String get replyWalk => 'Walk with me?';

  @override
  String get replyProud => 'Proud of you.';

  @override
  String get replyThankYou => 'Thank you for telling me.';

  @override
  String get replyNewRing => 'Tomorrow is a new ring.';

  @override
  String pushRationaleTitle(String name) {
    return 'Know when $name reaches out';
  }

  @override
  String get pushRationaleBody =>
      'Anchor can notify you quietly. Notifications never say what this app is for.';

  @override
  String get pushEnable => 'Turn on notifications';

  @override
  String get pushNotNow => 'Not now';

  @override
  String get prevMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get legendHeld => 'Held';

  @override
  String get legendSlipped => 'Slipped';

  @override
  String get legendNone => 'Not checked in';

  @override
  String legendSides(String left, String right) {
    return '$left on the left, $right on the right';
  }

  @override
  String get bestStreakLabel => 'Best streak';

  @override
  String get heldThisMonthLabel => 'Held this month';

  @override
  String countDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String dayHabits(int done, int total) {
    return 'Habits $done of $total';
  }

  @override
  String dayPerson(String name, String state) {
    return '$name: $state';
  }

  @override
  String get settingsPartner => 'Partner';

  @override
  String get settingsReminder => 'Daily reminder';

  @override
  String get reminderOff => 'Off';

  @override
  String get reminderDenied =>
      'Notifications are off for Anchor in your phone\'s settings.';

  @override
  String get settingsPartnerNumber => 'Partner\'s number';

  @override
  String get partnerNumberNone => 'Stays on this phone';

  @override
  String partnerNumberHelp(String name) {
    return 'Saved only on this phone. It lets you call or text $name from here.';
  }

  @override
  String get partnerNumberHint => 'Phone number';

  @override
  String get save => 'Save';

  @override
  String get remove => 'Remove';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get on => 'On';

  @override
  String get off => 'Off';

  @override
  String get turnOn => 'Turn on';

  @override
  String get settingsSecure => 'Secure your pod';

  @override
  String get secureSubtitle => 'Without this, a lost phone means a new pod.';

  @override
  String secured(String email) {
    return 'Secured · $email';
  }

  @override
  String get settingsLeave => 'Leave pod';

  @override
  String get leaveTitle => 'Leave this pod?';

  @override
  String leaveBody(String name) {
    return 'You and $name will no longer see each other\'s check-ins. $name will be told your pod has changed. This can\'t be undone.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get endedTitle => 'Your pod has ended.';

  @override
  String get endedBody =>
      'You can still read your history together. Start a new pod when you are ready.';

  @override
  String get endedStart => 'Start a new pod';

  @override
  String get secureTitle => 'Secure your pod';

  @override
  String get secureBody =>
      'Add your email so a lost or replaced phone doesn\'t mean a new pod. We only use it to sign you back in.';

  @override
  String get emailHint => 'Email';

  @override
  String get sendCode => 'Send code';

  @override
  String get codeTitle => 'Enter the code';

  @override
  String codeBody(String email) {
    return 'We sent a 6-digit code to $email.';
  }

  @override
  String get codeHint => '6-digit code';

  @override
  String get verify => 'Verify';

  @override
  String get secureDone => 'Your pod is secured.';

  @override
  String get done => 'Done';

  @override
  String get errInvalidOtp => 'That code didn\'t work. Check it and try again.';

  @override
  String get errEmailInUse => 'That email is already used by another account.';

  @override
  String get secureCardBody => 'Without this, a lost phone means a new pod.';

  @override
  String get secureCardAction => 'Secure it';

  @override
  String get restoreAction => 'I already have an account';

  @override
  String get restoreTitle => 'Welcome back';

  @override
  String get restoreBody => 'Enter the email you secured your pod with.';

  @override
  String get restoreNone => 'We couldn\'t find a pod for that account.';

  @override
  String waitingOn(String name) {
    return 'Waiting on $name';
  }

  @override
  String get inSync => 'In sync';

  @override
  String get sayHello => 'Say hello';

  @override
  String get replyHello => 'Just saying hello.';

  @override
  String get reminderBody => 'Your daily check-in is open.';
}
