import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_cs.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_fi.dart';
import 'app_localizations_fil.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_id.dart';
import 'app_localizations_it.dart';
import 'app_localizations_lt.dart';
import 'app_localizations_ms.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_th.dart';
import 'app_localizations_uk.dart';
import 'app_localizations_zh.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('bn'),
    Locale('cs'),
    Locale('en'),
    Locale('es'),
    Locale('fa'),
    Locale('fi'),
    Locale('fil'),
    Locale('fr'),
    Locale('hi'),
    Locale('id'),
    Locale('it'),
    Locale('lt'),
    Locale('ms'),
    Locale('pt'),
    Locale('ru'),
    Locale('th'),
    Locale('uk'),
    Locale('zh'),
  ];

  /// used on bottom_navigation.dart
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// used on bottom_navigation.dart
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// used on bottom_navigation and on Settings tab
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// used on the language selector
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// used on the language selector
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// used on the item detail page
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// used on the search bar
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get hintText;

  /// used on the search bar
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get default1;

  /// used on the search bar
  ///
  /// In en, this message translates to:
  /// **'Creators'**
  String get creators;

  /// used on startup app
  ///
  /// In en, this message translates to:
  /// **'Checking keys'**
  String get checkingKeys;

  /// used on startup app
  ///
  /// In en, this message translates to:
  /// **'API Login'**
  String get apiLogin;

  /// Toast message showing how many new keys were added
  ///
  /// In en, this message translates to:
  /// **'Added {keyCount} new keys'**
  String addedNewKeys(int keyCount);

  /// when no dlc found
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResult;

  /// open button
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// clear button
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// Used on the bottom sheet creator
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// OK button
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Queue position
  ///
  /// In en, this message translates to:
  /// **'Queued (Position #{count})'**
  String queuePosition(int count);

  /// Queue position
  ///
  /// In en, this message translates to:
  /// **'Queued #{count})'**
  String queuePosition2(int count);

  /// Message shown when an image is successfully saved
  ///
  /// In en, this message translates to:
  /// **'Image saved to {filePath}'**
  String imageSaved(String filePath);

  /// Error message shown when image download fails
  ///
  /// In en, this message translates to:
  /// **'Error downloading image: {error}'**
  String errorDownloadingImage(String error);

  /// used on the item detail page
  ///
  /// In en, this message translates to:
  /// **'Changelog'**
  String get changelog;

  /// used on the item detail page
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloaded;

  /// used on the item detail page
  ///
  /// In en, this message translates to:
  /// **'Retry Download'**
  String get retryDownload;

  /// used on the item detail page
  ///
  /// In en, this message translates to:
  /// **'Download Image'**
  String get downloadImage;

  /// used on the item detail page
  ///
  /// In en, this message translates to:
  /// **'Download this image?'**
  String get downloadImageQuestion;

  /// used on the item detail page
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// trailer button on item detail page
  ///
  /// In en, this message translates to:
  /// **'Watch Trailer'**
  String get trailer;

  /// Error message for trailer
  ///
  /// In en, this message translates to:
  /// **'Could not open trailer: {error}'**
  String trailerError(String error);

  /// Used on the settings tab
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// Used on the settings tab
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// Used on the settings tab
  ///
  /// In en, this message translates to:
  /// **'Dark theme enabled'**
  String get darkEnabled;

  /// Used on the settings tab
  ///
  /// In en, this message translates to:
  /// **'Light theme enabled'**
  String get lightEnabled;

  /// Used on the settings tab
  ///
  /// In en, this message translates to:
  /// **'Color Scheme'**
  String get colorScheme;

  /// Used on the settings tab
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultColor;

  /// Used on the settings tab
  ///
  /// In en, this message translates to:
  /// **'Default (Purple)'**
  String get defaultPurple;

  /// Display name for blue color scheme
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorSchemeBlue;

  /// Display name for green color scheme
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorSchemeGreen;

  /// Display name for orange color scheme
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get colorSchemeOrange;

  /// Display name for red color scheme
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get colorSchemeRed;

  /// Display name for teal color scheme
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get colorSchemeTeal;

  /// Display name for pink color scheme
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get colorSchemePink;

  /// Display name for lime color scheme
  ///
  /// In en, this message translates to:
  /// **'Lime'**
  String get colorSchemeLime;

  /// Used on the settings tab
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// Used on the settings tab
  ///
  /// In en, this message translates to:
  /// **'Filter:'**
  String get filter;

  /// Used on the settings tab
  ///
  /// In en, this message translates to:
  /// **'Show skins'**
  String get showSkins;

  /// Used on the settings tab
  ///
  /// In en, this message translates to:
  /// **'Keys'**
  String get keys;

  /// Used on the settings tab, auto update for the keys
  ///
  /// In en, this message translates to:
  /// **'Auto-update'**
  String get autoUpdate;

  /// Used on the settings tab
  ///
  /// In en, this message translates to:
  /// **'Custom DB'**
  String get customDb;

  /// Used on the settings tab
  ///
  /// In en, this message translates to:
  /// **'Account login'**
  String get accountLogin;

  /// Used on the settings tab
  ///
  /// In en, this message translates to:
  /// **'Extras'**
  String get extras;

  /// Used on the settings tab
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get cache;

  /// Message shown when cache is cleared
  ///
  /// In en, this message translates to:
  /// **'Cleared {size} MB of cache'**
  String cacheCleared(String size);

  /// Used on the settings tab
  ///
  /// In en, this message translates to:
  /// **'Faq'**
  String get faq;

  /// Used on faq page
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faqUppercase;

  /// Used on the settings tab
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get terminal;

  /// Used on faq page
  ///
  /// In en, this message translates to:
  /// **'Please add the keys for this and that pack!'**
  String get faqQuestion1;

  /// Used on faq page
  ///
  /// In en, this message translates to:
  /// **'When are the keys going to be updated?'**
  String get faqQuestion2;

  /// Used on faq page
  ///
  /// In en, this message translates to:
  /// **'What\'s the difference between encrypted and decrypted?'**
  String get faqQuestion3;

  /// Used on faq page
  ///
  /// In en, this message translates to:
  /// **'Where can I find the downloaded packs?'**
  String get faqQuestion4;

  /// Used on faq page
  ///
  /// In en, this message translates to:
  /// **'What is keys.tsv?'**
  String get faqQuestion5;

  /// Used on faq page
  ///
  /// In en, this message translates to:
  /// **'How can i use Persona items?'**
  String get faqQuestion6;

  /// Used on faq page
  ///
  /// In en, this message translates to:
  /// **'Why do some skin packs appear broken?'**
  String get faqQuestion7;

  /// Used on faq page
  ///
  /// In en, this message translates to:
  /// **'What\'s the purpose of the \"Account Login\" page?'**
  String get faqQuestion8;

  /// Used on faq page
  ///
  /// In en, this message translates to:
  /// **'What does the checkmark mean?'**
  String get faqQuestion9;

  /// Answer for FAQ question 1
  ///
  /// In en, this message translates to:
  /// **'The process of obtaining the keys is not magic: a person still has to buy the pack and share the keys with us. Without somebody buying it there would be no decryption keys in the first place. It is not possible to obtain them in any other way. Wait patiently or buy it.'**
  String get faqAnswer1;

  /// Answer for FAQ question 2
  ///
  /// In en, this message translates to:
  /// **'Once we decide to.'**
  String get faqAnswer2;

  /// Answer for FAQ question 3
  ///
  /// In en, this message translates to:
  /// **'Encrypted means turning the file into scrambled words that look like gibberish. No one can read it without a special key. Encrypted Minecraft contents are unplayable.\n\nDecrypted means using the special key to turn the gibberish back into the original content. Now the Minecraft contents can be used.'**
  String get faqAnswer3;

  /// Answer for FAQ question 4
  ///
  /// In en, this message translates to:
  /// **'You can find the packs here Download/Kyzen'**
  String get faqAnswer4;

  /// Answer for FAQ question 5
  ///
  /// In en, this message translates to:
  /// **'It\'s a file that stores the pack UUID\'s with their respective decryption keys. Without the decryption keys downloaded packs would be unplayable.'**
  String get faqAnswer5;

  /// Answer for FAQ question 6
  ///
  /// In en, this message translates to:
  /// **'U can\'t. They do exist some methods but given the complexity to be done, it is not feasible.'**
  String get faqAnswer6;

  /// Answer for FAQ question 7
  ///
  /// In en, this message translates to:
  /// **'Some skin packs (especially franchise collabs) use custom geometry which Minecraft doesn\'t allow to be used normally unless u buy the skin pack. U can check if a skin pack uses custom geometry by checking if the file \"geometry.json\" exists in the pack. Keep in mind that this issue is not related to the tool in any way.'**
  String get faqAnswer7;

  /// Answer for FAQ question 8
  ///
  /// In en, this message translates to:
  /// **'The account login page allows you to authenticate with your Microsoft account to directly load your Minecraft keys from your inventory.\nThis is useful when Kyzen doesn’t currently have a key available for a specific DLC but you do have it in your account, once your keys are loaded that DLC will appear available for download. \nNote that the keys are automatically uploaded to our database, where they will later be merged with Kyzen’s main key database so everyone can enjoy the new dlc, so please use this feature if u wanna contribute.'**
  String get faqAnswer8;

  /// Answer for FAQ question 9. checkmark ok
  ///
  /// In en, this message translates to:
  /// **'The key for this DLC is available.'**
  String get faqAnswer9Checkmark;

  /// Answer for FAQ question 9. no checkmark
  ///
  /// In en, this message translates to:
  /// **'The app currently does not have the key for this DLC.'**
  String get faqAnswer9NoCheckmark;

  /// Extra information for FAQ question 9
  ///
  /// In en, this message translates to:
  /// **'Keys are required to unlock the DLCs.'**
  String get faqAnswer9ExtraInfo;

  /// Used on the item detail page
  ///
  /// In en, this message translates to:
  /// **'Why is the download button unavailable?'**
  String get faqQuestionDownload;

  /// Answer for faq download item detail page
  ///
  /// In en, this message translates to:
  /// **'The key to unlock this dlc is not available, wait patiently or buy it.'**
  String get faqAnswerDownload;

  /// used on the item detail page
  ///
  /// In en, this message translates to:
  /// **'How do i get the key?'**
  String get faqQuestionKey;

  /// Answer for faq key item detail page
  ///
  /// In en, this message translates to:
  /// **'Buy the dlc on your account then go to settings > Account login > Click \'Start authentication\' > click \'Load keys\', now click \'Share\' and share the keys files to the Bluecoin chat, the keys are going to be added to the app database. if u can\'t share the keys file to the group, don\'t worry, the keys get automatically uploaded to a database.'**
  String get faqAnswerKey;

  /// Used on the pop up dialog faq item detail page
  ///
  /// In en, this message translates to:
  /// **'More help'**
  String get faqMoreHelp;

  /// used on the item detail page for non-dlc items
  ///
  /// In en, this message translates to:
  /// **'Not a DLC'**
  String get faqNotAdlc;

  /// used on the item detail page for non-dlc items
  ///
  /// In en, this message translates to:
  /// **'This item is not a DLC.'**
  String get faqNotAdlcDescription;

  /// Used on the faq item detail page
  ///
  /// In en, this message translates to:
  /// **'Server content'**
  String get faqServerContent;

  /// Used on the faq item detail page
  ///
  /// In en, this message translates to:
  /// **'This item is exclusive to a specific server and cannot be downloaded directly.'**
  String get faqServerContentDescription;

  /// Used on the downloads tab
  ///
  /// In en, this message translates to:
  /// **'File deleted'**
  String get fileDeleted;

  /// Used on the downloads tab
  ///
  /// In en, this message translates to:
  /// **'Stored Files'**
  String get storedFiles;

  /// Used on the downloads tab
  ///
  /// In en, this message translates to:
  /// **'Refresh files'**
  String get refreshFiles;

  /// Title for delete file confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete File'**
  String get deleteFile;

  /// Confirmation message for deleting a file
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {fileName}?'**
  String deleteFileConfirmation(String fileName);

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get cancelUppercase;

  /// Delete button
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteUppercase;

  /// Used on the downloads tab
  ///
  /// In en, this message translates to:
  /// **'Current Download'**
  String get currentDownload;

  /// Used on the downloads tab
  ///
  /// In en, this message translates to:
  /// **'No active downloads'**
  String get noActiveDownloads;

  /// Used on the downloads tab
  ///
  /// In en, this message translates to:
  /// **'Completed Downloads'**
  String get completedDownloads;

  /// Used on the downloads tab
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// Used on the downloads tab
  ///
  /// In en, this message translates to:
  /// **'Import to Minecraft'**
  String get importToMc;

  /// Used on the downloads tab but only for desktop
  ///
  /// In en, this message translates to:
  /// **'Open in file explorer'**
  String get openFileinExplorer;

  /// Used on the downloads tab
  ///
  /// In en, this message translates to:
  /// **'Share file'**
  String get shareFile;

  /// Used on debug page
  ///
  /// In en, this message translates to:
  /// **'Debug Terminal'**
  String get debugTerminal;

  /// Used on debug page
  ///
  /// In en, this message translates to:
  /// **'Clear logs'**
  String get clearLogs;

  /// Used on debug page
  ///
  /// In en, this message translates to:
  /// **'No logs yet...'**
  String get noLogs;

  /// Used on debug page
  ///
  /// In en, this message translates to:
  /// **'Save logs'**
  String get saveLogs;

  /// Message shown when logs are saved
  ///
  /// In en, this message translates to:
  /// **'Logs saved to {filePath}'**
  String logsSaved(String filePath);

  /// Used on the custom db page
  ///
  /// In en, this message translates to:
  /// **'Selecting file...'**
  String get selectingFile;

  /// Used on the custom db page
  ///
  /// In en, this message translates to:
  /// **'Processing file...'**
  String get processingFile;

  /// Used on the custom db page
  ///
  /// In en, this message translates to:
  /// **'File processed successfully!'**
  String get fileProcessed;

  /// Used on the custom db page
  ///
  /// In en, this message translates to:
  /// **'No file selected'**
  String get noFileSelected;

  /// Used on the custom db page
  ///
  /// In en, this message translates to:
  /// **'{count} custom keys loaded'**
  String customKeysLoaded(int count);

  /// Used on the custom db page
  ///
  /// In en, this message translates to:
  /// **'No custom keys loaded'**
  String get noCustomKeysLoaded;

  /// Used on the custom db page
  ///
  /// In en, this message translates to:
  /// **'Import a file with UUID=KEY format'**
  String get importFileFormat;

  /// Used on the bottom sheet creator
  ///
  /// In en, this message translates to:
  /// **'{contentType} Items'**
  String creatorItemsWithType(String contentType);

  /// Used on the bottom sheet creator
  ///
  /// In en, this message translates to:
  /// **'{contentType} Items ({count})'**
  String creatorItemsWithTypeAndCount(String contentType, int count);

  /// Used on the bottom sheet creator
  ///
  /// In en, this message translates to:
  /// **'Creator Items'**
  String get creatorItemsDefault;

  /// Used on the bottom sheet creator
  ///
  /// In en, this message translates to:
  /// **'This creator has no content'**
  String get noItemCreator;

  /// Used on the bottom sheet creator
  ///
  /// In en, this message translates to:
  /// **'No statistics available'**
  String get noStatistic;

  /// Used on the bottom sheet creator
  ///
  /// In en, this message translates to:
  /// **'Failed to load statistics'**
  String get failedLoadStatistic;

  /// Used on the bottom sheet creator
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Microsoft Authentication'**
  String get microsoftAuth;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Exchanging authorization code for token...'**
  String get exchangingToken;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Authentication failed: {error}'**
  String authenticationFailed(String error);

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Authentication successful!'**
  String get authenticationSuccessful;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Failed to exchange code for token: {error}'**
  String failedToExchangeToken(String error);

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'No authorization code received'**
  String get noAuthorizationCodeReceived;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'No new keys found to copy'**
  String get noNewKeysCopy;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Keys copied to clipboard!'**
  String get keysCopyClipboard;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'No new keys found to share'**
  String get noNewKeysShare;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Keys shared successfully!'**
  String get keysShared;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Checking existing authentication...'**
  String get authCheck;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Already authenticated!'**
  String get alreadyAuth;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Ready to authenticate'**
  String get readyAuth;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Authenticate with the URL'**
  String get authURL;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Complete Authentication'**
  String get completeAuthButton;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Open Auth Page'**
  String get openAuthPageButton;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Complete authentication in your browser. You will be redirected back to the app.'**
  String get completeAuth;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Copy URL'**
  String get copyUrl;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Could not open authentication page'**
  String get authPageFail;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Logging out...'**
  String get logout;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Logged out successfully'**
  String get logoutOk;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Using cached session...'**
  String get usingCachedSession;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Loading Minecraft keys...'**
  String get loadingMinecraftKeys;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Requesting Xbox Live token...'**
  String get requestingXboxLiveToken;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Logging in to PlayFab...'**
  String get loggingInToPlayFab;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Getting user information...'**
  String get gettingUserInformation;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Starting Minecraft session...'**
  String get startingMinecraftSession;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Loading Minecraft inventory...'**
  String get loadingMinecraftInventory;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Successfully loaded {keyCount} keys!'**
  String successfullyLoadedKeys(int keyCount);

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Error loading keys: {error}'**
  String errorLoadingKeys(String error);

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copyClipboard;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Authenticated'**
  String get authOk;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Not Authenticated'**
  String get authNotOk;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Authentication URL'**
  String get urlAuth;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Loaded Keys'**
  String get loadedKeys;

  /// Used on the auth page and mcdecryptor page
  ///
  /// In en, this message translates to:
  /// **'Export only new keys'**
  String get exportNewKeys;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Load Keys'**
  String get loadKeysButton;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutButton;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Start Authentication'**
  String get startAuthButton;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Hi '**
  String get greetings;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// Used on the auth page
  ///
  /// In en, this message translates to:
  /// **'Keys saved successfully'**
  String get keysSaved;

  /// Used on the download service
  ///
  /// In en, this message translates to:
  /// **'Starting download...'**
  String get startingDownload;

  /// Status when all downloads are finished
  ///
  /// In en, this message translates to:
  /// **'Downloads completed'**
  String get downloadsCompleted;

  /// Final completion status
  ///
  /// In en, this message translates to:
  /// **'Completed!'**
  String get completed;

  /// Error status when download fails
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get downloadFailed;

  /// Status during download progress
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloading;

  /// Status during file processing
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get processing;

  /// Status message when extracting zip files during DLC processing
  ///
  /// In en, this message translates to:
  /// **'Extracting zip file...'**
  String get extractingZipFile;

  /// Status message when decrypting DLC contents
  ///
  /// In en, this message translates to:
  /// **'Decrypting contents...'**
  String get decryptingContents;

  /// Status message when compressing the final pack
  ///
  /// In en, this message translates to:
  /// **'Compressing pack...'**
  String get compressingPack;

  /// Status message when cleaning up temporary files
  ///
  /// In en, this message translates to:
  /// **'Cleaning up...'**
  String get cleaningUp;

  /// Used for key filter
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get showAll;

  /// Used for key filter
  ///
  /// In en, this message translates to:
  /// **'Only available'**
  String get onlyAvailable;

  /// Used for key filter
  ///
  /// In en, this message translates to:
  /// **'Only not available'**
  String get onlyNotAvailable;

  /// Used on the settings tab
  ///
  /// In en, this message translates to:
  /// **'Custom Color'**
  String get customColor;

  /// Used on the settings tab
  ///
  /// In en, this message translates to:
  /// **'Tap to change your custom color'**
  String get changeCustomColor;

  /// Used on the settings tab
  ///
  /// In en, this message translates to:
  /// **'Create your own color scheme'**
  String get createCustomColor;

  /// Used on the settings tab
  ///
  /// In en, this message translates to:
  /// **'Pick Color'**
  String get pickColor;

  /// Button to select color on color picker dialog
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get selectColor;

  /// Used on the Images section of the settings tab
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get images;

  /// Button to save image as PNG on the settings tab
  ///
  /// In en, this message translates to:
  /// **'Save to PNG'**
  String get saveToPng;

  /// Button to save image to gallery on the settings tab
  ///
  /// In en, this message translates to:
  /// **'Save to Gallery'**
  String get saveToGallery;

  /// Used on the settings tab
  ///
  /// In en, this message translates to:
  /// **'Compression'**
  String get compression;

  /// Used on the settings tab
  ///
  /// In en, this message translates to:
  /// **'Normal Compression'**
  String get normalCompression;

  /// Used on the settings tab
  ///
  /// In en, this message translates to:
  /// **'No Compression'**
  String get noCompression;

  /// Button to copy UUID to clipboard on the item detail page
  ///
  /// In en, this message translates to:
  /// **'Copy UUID'**
  String get copyUUID;

  /// Button to open the item pack in Minecraft on the item detail page
  ///
  /// In en, this message translates to:
  /// **'Open in Minecraft'**
  String get openInMinecraft;

  /// Button to open the bottom sheet creator on the item detail page
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get creator;

  /// Button to add an item to the cart
  ///
  /// In en, this message translates to:
  /// **'Add to Cart'**
  String get addToCart;

  /// Button to remove an item from the cart
  ///
  /// In en, this message translates to:
  /// **'Remove from Cart'**
  String get removeFromCart;

  /// Message shown when an item is added to the cart
  ///
  /// In en, this message translates to:
  /// **'Added to cart'**
  String get addedToCart;

  /// Message shown when an item is removed from the cart
  ///
  /// In en, this message translates to:
  /// **'Removed from cart'**
  String get removedFromCart;

  /// Message shown when trying to add an item to the cart without being authenticated
  ///
  /// In en, this message translates to:
  /// **'Authentication required'**
  String get authRequired;

  /// Message shown when trying to add an item to the cart without being authenticated
  ///
  /// In en, this message translates to:
  /// **'You need to be fully authenticated to view your cart. Please authenticate from the Account login page.'**
  String get authRequiredDesc;

  /// Used on the dropdown filter
  ///
  /// In en, this message translates to:
  /// **'New update'**
  String get newUpdate;

  /// Used on the dropdown filter
  ///
  /// In en, this message translates to:
  /// **'New dlc'**
  String get newDlc;

  /// Used on the dropdown filter
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get hidden;

  /// Used on the dropdown filter
  ///
  /// In en, this message translates to:
  /// **'Persona'**
  String get persona;

  /// Used on the dropdown filter
  ///
  /// In en, this message translates to:
  /// **'Skins'**
  String get skins;

  /// Used on the dropdown filter
  ///
  /// In en, this message translates to:
  /// **'Mashups'**
  String get mashups;

  /// Used on the dropdown filter
  ///
  /// In en, this message translates to:
  /// **'Worlds'**
  String get worlds;

  /// Used on the dropdown filter
  ///
  /// In en, this message translates to:
  /// **'Textures'**
  String get textures;

  /// Used on the dropdown filter
  ///
  /// In en, this message translates to:
  /// **'Add-Ons'**
  String get addons;

  /// Used on the bottom sheet for the mojang creator
  ///
  /// In en, this message translates to:
  /// **'Capes'**
  String get capes;

  /// Used on the dropdown filter
  ///
  /// In en, this message translates to:
  /// **'Vibrant visuals'**
  String get vibrantVisuals;

  /// Used on the dropdown filter
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// Used on the dropdown filter
  ///
  /// In en, this message translates to:
  /// **'Unfiltered'**
  String get unfiltered;

  /// Used on the dropdown filter
  ///
  /// In en, this message translates to:
  /// **'Sorting'**
  String get sorting;

  /// Used on the dropdown filter
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// Used on the dropdown filter
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newFilter;

  /// Used on the dropdown filter
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// Used on the dropdown filter
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get newest;

  /// Used on the dropdown filter
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get oldest;

  /// Used on the dropdown filter
  ///
  /// In en, this message translates to:
  /// **'Most Rated'**
  String get mostRated;

  /// Used on the dropdown filter
  ///
  /// In en, this message translates to:
  /// **'Least Rated'**
  String get leastRated;

  /// tooltip for menu button
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// Message shown when an image is saved to gallery
  ///
  /// In en, this message translates to:
  /// **'Image saved to gallery: {filePath}'**
  String imageSavedToGallery(String filePath);

  /// used on the item detail page
  ///
  /// In en, this message translates to:
  /// **'Vibrant Visuals Enhanced'**
  String get vibrantVisualEnhanced;

  /// message shown when UUID is copied to clipboard
  ///
  /// In en, this message translates to:
  /// **'UUID copied to clipboard'**
  String get uuidCopied;

  /// tooltip for scrolling right for desktop
  ///
  /// In en, this message translates to:
  /// **'Scroll right'**
  String get scrollRight;

  /// tooltip for scrolling left for desktop
  ///
  /// In en, this message translates to:
  /// **'Scroll left'**
  String get scrollLeft;

  /// tooltip for previous image button for desktop
  ///
  /// In en, this message translates to:
  /// **'Previous image'**
  String get previousImage;

  /// tooltip for next image button for desktop
  ///
  /// In en, this message translates to:
  /// **'Next image'**
  String get nextImage;

  /// shown when there is no favorite items
  ///
  /// In en, this message translates to:
  /// **'Your favorites list is empty'**
  String get favoriteEmpty;

  /// shown when there is no favorite items
  ///
  /// In en, this message translates to:
  /// **'Tap the heart icon on any item\'s details page to add it to your favorites and build your collection'**
  String get favoriteDescription;

  /// tooltip for removing item from favorites
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFromFavorites;

  /// tooltip for adding item to favorites
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addToFavorites;

  /// message shown when an item is added to favorites
  ///
  /// In en, this message translates to:
  /// **'Added to favorites'**
  String get addedToFavorites;

  /// message shown when an item is removed from favorites
  ///
  /// In en, this message translates to:
  /// **'Removed from favorites'**
  String get removedFromFavorites;

  /// Used on the Mcdecryptor page
  ///
  /// In en, this message translates to:
  /// **'No keys found to save'**
  String get noNewKeysFoundToSave;

  /// Used on the Mcdecryptor page and auth page
  ///
  /// In en, this message translates to:
  /// **'Keys saved successfully into the Kyzen folder.'**
  String get keysSavedSuccessfully;

  /// Used on the Mcdecryptor page
  ///
  /// In en, this message translates to:
  /// **'Entitlement Keys'**
  String get entitlementKeys;

  /// Used on the Mcdecryptor page
  ///
  /// In en, this message translates to:
  /// **'Search your Minecraft bought content.'**
  String get searchBoughContent;

  /// Used on the Mcdecryptor page
  ///
  /// In en, this message translates to:
  /// **'Save Keys'**
  String get saveKeys;

  /// Used on the Mcdecryptor page
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Used on the Mcdecryptor page
  ///
  /// In en, this message translates to:
  /// **'Search Keys'**
  String get searchKeys;

  /// Used on the Mcdecryptor page
  ///
  /// In en, this message translates to:
  /// **'Load SkinPack/Persona'**
  String get loadSkinPersona;

  /// Used on the Mcdecryptor page
  ///
  /// In en, this message translates to:
  /// **'Include skinpack and persona on the list'**
  String get descriptionSkinPersona;

  /// Used on the Mcdecryptor page
  ///
  /// In en, this message translates to:
  /// **'Load only new keys'**
  String get loadOnlyNewKeys;

  /// Used on the Mcdecryptor page
  ///
  /// In en, this message translates to:
  /// **'Load only content not present on the app keys database'**
  String get descriptionLoadOnlyNewKeys;

  /// Used on the Mcdecryptor page
  ///
  /// In en, this message translates to:
  /// **'Whether \"save keys\" should only export new keys'**
  String get descriptionExportNewKeys;

  /// Used on the Mcdecryptor page
  ///
  /// In en, this message translates to:
  /// **'Successfully Processed ({countFiles} files, {countKeys} keys)'**
  String processedEntitlementKeys(int countFiles, int countKeys);

  /// Used on the Mcdecryptor page
  ///
  /// In en, this message translates to:
  /// **'No results yet'**
  String get noResultsYet;

  /// Used on the Mcdecryptor page
  ///
  /// In en, this message translates to:
  /// **'Click \"Search Keys\" to load your content'**
  String get clickSearchKeysToLoadContent;

  /// Used on the Mcdecryptor page
  ///
  /// In en, this message translates to:
  /// **'Try a different search term'**
  String get tryadifferentSearch;

  /// Used on the Mcdecryptor page
  ///
  /// In en, this message translates to:
  /// **'No valid Minecraft installation paths found. Please ensure Minecraft Bedrock Edition (UWP or GDK) is installed and has been launched at least once.'**
  String get minecraftNotInstalled;

  /// Used on the Mcdecryptor page
  ///
  /// In en, this message translates to:
  /// **'Processing Errors'**
  String get processingError;

  /// Used on the Mcdecryptor page
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// Used on the Mcdecryptor page
  ///
  /// In en, this message translates to:
  /// **'Failed Files:'**
  String get failedFiles;

  /// Used to refer to the Minecraft font in the settings tab
  ///
  /// In en, this message translates to:
  /// **'Minecraft Font'**
  String get minecraftFont;

  /// Used on the settings tab to indicate that the Minecraft font is being used
  ///
  /// In en, this message translates to:
  /// **'Using Minecraft-style font'**
  String get usingMinecraftFont;

  /// Used on the settings tab to indicate that the default font is being used
  ///
  /// In en, this message translates to:
  /// **'Using default font'**
  String get usingDefaultFont;

  /// Used on the settings tab to refer to the language of the DLC content
  ///
  /// In en, this message translates to:
  /// **'DLC Language'**
  String get dlcLanguage;

  /// Used on the settings tab to provide information about the DLC language setting
  ///
  /// In en, this message translates to:
  /// **'DLC Language Info'**
  String get dlcLangInfo;

  /// Used on the settings tab to provide information about the DLC language setting
  ///
  /// In en, this message translates to:
  /// **'Note that some DLCs may not have a translation available. This solely depends on the marketplace and not by the app.'**
  String get dlcLangInfoText;

  /// Used on the settings tab to refer to the number of items shown per page in the item list
  ///
  /// In en, this message translates to:
  /// **'Page Size'**
  String get pageSize;

  /// Used on the settings tab to provide information about the page size setting
  ///
  /// In en, this message translates to:
  /// **'Page Size Info'**
  String get pageSizeInfo;

  /// Used on the settings tab to provide information about the page size setting
  ///
  /// In en, this message translates to:
  /// **'Controls how many items load at once.\n\n • Lower values: Better for weak connections (more frequent requests)\n • Higher values: Better for fast connections (fewer requests)\n\nAll results remain accessible regardless of page size. Additional items load automatically when you reach the bottom of the list.'**
  String get pageSizeInfoText;

  /// Used on the settings tab for selecting the DLC language
  ///
  /// In en, this message translates to:
  /// **'Select DLC language'**
  String get selectDlcLanguage;

  /// Used on the settings tab for showing a message when the download path is updated
  ///
  /// In en, this message translates to:
  /// **'Download path updated'**
  String get downloadPathUpdated;

  /// Used on the settings tab for showing a message when the download path is reset to default
  ///
  /// In en, this message translates to:
  /// **'Download path reset to default'**
  String get downloadPathReset;

  /// Used on the settings tab for resetting the download path to default
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get resetDefaults;

  /// Used on the settings tab for choosing a custom download path
  ///
  /// In en, this message translates to:
  /// **'Choose folder'**
  String get chooseFolder;

  /// Used on the settings tab to refer to the path where downloaded packs are saved
  ///
  /// In en, this message translates to:
  /// **'Download Path'**
  String get downloadPath;

  /// Used on the settings tab to refer to the app version
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// Used on the cart page when the user is purchasing a DLC pack
  ///
  /// In en, this message translates to:
  /// **'Purchasing'**
  String get purchasing;

  /// Used on the cart page when the purchase of a DLC pack fails
  ///
  /// In en, this message translates to:
  /// **'Failed to purchase'**
  String get failedPurchase;

  /// Used on the cart page when all items in the cart are successfully purchased
  ///
  /// In en, this message translates to:
  /// **'All items purchased successfully!'**
  String get allItemsSuccessfullyPurchased;

  /// Used on the cart page when the user doesn't have enough funds to purchase the items in the cart
  ///
  /// In en, this message translates to:
  /// **'Insufficient funds for {insufficientFundsItems} item(s)'**
  String insufficientFunds(int insufficientFundsItems);

  /// Used on the cart page when some items in the cart fail to be purchased but not all
  ///
  /// In en, this message translates to:
  /// **'Some purchases failed'**
  String get somePurchasesFailed;

  /// Used on the cart page when some items in the cart are not purchasable
  ///
  /// In en, this message translates to:
  /// **'{numItems} item(s) are not purchasable'**
  String numItemsAreNotPurchasable(int numItems);

  /// Used on the cart page when the purchase process is complete
  ///
  /// In en, this message translates to:
  /// **'Purchase completed'**
  String get purchaseComplete;

  /// Used on the cart page
  ///
  /// In en, this message translates to:
  /// **'Confirm Purchase'**
  String get confirmPurchase;

  /// Used on the cart page when confirming a purchase
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to purchase {itemsText}?'**
  String confirmPurchaseMessage(String itemsText);

  /// Used on the cart page to indicate the total price of the items being purchased
  ///
  /// In en, this message translates to:
  /// **'Total Price:'**
  String get totalPrice;

  /// Used on the cart page to indicate the results of the purchase process
  ///
  /// In en, this message translates to:
  /// **'Purchase Results'**
  String get purchaseResults;

  /// Used on the cart page to indicate the number of items successfully purchased
  ///
  /// In en, this message translates to:
  /// **'Successfully purchased: {successItems} item(s)'**
  String successfullyPurchased(int successItems);

  /// Used on the cart page to indicate the number of items that were already owned
  ///
  /// In en, this message translates to:
  /// **'Already owned: {alreadyOwnedItems} item(s)'**
  String alreadyOwnded(int alreadyOwnedItems);

  /// Used on the cart page to indicate the number of items that were not purchasable
  ///
  /// In en, this message translates to:
  /// **'Not purchasable: {notPurchasableItems} item(s)'**
  String numItemsNotPurchasable(int notPurchasableItems);

  /// Used on the cart page to indicate the number of items that couldn't be purchased due to insufficient funds
  ///
  /// In en, this message translates to:
  /// **'Insufficient funds: {insufficientFundsItems} item(s)'**
  String numItemsInsufficientFunds(int insufficientFundsItems);

  /// Used on the cart page to indicate the number of items that failed to be purchased
  ///
  /// In en, this message translates to:
  /// **'Failed purchases: {failedItemsCount} item(s)'**
  String numItemsFailed(int failedItemsCount);

  /// Used on the cart page to clear all items from the cart
  ///
  /// In en, this message translates to:
  /// **'Clear Cart'**
  String get clearCart;

  /// Confirmation message when clearing the cart
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove all items from your cart?'**
  String get clearCartConfirmation;

  /// Used as the title of the cart page with the number of items in the cart
  ///
  /// In en, this message translates to:
  /// **'Cart ({count})'**
  String cartTitleNum(int count);

  /// Message shown when the cart is empty
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get cartisEmpty;

  /// Message shown when the cart is empty
  ///
  /// In en, this message translates to:
  /// **'Tap the cart icon on any item\'s details page to add it to your cart and purchase it'**
  String get cartEmptyDescription;

  /// Message shown when a purchase is in progress
  ///
  /// In en, this message translates to:
  /// **'Purchasing...'**
  String get purchasingInProgress;

  /// Used on the cart page to purchase all items in the cart
  ///
  /// In en, this message translates to:
  /// **'Purchase All ({count})'**
  String purchaseAllnum(int count);

  /// Used on the auth page when no new dlc is found
  ///
  /// In en, this message translates to:
  /// **'No New DLCs Found'**
  String get nowNewdlcFound;

  /// Used on the auth page when no new dlc is found
  ///
  /// In en, this message translates to:
  /// **'All DLCs are already present on the app database'**
  String get nowNewDlcFoundDescription;

  /// Used on the auth page when no dlc is found
  ///
  /// In en, this message translates to:
  /// **'No DLCs Found'**
  String get noDlcFound;

  /// Used on the auth page dlc list
  ///
  /// In en, this message translates to:
  /// **'No DLC content available'**
  String get noDlcAvailable;

  /// Used on the auth page to open the list of dlcs
  ///
  /// In en, this message translates to:
  /// **'Open DLCs'**
  String get openDlcsList;

  /// Used on the changelog page
  ///
  /// In en, this message translates to:
  /// **'App Updates'**
  String get appUpdates;

  /// Used on the changelog page
  ///
  /// In en, this message translates to:
  /// **'See what\'s new in recent versions of the app'**
  String get appUpdatesDescription;

  /// Used on the settings page
  ///
  /// In en, this message translates to:
  /// **'Socials'**
  String get socials;

  /// Title for the app picker dialog
  ///
  /// In en, this message translates to:
  /// **'Select App'**
  String get selectApp;

  /// Message shown when no apps are found
  ///
  /// In en, this message translates to:
  /// **'No apps found'**
  String get noAppsFound;

  /// Message shown when there is an error loading DLCs
  ///
  /// In en, this message translates to:
  /// **'Error loading DLCs'**
  String get errorLoadingDlcs;

  /// Title for the DLCs list page
  ///
  /// In en, this message translates to:
  /// **'DLCs'**
  String get dlcs;

  /// Error message when saving keys fails
  ///
  /// In en, this message translates to:
  /// **'Error saving keys: {error}'**
  String errorSavingKeys(String error);

  /// Error message when opening authentication page fails
  ///
  /// In en, this message translates to:
  /// **'Error opening authentication page: {error}'**
  String errorOpeningAuthPage(String error);

  /// Status message during authentication
  ///
  /// In en, this message translates to:
  /// **'Getting entity token...'**
  String get gettingEntityToken;

  /// Status message while loading Minecoin balance
  ///
  /// In en, this message translates to:
  /// **'Loading Minecoin balance...'**
  String get loadingMinecoinBalance;

  /// Message instructing the user to authenticate first
  ///
  /// In en, this message translates to:
  /// **'Please complete authentication first'**
  String get completeAuthFirst;

  /// Error message when session expires
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please try again.'**
  String get sessionExpired;

  /// Error message when access is denied
  ///
  /// In en, this message translates to:
  /// **'Access denied. Please re-authenticate.'**
  String get accessDenied;

  /// Error message for connection timeout
  ///
  /// In en, this message translates to:
  /// **'Connection timeout. Please check your internet and try again.'**
  String get connectionTimeout;

  /// Error message for server errors
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again in a few moments.'**
  String get serverError;

  /// Tooltip text to go back to settings
  ///
  /// In en, this message translates to:
  /// **'Back to Settings'**
  String get backToSettings;

  /// Error message when cart initialization fails
  ///
  /// In en, this message translates to:
  /// **'Error initializing cart: {error}'**
  String errorInitializingCart(String error);

  /// Error message when loading cart items fails
  ///
  /// In en, this message translates to:
  /// **'Error loading cart items: {error}'**
  String errorLoadingCartItems(String error);

  /// Error message when loading more items fails
  ///
  /// In en, this message translates to:
  /// **'Failed to load more items: {error}'**
  String failedLoadMoreItems(String error);

  /// Error message when saving logs fails
  ///
  /// In en, this message translates to:
  /// **'Error saving log: {error}'**
  String errorSavingLog(String error);

  /// Error message when deleting a file fails
  ///
  /// In en, this message translates to:
  /// **'Failed to delete file'**
  String get failedToDeleteFile;

  /// Error message when sharing a file fails
  ///
  /// In en, this message translates to:
  /// **'Failed to share file: {error}'**
  String failedToShareFile(String error);

  /// Warning message displayed for Persona items
  ///
  /// In en, this message translates to:
  /// **'Persona items cannot be imported in-game (such as emotes, cosmetics, and capes)'**
  String get personaWarning;

  /// Status message shown during McDecryptor initialization
  ///
  /// In en, this message translates to:
  /// **'Initializing McDec...'**
  String get initializingMcDec;

  /// Error message when saving keys fails in McDecryptor
  ///
  /// In en, this message translates to:
  /// **'Failed to save keys: {error}'**
  String failedToSaveKeys(String error);

  /// Title of the item details sheet
  ///
  /// In en, this message translates to:
  /// **'Item Details'**
  String get itemDetailsTitle;

  /// Prefix followed by the author name
  ///
  /// In en, this message translates to:
  /// **'by {creator}'**
  String byCreator(String creator);

  /// Error message when social links fail to load
  ///
  /// In en, this message translates to:
  /// **'Could not load social links, using defaults'**
  String get couldNotLoadSocials;

  /// Display name for SD card or external storage
  ///
  /// In en, this message translates to:
  /// **'SD Card / External Storage'**
  String get sdCardExternalStorage;

  /// Display name for custom location
  ///
  /// In en, this message translates to:
  /// **'Custom Location'**
  String get customLocation;

  /// Error message when opening link fails
  ///
  /// In en, this message translates to:
  /// **'Could not open link: {error}'**
  String couldNotOpenLink(String error);

  /// Setting item for Minecraft package
  ///
  /// In en, this message translates to:
  /// **'Minecraft Package'**
  String get minecraftPackage;

  /// FreeDroidWarn deprecation notice for certified Android devices
  ///
  /// In en, this message translates to:
  /// **'Google has announced that, starting in 2026/2027, all apps on certified Android devices will require the developer to submit personal identity details directly to Google. Since the developers of this app do not agree to this requirement, this app will no longer work on certified Android devices after that time.'**
  String get freeDroidWarnMessage;

  /// Details button on FreeDroidWarn dialog
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get freeDroidWarnDetails;

  /// Solution button on FreeDroidWarn dialog
  ///
  /// In en, this message translates to:
  /// **'Solution'**
  String get freeDroidWarnSolution;

  /// Title of the unsupported 3D preview dialog
  ///
  /// In en, this message translates to:
  /// **'3D Preview Unsupported'**
  String get unsupported3DTitle;

  /// Message shown when 3D preview is unsupported on the device
  ///
  /// In en, this message translates to:
  /// **'3D preview is unsupported on this device and has been disabled.'**
  String get unsupported3DMessage;

  /// Error message when announcements fail to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load announcements'**
  String get failedToLoadAnnouncements;

  /// Empty state for announcements
  ///
  /// In en, this message translates to:
  /// **'No announcements available'**
  String get noAnnouncementsAvailable;

  /// Error message when copying keys fails
  ///
  /// In en, this message translates to:
  /// **'Error copying keys: {error}'**
  String errorCopyingKeys(String error);

  /// Error message when sharing keys fails
  ///
  /// In en, this message translates to:
  /// **'Error sharing keys: {error}'**
  String errorSharingKeys(String error);

  /// Notice for skin and persona availability
  ///
  /// In en, this message translates to:
  /// **'Skin and Persona items are always available'**
  String get skinAndPersonaAlwaysAvailable;

  /// Instruction to change filter in settings
  ///
  /// In en, this message translates to:
  /// **'Change the filter in Settings to \"Show all\" or \"Only available\" to view them.'**
  String get changeFilterInSettingsNotice;

  /// FAQ question about unavailable items
  ///
  /// In en, this message translates to:
  /// **'What does \"UNAVAILABLE\" mean?'**
  String get faqQuestionUnavailable;

  /// Description of UNAVAILABLE badge in FAQ
  ///
  /// In en, this message translates to:
  /// **'UNAVAILABLE: The app currently does not have the key for this DLC.'**
  String get faqUnavailableDescription;

  /// Description of normal item state in FAQ
  ///
  /// In en, this message translates to:
  /// **'No overlay: The key for this DLC is available for download.'**
  String get faqNoOverlayDescription;

  /// Count of total reviews
  ///
  /// In en, this message translates to:
  /// **'({count} reviews)'**
  String reviewsCount(int count);

  /// Button to view pack details
  ///
  /// In en, this message translates to:
  /// **'View Pack'**
  String get viewPack;

  /// Section title for new releases
  ///
  /// In en, this message translates to:
  /// **'New Releases'**
  String get newReleases;

  /// Section title for scary DLC
  ///
  /// In en, this message translates to:
  /// **'Scary DLC'**
  String get scaryDlc;

  /// Section title for sounds DLC
  ///
  /// In en, this message translates to:
  /// **'Sounds'**
  String get sounds;

  /// Section title for texture packs
  ///
  /// In en, this message translates to:
  /// **'Texture Packs'**
  String get texturePacks;

  /// More button or link
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// Error message when discovery content fails to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load discover content'**
  String get failedToLoadDiscoverContent;

  /// Placeholder when image fails to load
  ///
  /// In en, this message translates to:
  /// **'Image not available'**
  String get imageNotAvailable;

  /// Unavailable badge label
  ///
  /// In en, this message translates to:
  /// **'UNAVAILABLE'**
  String get unavailableUppercase;

  /// Title for key server connection failure dialog
  ///
  /// In en, this message translates to:
  /// **'Key Server Connection Failed'**
  String get keyServerConnectionFailed;

  /// Subtitle for key server failure dialog
  ///
  /// In en, this message translates to:
  /// **'Unable to reach the key server to download the latest keys'**
  String get unableToReachKeyServer;

  /// Header in key server failure dialog
  ///
  /// In en, this message translates to:
  /// **'Restricted Region or Network'**
  String get restrictedRegionOrNetwork;

  /// Body in key server failure dialog
  ///
  /// In en, this message translates to:
  /// **'If you are located in a region with internet restrictions or ISP censorship, access to the server may be blocked\\n\\nPlease enable a VPN or proxy and tap Retry to download new keys'**
  String get restrictedRegionOrNetworkDescription;

  /// Offline note in key server failure dialog
  ///
  /// In en, this message translates to:
  /// **'Note: You can still use the app with cached/offline keys, but certain dlcs may not be available until keys are updated'**
  String get keyServerOfflineNote;

  /// Button to continue using cached offline keys
  ///
  /// In en, this message translates to:
  /// **'Continue Offline'**
  String get continueOffline;

  /// Loading label while retrying
  ///
  /// In en, this message translates to:
  /// **'Retrying...'**
  String get retrying;

  /// Tool name for McDecryptor
  ///
  /// In en, this message translates to:
  /// **'McDecryptor'**
  String get mcDecryptor;

  /// Title of notification permission dialog
  ///
  /// In en, this message translates to:
  /// **'Notification Permission'**
  String get notificationPermission;

  /// Content of notification permission dialog
  ///
  /// In en, this message translates to:
  /// **'Notification permission should be granted if you want background download to properly work'**
  String get notificationPermissionDescription;

  /// Button to open application settings
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// Loading message for 3D persona preview
  ///
  /// In en, this message translates to:
  /// **'Loading 3D persona...'**
  String get loading3DPersona;

  /// Tooltip to open full 3D viewer screen
  ///
  /// In en, this message translates to:
  /// **'Open Full 3D Viewer'**
  String get openFull3DViewer;

  /// Manage button label
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// Subtitle prompting Microsoft account sign in
  ///
  /// In en, this message translates to:
  /// **'Sign in with Microsoft to access your bought DLCs'**
  String get signInWithMicrosoftDescription;

  /// Settings tile title for downloads and storage
  ///
  /// In en, this message translates to:
  /// **'Downloads & Storage'**
  String get downloadsAndStorage;

  /// Settings tile subtitle for downloads and storage
  ///
  /// In en, this message translates to:
  /// **'Custom path, zip compression, cache'**
  String get downloadsAndStorageSubtitle;

  /// Settings tile title for keys and tools
  ///
  /// In en, this message translates to:
  /// **'Keys & Tools'**
  String get keysAndTools;

  /// Settings section title for support and community
  ///
  /// In en, this message translates to:
  /// **'Support & Community'**
  String get supportAndCommunity;

  /// Subtitle for FAQ tile
  ///
  /// In en, this message translates to:
  /// **'Frequently asked questions'**
  String get frequentlyAskedQuestions;

  /// Settings section title for about and diagnostics
  ///
  /// In en, this message translates to:
  /// **'About & Diagnostics'**
  String get aboutAndDiagnostics;

  /// Tile title to check for application updates
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// Notice when app is already up to date
  ///
  /// In en, this message translates to:
  /// **'You are using the latest version.'**
  String get youAreUsingTheLatestVersion;

  /// Close button or tooltip
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Button to postpone update prompt for one day
  ///
  /// In en, this message translates to:
  /// **'Ignore 1 day'**
  String get ignore1Day;

  /// Button to open external link in web browser
  ///
  /// In en, this message translates to:
  /// **'Open in Browser'**
  String get openInBrowser;

  /// Button to install downloaded APK
  ///
  /// In en, this message translates to:
  /// **'Install APK'**
  String get installApk;

  /// Button to open downloaded file
  ///
  /// In en, this message translates to:
  /// **'Open File'**
  String get openFile;

  /// Notice indicating file destination
  ///
  /// In en, this message translates to:
  /// **'Saved to: {path}'**
  String savedTo(String path);

  /// Label for zip archive password
  ///
  /// In en, this message translates to:
  /// **'ZIP Password:'**
  String get zipPassword;

  /// Tooltip to copy archive password
  ///
  /// In en, this message translates to:
  /// **'Copy password'**
  String get copyPassword;

  /// Dialog title when skin file format is not supported
  ///
  /// In en, this message translates to:
  /// **'Unsupported Skin Format'**
  String get unsupportedSkinFormat;

  /// Error message when skin format is invalid
  ///
  /// In en, this message translates to:
  /// **'Invalid skin format. Please select a valid Minecraft skin PNG (64x64, 128x128, or 64x32).'**
  String get invalidSkinFormatMessage;

  /// Snackbar message when custom 3D persona skin is updated
  ///
  /// In en, this message translates to:
  /// **'Custom 3D persona skin updated to \"{skinName}\"'**
  String customPersonaSkinUpdated(String skinName);

  /// Confirmation title to reset custom persona skin
  ///
  /// In en, this message translates to:
  /// **'Reset 3D Persona Skin?'**
  String get resetPersonaSkinQuestion;

  /// Confirmation message to reset custom persona skin
  ///
  /// In en, this message translates to:
  /// **'This will restore the default 3D persona mannequin model.'**
  String get resetPersonaSkinDescription;

  /// Reset action button
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// Snackbar message when persona skin is reset
  ///
  /// In en, this message translates to:
  /// **'Reset to default 3D persona mannequin model'**
  String get resetPersonaSkinSuccess;

  /// Section title in appearance settings
  ///
  /// In en, this message translates to:
  /// **'Theme & Font'**
  String get themeAndFont;

  /// Section title for 3D settings
  ///
  /// In en, this message translates to:
  /// **'3D Options'**
  String get options3D;

  /// Title of 3D preview toggle
  ///
  /// In en, this message translates to:
  /// **'3D Preview'**
  String get preview3D;

  /// Subtitle when 3D preview is enabled
  ///
  /// In en, this message translates to:
  /// **'Show 3D preview for skins and emotes'**
  String get show3DPreviewSubtitle;

  /// Subtitle when 3D preview is disabled
  ///
  /// In en, this message translates to:
  /// **'Hide 3D preview for skins and emotes'**
  String get hide3DPreviewSubtitle;

  /// Title of adaptive resolution toggle
  ///
  /// In en, this message translates to:
  /// **'Adaptive Resolution'**
  String get adaptiveResolution;

  /// Subtitle describing adaptive resolution feature
  ///
  /// In en, this message translates to:
  /// **'Dynamically adjust 3D preview resolution (recommended for weaker devices)'**
  String get adaptiveResolutionDescription;

  /// Setting item for custom character skin
  ///
  /// In en, this message translates to:
  /// **'Custom Character Skin'**
  String get customCharacterSkin;

  /// Status text while updating 3D persona skin
  ///
  /// In en, this message translates to:
  /// **'Updating 3D persona...'**
  String get updating3DPersona;

  /// Shows currently active custom skin name
  ///
  /// In en, this message translates to:
  /// **'Active: {skinName}'**
  String activeCustomSkin(String skinName);

  /// Label for default mannequin model
  ///
  /// In en, this message translates to:
  /// **'Default (Mannequin)'**
  String get defaultMannequin;

  /// Tooltip to choose a skin PNG file
  ///
  /// In en, this message translates to:
  /// **'Choose skin PNG'**
  String get chooseSkinPng;

  /// Section title for languages
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get languages;

  /// Dialog title when download path is reset
  ///
  /// In en, this message translates to:
  /// **'Download path reset'**
  String get downloadPathResetTitle;

  /// Dialog content when download path falls back to default
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find {stale}, falling back to {fallback}'**
  String downloadPathResetFallback(String stale, String fallback);

  /// Section title for download location settings
  ///
  /// In en, this message translates to:
  /// **'Download Location'**
  String get downloadLocation;

  /// Section title for file and image format settings
  ///
  /// In en, this message translates to:
  /// **'File & Image Formats'**
  String get fileAndImageFormats;

  /// Subtitle for cache setting
  ///
  /// In en, this message translates to:
  /// **'Temporary files'**
  String get temporaryFiles;

  /// Tile title to check for encryption key updates
  ///
  /// In en, this message translates to:
  /// **'Check for keys update'**
  String get checkForKeysUpdate;

  /// Section title for filter and display settings
  ///
  /// In en, this message translates to:
  /// **'Filters & Display'**
  String get filtersAndDisplay;

  /// Section title for tools settings
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools;

  /// Dark theme mode label
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// Light theme mode label
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// Discovery search category
  ///
  /// In en, this message translates to:
  /// **'Discovery'**
  String get discovery;

  /// Relevance sort order option
  ///
  /// In en, this message translates to:
  /// **'Relevance'**
  String get relevance;

  /// Emotes category filter
  ///
  /// In en, this message translates to:
  /// **'Emotes'**
  String get emotes;

  /// Error message when 3D preview fails to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load 3D preview: {error}'**
  String failedToLoad3dPreview(String error);

  /// Tooltip to stop walking animation and return to idle pose
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get idle;

  /// Tooltip to start walking animation
  ///
  /// In en, this message translates to:
  /// **'Walk'**
  String get walk;

  /// Tooltip to pause model turntable auto-rotation
  ///
  /// In en, this message translates to:
  /// **'Pause Turntable'**
  String get pauseTurntable;

  /// Tooltip to start model turntable auto-rotation
  ///
  /// In en, this message translates to:
  /// **'Auto Rotate'**
  String get autoRotate;

  /// Tooltip to switch back equipment from cape to elytra
  ///
  /// In en, this message translates to:
  /// **'Switch to Elytra'**
  String get switchToElytra;

  /// Tooltip to switch back equipment from elytra to cape
  ///
  /// In en, this message translates to:
  /// **'Switch to Cape'**
  String get switchToCape;

  /// Header title for included skins
  ///
  /// In en, this message translates to:
  /// **'Included Skins'**
  String get includedSkins;

  /// Hint text to expand 3D skin preview with counter
  ///
  /// In en, this message translates to:
  /// **'Tap to expand 3D skin preview ({current}/{total})'**
  String tapToExpand3dSkinPreview(int current, int total);

  /// Hint text to preview 3D skins
  ///
  /// In en, this message translates to:
  /// **'Tap to preview 3D skins'**
  String get tapToPreview3dSkins;

  /// Hint text to preview included 3D skins
  ///
  /// In en, this message translates to:
  /// **'Tap to preview included 3D skins'**
  String get tapToPreviewIncluded3dSkins;

  /// Tooltip to open full 3D skin viewer
  ///
  /// In en, this message translates to:
  /// **'Open 3D Viewer'**
  String get open3dViewer;

  /// Tooltip to download skin pack
  ///
  /// In en, this message translates to:
  /// **'Download skin pack'**
  String get downloadSkinPack;

  /// Tooltip to view previous skin in preview
  ///
  /// In en, this message translates to:
  /// **'Previous skin'**
  String get previousSkin;

  /// Tooltip to view next skin in preview
  ///
  /// In en, this message translates to:
  /// **'Next skin'**
  String get nextSkin;

  /// Hint text explaining how to rotate the 3D model
  ///
  /// In en, this message translates to:
  /// **'Drag to rotate'**
  String get dragToRotate;

  /// Progress text when downloading and preparing 3D skins
  ///
  /// In en, this message translates to:
  /// **'Downloading & Preparing Skins: {percent}%'**
  String downloadingAndPreparingSkins(int percent);

  /// Loading text while 3D skins are preparing
  ///
  /// In en, this message translates to:
  /// **'Preparing 3D Skins...'**
  String get preparing3dSkins;

  /// Error message when loading skins fails
  ///
  /// In en, this message translates to:
  /// **'Failed to load skins: {error}'**
  String failedToLoadSkins(String error);

  /// Title of the 3D Viewer screen
  ///
  /// In en, this message translates to:
  /// **'3D Viewer'**
  String get viewer3d;

  /// Tooltip for high quality native DPR rendering mode
  ///
  /// In en, this message translates to:
  /// **'High Quality (Native DPR)'**
  String get highQualityNativeDpr;

  /// Tooltip for balanced rendering mode
  ///
  /// In en, this message translates to:
  /// **'Balanced Mode (Optimized)'**
  String get balancedModeOptimized;

  /// Snackbar message when high quality mode is enabled
  ///
  /// In en, this message translates to:
  /// **'High Quality enabled (Native {dpr}x DPR)'**
  String highQualityEnabledNative(String dpr);

  /// Snackbar message when balanced mode is enabled
  ///
  /// In en, this message translates to:
  /// **'Balanced mode enabled ({dpr}x DPR)'**
  String balancedModeEnabled(String dpr);

  /// Tooltip to reset 3D camera view
  ///
  /// In en, this message translates to:
  /// **'Reset View'**
  String get resetView;

  /// Loading text while 3D model is compiling
  ///
  /// In en, this message translates to:
  /// **'Building 3D model...'**
  String get building3dModel;

  /// Pose chip label for standing pose
  ///
  /// In en, this message translates to:
  /// **'Stand'**
  String get stand;

  /// Equipment segment label for cape
  ///
  /// In en, this message translates to:
  /// **'Cape'**
  String get cape;

  /// Equipment segment label for elytra
  ///
  /// In en, this message translates to:
  /// **'Elytra'**
  String get elytra;

  /// FilterChip label for turntable auto-rotation
  ///
  /// In en, this message translates to:
  /// **'Turntable'**
  String get turntable;

  /// Default label for a skin
  ///
  /// In en, this message translates to:
  /// **'Skin'**
  String get skin;

  /// Message shown when decryption keys are already up to date
  ///
  /// In en, this message translates to:
  /// **'Keys are up to date'**
  String get keysAreUpToDate;

  /// Bottom navigation bar label for news/announcements tab
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get news;

  /// Error message when retry to reach key server fails
  ///
  /// In en, this message translates to:
  /// **'Still unable to reach the server. Please check your VPN connection and try again'**
  String get stillUnableToReachServer;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'bn',
    'cs',
    'en',
    'es',
    'fa',
    'fi',
    'fil',
    'fr',
    'hi',
    'id',
    'it',
    'lt',
    'ms',
    'pt',
    'ru',
    'th',
    'uk',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'bn':
      return AppLocalizationsBn();
    case 'cs':
      return AppLocalizationsCs();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fa':
      return AppLocalizationsFa();
    case 'fi':
      return AppLocalizationsFi();
    case 'fil':
      return AppLocalizationsFil();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'id':
      return AppLocalizationsId();
    case 'it':
      return AppLocalizationsIt();
    case 'lt':
      return AppLocalizationsLt();
    case 'ms':
      return AppLocalizationsMs();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'th':
      return AppLocalizationsTh();
    case 'uk':
      return AppLocalizationsUk();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
