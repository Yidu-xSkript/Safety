import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Anchor'**
  String get appName;

  /// No description provided for @tabToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tabToday;

  /// No description provided for @tabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get tabHistory;

  /// No description provided for @tabPod.
  ///
  /// In en, this message translates to:
  /// **'Pod'**
  String get tabPod;

  /// No description provided for @urge.
  ///
  /// In en, this message translates to:
  /// **'Urge'**
  String get urge;

  /// No description provided for @urgeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reach out to your partner'**
  String get urgeTooltip;

  /// No description provided for @daysHeld.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{day held} other{days held}}'**
  String daysHeld(int count);

  /// No description provided for @daysHeldPhrase.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day held} other{{count} days held}}'**
  String daysHeldPhrase(int count);

  /// No description provided for @podStreak.
  ///
  /// In en, this message translates to:
  /// **'Pod streak {count}'**
  String podStreak(int count);

  /// No description provided for @ringStateHeld.
  ///
  /// In en, this message translates to:
  /// **'held'**
  String get ringStateHeld;

  /// No description provided for @ringStateSlipped.
  ///
  /// In en, this message translates to:
  /// **'slipped'**
  String get ringStateSlipped;

  /// No description provided for @ringStateUnchecked.
  ///
  /// In en, this message translates to:
  /// **'not checked in'**
  String get ringStateUnchecked;

  /// No description provided for @slabSemantics.
  ///
  /// In en, this message translates to:
  /// **'{name}: {days}. Today: habits {done} of {total}, pledge {pledge}. Last days: {history}.'**
  String slabSemantics(
    String name,
    String days,
    int done,
    int total,
    String pledge,
    String history,
  );

  /// No description provided for @slabSemanticsNoHistory.
  ///
  /// In en, this message translates to:
  /// **'{name}: {days}. Today: habits {done} of {total}, pledge {pledge}.'**
  String slabSemanticsNoHistory(
    String name,
    String days,
    int done,
    int total,
    String pledge,
  );

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @historyPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Your first ring forms tonight.'**
  String get historyPlaceholder;

  /// No description provided for @genericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our side. Nothing was lost.'**
  String get genericError;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Two people. One honest line a day.'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'A quiet pod for you and one person you trust.'**
  String get welcomeBody;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @notTreatment.
  ///
  /// In en, this message translates to:
  /// **'Anchor supports recovery. It isn\'t treatment or a crisis service.'**
  String get notTreatment;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @nameTitle.
  ///
  /// In en, this message translates to:
  /// **'What should we call you?'**
  String get nameTitle;

  /// No description provided for @nameHint.
  ///
  /// In en, this message translates to:
  /// **'A nickname is fine.'**
  String get nameHint;

  /// No description provided for @nameHelper.
  ///
  /// In en, this message translates to:
  /// **'Your partner will see this. It also appears on notifications.'**
  String get nameHelper;

  /// No description provided for @habitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a few daily habits'**
  String get habitsTitle;

  /// No description provided for @habitsBody.
  ///
  /// In en, this message translates to:
  /// **'Optional. They sit beside your pledge so the day is more than not-doing.'**
  String get habitsBody;

  /// No description provided for @habitMorningPrayer.
  ///
  /// In en, this message translates to:
  /// **'Morning prayer'**
  String get habitMorningPrayer;

  /// No description provided for @habitNightPrayer.
  ///
  /// In en, this message translates to:
  /// **'Night prayer'**
  String get habitNightPrayer;

  /// No description provided for @habitWorkout.
  ///
  /// In en, this message translates to:
  /// **'Workout (30 min)'**
  String get habitWorkout;

  /// No description provided for @habitReading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get habitReading;

  /// No description provided for @habitPhoneAway.
  ///
  /// In en, this message translates to:
  /// **'Phone away by 22:00'**
  String get habitPhoneAway;

  /// No description provided for @addYourOwn.
  ///
  /// In en, this message translates to:
  /// **'Add your own'**
  String get addYourOwn;

  /// No description provided for @addHabitHint.
  ///
  /// In en, this message translates to:
  /// **'Habit name'**
  String get addHabitHint;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @habitsLimit.
  ///
  /// In en, this message translates to:
  /// **'That\'s the most you can add: 8.'**
  String get habitsLimit;

  /// No description provided for @justThePledge.
  ///
  /// In en, this message translates to:
  /// **'Just the pledge for now'**
  String get justThePledge;

  /// No description provided for @startToday.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startToday;

  /// No description provided for @podTitle.
  ///
  /// In en, this message translates to:
  /// **'{you} & {partner}'**
  String podTitle(String you, String partner);

  /// No description provided for @pledgePrompt.
  ///
  /// In en, this message translates to:
  /// **'How was today?'**
  String get pledgePrompt;

  /// No description provided for @heldTheLine.
  ///
  /// In en, this message translates to:
  /// **'Held the line'**
  String get heldTheLine;

  /// No description provided for @iSlipped.
  ///
  /// In en, this message translates to:
  /// **'I slipped'**
  String get iSlipped;

  /// No description provided for @heldAt.
  ///
  /// In en, this message translates to:
  /// **'Held the line · {time}'**
  String heldAt(String time);

  /// No description provided for @slippedAt.
  ///
  /// In en, this message translates to:
  /// **'Slipped · {time}'**
  String slippedAt(String time);

  /// No description provided for @slipSaved.
  ///
  /// In en, this message translates to:
  /// **'Told. Tomorrow is a new ring. The tree keeps growing.'**
  String get slipSaved;

  /// No description provided for @changeAnswer.
  ///
  /// In en, this message translates to:
  /// **'Change today\'s answer'**
  String get changeAnswer;

  /// No description provided for @habitsHeading.
  ///
  /// In en, this message translates to:
  /// **'Habits'**
  String get habitsHeading;

  /// No description provided for @habitsProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String habitsProgress(int done, int total);

  /// No description provided for @slipTitle.
  ///
  /// In en, this message translates to:
  /// **'Thank you for telling the truth.'**
  String get slipTitle;

  /// No description provided for @slipNotYet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get slipNotYet;

  /// No description provided for @weekHeading.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get weekHeading;

  /// No description provided for @weekPersonState.
  ///
  /// In en, this message translates to:
  /// **'{name} {state}'**
  String weekPersonState(String name, String state);

  /// No description provided for @weekDayLabel.
  ///
  /// In en, this message translates to:
  /// **'{date}: {summary}'**
  String weekDayLabel(String date, String summary);

  /// No description provided for @slipBody.
  ///
  /// In en, this message translates to:
  /// **'That takes more than holding a streak does. {name} will see this and can answer you.'**
  String slipBody(String name);

  /// No description provided for @slipNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add a note for {name} (optional)'**
  String slipNoteHint(String name);

  /// No description provided for @slipTell.
  ///
  /// In en, this message translates to:
  /// **'Tell {name}'**
  String slipTell(String name);

  /// No description provided for @heldSeen.
  ///
  /// In en, this message translates to:
  /// **'{name} can see it.'**
  String heldSeen(String name);

  /// No description provided for @queuedNote.
  ///
  /// In en, this message translates to:
  /// **'Saved. Will send when you\'re back online.'**
  String get queuedNote;

  /// No description provided for @pairTitle.
  ///
  /// In en, this message translates to:
  /// **'Pair with one person you trust'**
  String get pairTitle;

  /// No description provided for @pairBody.
  ///
  /// In en, this message translates to:
  /// **'A pod is exactly two people. Nobody else can ever see it.'**
  String get pairBody;

  /// No description provided for @createPod.
  ///
  /// In en, this message translates to:
  /// **'Create a pod'**
  String get createPod;

  /// No description provided for @haveCode.
  ///
  /// In en, this message translates to:
  /// **'I have a code'**
  String get haveCode;

  /// No description provided for @joinTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your partner\'s code'**
  String get joinTitle;

  /// No description provided for @joinHint.
  ///
  /// In en, this message translates to:
  /// **'6-character code'**
  String get joinHint;

  /// No description provided for @joinButton.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get joinButton;

  /// No description provided for @waitingTitle.
  ///
  /// In en, this message translates to:
  /// **'Share this code with the one person you trust.'**
  String get waitingTitle;

  /// No description provided for @codeNote.
  ///
  /// In en, this message translates to:
  /// **'Single use. Expires in 24 hours.'**
  String get codeNote;

  /// No description provided for @codeExpired.
  ///
  /// In en, this message translates to:
  /// **'This code has expired.'**
  String get codeExpired;

  /// No description provided for @newCode.
  ///
  /// In en, this message translates to:
  /// **'Get a new code'**
  String get newCode;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyCode;

  /// No description provided for @copiedCode.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copiedCode;

  /// No description provided for @shareCode.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareCode;

  /// No description provided for @shareText.
  ///
  /// In en, this message translates to:
  /// **'Join me on Anchor: {code}'**
  String shareText(String code);

  /// No description provided for @pairedMoment.
  ///
  /// In en, this message translates to:
  /// **'{name} is here.'**
  String pairedMoment(String name);

  /// No description provided for @errInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'That code doesn\'t match a pod. Check it with your partner and try again.'**
  String get errInvalidCode;

  /// No description provided for @errTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Let\'s pause a bit. Try again in an hour.'**
  String get errTooManyAttempts;

  /// No description provided for @errAlreadyInPod.
  ///
  /// In en, this message translates to:
  /// **'You\'re already in a pod.'**
  String get errAlreadyInPod;

  /// No description provided for @errOffline.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get errOffline;

  /// No description provided for @errNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Anchor isn\'t connected to a server yet.'**
  String get errNotConfigured;

  /// No description provided for @urgeToldYes.
  ///
  /// In en, this message translates to:
  /// **'{name} has been told.'**
  String urgeToldYes(String name);

  /// No description provided for @urgeQueued.
  ///
  /// In en, this message translates to:
  /// **'{name} will be told the moment you\'re back online. The next three minutes are yours.'**
  String urgeQueued(String name);

  /// No description provided for @urgeStay.
  ///
  /// In en, this message translates to:
  /// **'Stay with me for three minutes.'**
  String get urgeStay;

  /// No description provided for @urgeStep1.
  ///
  /// In en, this message translates to:
  /// **'Stand up.'**
  String get urgeStep1;

  /// No description provided for @urgeStep2.
  ///
  /// In en, this message translates to:
  /// **'Drink a glass of water.'**
  String get urgeStep2;

  /// No description provided for @urgeStep3.
  ///
  /// In en, this message translates to:
  /// **'Put the phone in another room, or face down.'**
  String get urgeStep3;

  /// No description provided for @breathIn.
  ///
  /// In en, this message translates to:
  /// **'In.'**
  String get breathIn;

  /// No description provided for @breathOut.
  ///
  /// In en, this message translates to:
  /// **'Out.'**
  String get breathOut;

  /// No description provided for @urgeMistake.
  ///
  /// In en, this message translates to:
  /// **'That was a mistake'**
  String get urgeMistake;

  /// No description provided for @urgeMistakeSent.
  ///
  /// In en, this message translates to:
  /// **'All clear sent.'**
  String get urgeMistakeSent;

  /// No description provided for @urgeReplyLine.
  ///
  /// In en, this message translates to:
  /// **'{name}: {text}'**
  String urgeReplyLine(String name, String text);

  /// No description provided for @urgeCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get urgeCall;

  /// No description provided for @urgeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get urgeText;

  /// No description provided for @urgeEndTitle.
  ///
  /// In en, this message translates to:
  /// **'How are you now?'**
  String get urgeEndTitle;

  /// No description provided for @urgeEndPassed.
  ///
  /// In en, this message translates to:
  /// **'It passed'**
  String get urgeEndPassed;

  /// No description provided for @urgeEndMore.
  ///
  /// In en, this message translates to:
  /// **'I need more time'**
  String get urgeEndMore;

  /// No description provided for @urgeEndSlipped.
  ///
  /// In en, this message translates to:
  /// **'I slipped'**
  String get urgeEndSlipped;

  /// No description provided for @urgeHelp.
  ///
  /// In en, this message translates to:
  /// **'Need more than a partner?'**
  String get urgeHelp;

  /// No description provided for @reachingOut.
  ///
  /// In en, this message translates to:
  /// **'{name} is reaching out.'**
  String reachingOut(String name);

  /// No description provided for @postedUpdate.
  ///
  /// In en, this message translates to:
  /// **'{name} posted an update.'**
  String postedUpdate(String name);

  /// No description provided for @replyAction.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get replyAction;

  /// No description provided for @replySent.
  ///
  /// In en, this message translates to:
  /// **'Sent.'**
  String get replySent;

  /// No description provided for @replyHere.
  ///
  /// In en, this message translates to:
  /// **'I\'m here.'**
  String get replyHere;

  /// No description provided for @replyCallMe.
  ///
  /// In en, this message translates to:
  /// **'I\'m here. Call me?'**
  String get replyCallMe;

  /// No description provided for @replyWalk.
  ///
  /// In en, this message translates to:
  /// **'Walk with me?'**
  String get replyWalk;

  /// No description provided for @replyProud.
  ///
  /// In en, this message translates to:
  /// **'Proud of you.'**
  String get replyProud;

  /// No description provided for @replyThankYou.
  ///
  /// In en, this message translates to:
  /// **'Thank you for telling me.'**
  String get replyThankYou;

  /// No description provided for @replyNewRing.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow is a new ring.'**
  String get replyNewRing;

  /// No description provided for @pushRationaleTitle.
  ///
  /// In en, this message translates to:
  /// **'Know when {name} reaches out'**
  String pushRationaleTitle(String name);

  /// No description provided for @pushRationaleBody.
  ///
  /// In en, this message translates to:
  /// **'Anchor can notify you quietly. Notifications never say what this app is for.'**
  String get pushRationaleBody;

  /// No description provided for @pushEnable.
  ///
  /// In en, this message translates to:
  /// **'Turn on notifications'**
  String get pushEnable;

  /// No description provided for @pushNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get pushNotNow;

  /// No description provided for @prevMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get prevMonth;

  /// No description provided for @nextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// No description provided for @legendHeld.
  ///
  /// In en, this message translates to:
  /// **'Held'**
  String get legendHeld;

  /// No description provided for @legendSlipped.
  ///
  /// In en, this message translates to:
  /// **'Slipped'**
  String get legendSlipped;

  /// No description provided for @legendNone.
  ///
  /// In en, this message translates to:
  /// **'Not checked in'**
  String get legendNone;

  /// No description provided for @legendSides.
  ///
  /// In en, this message translates to:
  /// **'{left} on the left, {right} on the right'**
  String legendSides(String left, String right);

  /// No description provided for @bestStreakLabel.
  ///
  /// In en, this message translates to:
  /// **'Best streak'**
  String get bestStreakLabel;

  /// No description provided for @heldThisMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'Held this month'**
  String get heldThisMonthLabel;

  /// No description provided for @countDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String countDays(int count);

  /// No description provided for @dayHabits.
  ///
  /// In en, this message translates to:
  /// **'Habits {done} of {total}'**
  String dayHabits(int done, int total);

  /// No description provided for @dayPerson.
  ///
  /// In en, this message translates to:
  /// **'{name}: {state}'**
  String dayPerson(String name, String state);

  /// No description provided for @settingsPartner.
  ///
  /// In en, this message translates to:
  /// **'Partner'**
  String get settingsPartner;

  /// No description provided for @settingsReminder.
  ///
  /// In en, this message translates to:
  /// **'Daily reminder'**
  String get settingsReminder;

  /// No description provided for @reminderOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get reminderOff;

  /// No description provided for @reminderDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off for Anchor in your phone\'s settings.'**
  String get reminderDenied;

  /// No description provided for @settingsPartnerNumber.
  ///
  /// In en, this message translates to:
  /// **'Partner\'s number'**
  String get settingsPartnerNumber;

  /// No description provided for @partnerNumberNone.
  ///
  /// In en, this message translates to:
  /// **'Stays on this phone'**
  String get partnerNumberNone;

  /// No description provided for @partnerNumberHelp.
  ///
  /// In en, this message translates to:
  /// **'Saved only on this phone. It lets you call or text {name} from here.'**
  String partnerNumberHelp(String name);

  /// No description provided for @partnerNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get partnerNumberHint;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @turnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get turnOn;

  /// No description provided for @settingsSecure.
  ///
  /// In en, this message translates to:
  /// **'Secure your pod'**
  String get settingsSecure;

  /// No description provided for @secureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Without this, a lost phone means a new pod.'**
  String get secureSubtitle;

  /// No description provided for @secured.
  ///
  /// In en, this message translates to:
  /// **'Secured · {email}'**
  String secured(String email);

  /// No description provided for @settingsLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave pod'**
  String get settingsLeave;

  /// No description provided for @leaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this pod?'**
  String get leaveTitle;

  /// No description provided for @leaveBody.
  ///
  /// In en, this message translates to:
  /// **'You and {name} will no longer see each other\'s check-ins. {name} will be told your pod has changed. This can\'t be undone.'**
  String leaveBody(String name);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @endedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your pod has ended.'**
  String get endedTitle;

  /// No description provided for @endedBody.
  ///
  /// In en, this message translates to:
  /// **'You can still read your history together. Start a new pod when you are ready.'**
  String get endedBody;

  /// No description provided for @endedStart.
  ///
  /// In en, this message translates to:
  /// **'Start a new pod'**
  String get endedStart;

  /// No description provided for @secureTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure your pod'**
  String get secureTitle;

  /// No description provided for @secureBody.
  ///
  /// In en, this message translates to:
  /// **'Add your email so a lost or replaced phone doesn\'t mean a new pod. We only use it to sign you back in.'**
  String get secureBody;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailHint;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCode;

  /// No description provided for @codeTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get codeTitle;

  /// No description provided for @codeBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {email}.'**
  String codeBody(String email);

  /// No description provided for @codeHint.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get codeHint;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @secureDone.
  ///
  /// In en, this message translates to:
  /// **'Your pod is secured.'**
  String get secureDone;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @errInvalidOtp.
  ///
  /// In en, this message translates to:
  /// **'That code didn\'t work. Check it and try again.'**
  String get errInvalidOtp;

  /// No description provided for @errEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'That email is already used by another account.'**
  String get errEmailInUse;

  /// No description provided for @secureCardBody.
  ///
  /// In en, this message translates to:
  /// **'Without this, a lost phone means a new pod.'**
  String get secureCardBody;

  /// No description provided for @secureCardAction.
  ///
  /// In en, this message translates to:
  /// **'Secure it'**
  String get secureCardAction;

  /// No description provided for @restoreAction.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get restoreAction;

  /// No description provided for @restoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get restoreTitle;

  /// No description provided for @restoreBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the email you secured your pod with.'**
  String get restoreBody;

  /// No description provided for @restoreNone.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find a pod for that account.'**
  String get restoreNone;

  /// No description provided for @waitingOn.
  ///
  /// In en, this message translates to:
  /// **'Waiting on {name}'**
  String waitingOn(String name);

  /// No description provided for @inSync.
  ///
  /// In en, this message translates to:
  /// **'In sync'**
  String get inSync;

  /// No description provided for @sayHello.
  ///
  /// In en, this message translates to:
  /// **'Say hello'**
  String get sayHello;

  /// No description provided for @replyHello.
  ///
  /// In en, this message translates to:
  /// **'Just saying hello.'**
  String get replyHello;

  /// No description provided for @reminderBody.
  ///
  /// In en, this message translates to:
  /// **'Your daily check-in is open.'**
  String get reminderBody;

  /// No description provided for @lockTitle.
  ///
  /// In en, this message translates to:
  /// **'Anchor is locked'**
  String get lockTitle;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @lockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Anchor'**
  String get lockReason;

  /// No description provided for @settingsAppLock.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get settingsAppLock;

  /// No description provided for @appLockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Face, fingerprint or your phone\'s passcode'**
  String get appLockSubtitle;

  /// No description provided for @appLockUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available on this phone'**
  String get appLockUnavailable;

  /// No description provided for @settingsHide.
  ///
  /// In en, this message translates to:
  /// **'Hide in app switcher'**
  String get settingsHide;

  /// No description provided for @hideSubtitleAndroid.
  ///
  /// In en, this message translates to:
  /// **'Shows nothing when you switch apps. Also blocks screenshots.'**
  String get hideSubtitleAndroid;

  /// No description provided for @hideSubtitleIos.
  ///
  /// In en, this message translates to:
  /// **'Shows nothing when you switch apps.'**
  String get hideSubtitleIos;

  /// No description provided for @settingsExport.
  ///
  /// In en, this message translates to:
  /// **'Export my data'**
  String get settingsExport;

  /// No description provided for @exportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Everything you have saved, as a file'**
  String get exportSubtitle;

  /// No description provided for @settingsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDelete;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteBodyPod.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your check-ins, habits and notes from our servers and from this phone. {name} will be told your pod has changed. This can\'t be undone.'**
  String deleteBodyPod(String name);

  /// No description provided for @deleteBodySolo.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes everything Anchor has stored, on this phone and on our servers. This can\'t be undone.'**
  String get deleteBodySolo;

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get deleteConfirm;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t prepare your data. Check your connection and try again.'**
  String get exportFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
