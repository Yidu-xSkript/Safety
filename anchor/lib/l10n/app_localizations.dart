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

  /// No description provided for @urgePlaceholderTitle.
  ///
  /// In en, this message translates to:
  /// **'The Urge flow arrives in a later phase.'**
  String get urgePlaceholderTitle;

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

  /// No description provided for @podPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Your pod will live here.'**
  String get podPlaceholder;

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
  /// **'Saved. Tomorrow is a new ring. The tree keeps growing.'**
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

  /// No description provided for @slipBody.
  ///
  /// In en, this message translates to:
  /// **'That takes more than holding a streak does.'**
  String get slipBody;

  /// No description provided for @slipNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add a note (optional)'**
  String get slipNoteHint;

  /// No description provided for @slipSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get slipSave;

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
