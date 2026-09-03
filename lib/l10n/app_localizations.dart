import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Mountain Fairytale'**
  String get appTitle;

  /// No description provided for @deliveryCardTitleToday.
  ///
  /// In en, this message translates to:
  /// **'Delivery on today'**
  String get deliveryCardTitleToday;

  /// No description provided for @deliveryCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery on'**
  String get deliveryCardTitle;

  /// No description provided for @deliveryCardClients.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get deliveryCardClients;

  /// No description provided for @deliveryCardClientsMetrics.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get deliveryCardClientsMetrics;

  /// No description provided for @deliveryCardBottles.
  ///
  /// In en, this message translates to:
  /// **'Bottles'**
  String get deliveryCardBottles;

  /// No description provided for @deliveryCardBottlesMetrics.
  ///
  /// In en, this message translates to:
  /// **'pcs'**
  String get deliveryCardBottlesMetrics;

  /// No description provided for @deliveryCardReturns.
  ///
  /// In en, this message translates to:
  /// **'Returns'**
  String get deliveryCardReturns;

  /// No description provided for @deliveryCardReturnsMetrics.
  ///
  /// In en, this message translates to:
  /// **'pcs'**
  String get deliveryCardReturnsMetrics;

  /// No description provided for @deliveryCardGlasses.
  ///
  /// In en, this message translates to:
  /// **'Glasses'**
  String get deliveryCardGlasses;

  /// No description provided for @deliveryCardGlassesMetrics.
  ///
  /// In en, this message translates to:
  /// **'pcs'**
  String get deliveryCardGlassesMetrics;

  /// No description provided for @deliveryCardWaterCooler.
  ///
  /// In en, this message translates to:
  /// **'Water Cooler'**
  String get deliveryCardWaterCooler;

  /// No description provided for @deliveryCardWaterCoolerMetrics.
  ///
  /// In en, this message translates to:
  /// **'pcs'**
  String get deliveryCardWaterCoolerMetrics;

  /// No description provided for @deliveryCardCoolerRepair.
  ///
  /// In en, this message translates to:
  /// **'Cooler Repair'**
  String get deliveryCardCoolerRepair;

  /// No description provided for @deliveryCardCoolerRepairMetrics.
  ///
  /// In en, this message translates to:
  /// **'pcs'**
  String get deliveryCardCoolerRepairMetrics;

  /// No description provided for @deliveryCardTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get deliveryCardTotal;

  /// No description provided for @deliveryCardTotalMetrics.
  ///
  /// In en, this message translates to:
  /// **'₽'**
  String get deliveryCardTotalMetrics;

  /// No description provided for @notifySaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'File saved successfully'**
  String get notifySaveSuccess;

  /// No description provided for @notifySaveError.
  ///
  /// In en, this message translates to:
  /// **'Error saving file'**
  String get notifySaveError;

  /// No description provided for @notifyWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: amounts in documents differ!'**
  String get notifyWarning;

  /// No description provided for @notifyMergeSuccess.
  ///
  /// In en, this message translates to:
  /// **'Fields from 1c UTD merged'**
  String get notifyMergeSuccess;

  /// No description provided for @resetButton.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get resetButton;

  /// No description provided for @themBottom.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themBottom;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'ru': return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
