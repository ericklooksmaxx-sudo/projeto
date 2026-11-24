// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get home => 'হোম';

  @override
  String get downloads => 'ডাউনলোড সমূহ';

  @override
  String get settings => 'সেটিংস';

  @override
  String get selectLanguage => 'ভাষা নির্বাচন করুন';

  @override
  String get language => 'ভাষা';

  @override
  String get download => 'ডাউনলোড';

  @override
  String get hintText => 'খুঁজুন...';

  @override
  String get default1 => 'ডিফল্ট';

  @override
  String get creators => 'ক্রিয়েটর সমূহ';

  @override
  String get checkingKeys => 'Key চেক করা হচ্ছে';

  @override
  String get apiLogin => 'API লগিন';

  @override
  String addedNewKeys(int keyCount) {
    return '$keyCount টা key অ্যাড করা হয়েছে';
  }

  @override
  String get noResult => 'কোনো কিছু পাওয়া যায়নি';

  @override
  String get open => 'ওপেন';

  @override
  String get clear => 'ক্লিয়ার';

  @override
  String get retry => 'আবার চেষ্টা করুন';

  @override
  String get ok => 'OK';

  @override
  String queuePosition(int count) {
    return 'অপেক্ষামান (অবস্থান #$count)';
  }

  @override
  String queuePosition2(int count) {
    return 'অপেক্ষামান #$count)';
  }

  @override
  String imageSaved(String filePath) {
    return 'ইমেজ সেভ করা হয়েছে $filePath';
  }

  @override
  String errorDownloadingImage(String error) {
    return 'ইমেজ ডাউনলোডে সমস্যা হয়েছে: $error';
  }

  @override
  String get changelog => 'চেঞ্জ লগ';

  @override
  String get downloaded => 'ডাউনলোড হয়েছে';

  @override
  String get retryDownload => 'আবার ডাউনলোড করুন';

  @override
  String get downloadImage => 'ইমেজ ডাউনলোড করুন';

  @override
  String get downloadImageQuestion => 'এই ইমেজ ডাউনলোড করবেন?';

  @override
  String get cancel => 'বাতিল';

  @override
  String get trailer => 'ট্রেইলার দেখুন';

  @override
  String trailerError(String error) {
    return 'ট্রেইলার ওপেন করতে সমস্যা হয়েছে: $error';
  }

  @override
  String get appearance => 'Appearance';

  @override
  String get darkMode => 'ডার্ক মোড';

  @override
  String get darkEnabled => 'ডার্ক মোড চালু আছে';

  @override
  String get lightEnabled => 'লাইট থিম চালু আছে';

  @override
  String get colorScheme => 'কালার স্কিম';

  @override
  String get defaultColor => 'ডিফল্ট';

  @override
  String get defaultPurple => 'ডিফল্ট (বেগুনি)';

  @override
  String get colorSchemeBlue => 'নীল';

  @override
  String get colorSchemeGreen => 'সবুজ';

  @override
  String get colorSchemeOrange => 'কমলা';

  @override
  String get colorSchemeRed => 'লাল';

  @override
  String get colorSchemeTeal => 'সমুদ্র নীল';

  @override
  String get colorSchemePink => 'গোলাপি';

  @override
  String get colorSchemeLime => 'লেবু লেমুন';

  @override
  String get filters => 'ফিল্টার সমূহ';

  @override
  String get filter => 'ফিল্টার';

  @override
  String get showSkins => 'স্কিনসমূহ দেখান';

  @override
  String get keys => 'Key সমূহ';

  @override
  String get autoUpdate => 'অটো-আপডেট';

  @override
  String get customDb => 'কাস্টম DB';

  @override
  String get accountLogin => 'অ্যাকাউন্ট লগিন';

  @override
  String get extras => 'অতিরিক্তসমূহ';

  @override
  String get cache => 'ক্যাশে';

  @override
  String cacheCleared(String size) {
    return '$size MB ক্যাশে মুছে ফেলা হয়েছে';
  }

  @override
  String get faq => 'Faq';

  @override
  String get faqUppercase => 'FAQ';

  @override
  String get terminal => 'টার্মিনাল';

  @override
  String get faqQuestion1 => 'অনুগ্রহ করে এই প্যাক এর Key যোগ করুন!';

  @override
  String get faqQuestion2 => 'Key সমূহ কখন আপডেট করা হবে?';

  @override
  String get faqQuestion3 => 'এনক্রিপ্টেড আর ডিক্রিপ্টেডের মাঝে পার্থক্য কী?';

  @override
  String get faqQuestion4 => 'ডাউনলোড করা প্যাকগুলো কোথায় পাবো?';

  @override
  String get faqQuestion5 => 'keys.tsv কী?';

  @override
  String get faqQuestion6 => 'How can i use Persona items?';

  @override
  String get faqQuestion7 => 'Why do some skin packs appear broken?';

  @override
  String get faqQuestion8 =>
      'What\'s the purpose of the \"Account Login\" page?';

  @override
  String get faqQuestion9 => 'What does the checkmark mean?';

  @override
  String get faqAnswer1 =>
      'Key পাওয়ার প্রক্রিয়া কোনো যাদু না: কোনো একজনকে প্রথমে প্যাকটা কিনতে হবে এরপর আমাদের কাছে key গুলা শেয়ার করতে হবে। কেউ না কিনলে ডিক্রিপশন key পাওয়া যাবে না। আর তা ছাড়া পাওয়ার কোনো উপায় নেই। অপেক্ষা করুন বা নিজে কিনে ফেলুন।';

  @override
  String get faqAnswer2 => 'যখন আমাদের মর্জি হবে।';

  @override
  String get faqAnswer3 =>
      'এনক্রিপ্টেড মানে একটা ফাইলকে হযবরলে পরিণত করা। কেউ সেটা পড়তে পারবে না এক বিশেষ key ছাড়া। এনক্রিপ্টেড মাইনক্রাফট কন্টেন্ট খেলার মতো না। ডিক্রিপ্টেড মানে হচ্ছে বিশেষ key টা ব্যবহার করে হযবরল কে আসল রূপে নিয়ে আসা। এরপর মাইনক্রাফট কন্টেন্ট ব্যবহার করা যাবে।';

  @override
  String get faqAnswer4 => 'আপনি প্যাকসমূহ এখানে ডাউনলোড বা Kyzen এ পাবেন।';

  @override
  String get faqAnswer5 =>
      'ওটা একটা ফাইল যা প্যাকসমূহের এর UUID আর তার ডিক্রিপশন key সংরক্ষণ করে। ডিক্রিপশন key ছাড়া ডাউনলোড করা প্যাক খেলার যোগ্য অবস্থায় থাকবে না।';

  @override
  String get faqAnswer6 =>
      'U can\'t. They do exist some methods but given the complexity to be done, it is not feasible.';

  @override
  String get faqAnswer7 =>
      'Some skin packs (especially franchise collabs) use custom geometry which Minecraft doesn\'t allow to be used normally unless u buy the skin pack. U can check if a skin pack uses custom geometry by checking if the file \"geometry.json\" exists in the pack. Keep in mind that this issue is not related to the tool in any way.';

  @override
  String get faqAnswer8 =>
      'The account login page allows you to authenticate with your Microsoft account to directly load your Minecraft keys from your inventory.\nThis is useful when Kyzen doesn’t currently have a key available for a specific DLC but you do have it in your account, once your keys are loaded that DLC will appear available for download. \nNote that the keys are automatically uploaded to our database, where they will later be merged with Kyzen’s main key database so everyone can enjoy the new dlc, so please use this feature if u wanna contribute.';

  @override
  String get faqAnswer9Checkmark => 'The key for this DLC is available.';

  @override
  String get faqAnswer9NoCheckmark =>
      'The app currently does not have the key for this DLC.';

  @override
  String get faqAnswer9ExtraInfo => 'Keys are required to unlock the DLCs.';

  @override
  String get faqQuestionDownload => 'Why is the download button unavailable?';

  @override
  String get faqAnswerDownload =>
      'The key to unlock this dlc is not available, wait patiently or buy it.';

  @override
  String get faqQuestionKey => 'How do i get the key?';

  @override
  String get faqAnswerKey =>
      'Buy the dlc on your account then go to settings > Account login > Click \'Start authentication\' > click \'Load keys\', now click \'Share\' and share the keys files to the Bluecoin chat, the keys are going to be added to the app database. if u can\'t share the keys file to the group, don\'t worry, the keys get automatically uploaded to a database.';

  @override
  String get faqMoreHelp => 'More help';

  @override
  String get faqNotAdlc => 'Not a DLC';

  @override
  String get faqNotAdlcDescription => 'This item is not a DLC.';

  @override
  String get faqServerContent => 'Server content';

  @override
  String get faqServerContentDescription =>
      'This item is exclusive to a specific server and cannot be downloaded directly.';

  @override
  String get fileDeleted => 'ফাইল ডিলিট করা হয়েছে';

  @override
  String get storedFiles => 'সংরক্ষিত ফাইলসমূহ';

  @override
  String get refreshFiles => 'ফাইলসমূহ রিফ্রেশ করুন';

  @override
  String get deleteFile => 'ফাইল ডিলিট করুন';

  @override
  String deleteFileConfirmation(String fileName) {
    return 'আপনি কি নিশ্চিত যে, আপনি $fileName ডিলিট করতে চান?';
  }

  @override
  String get cancelUppercase => 'বাতিল';

  @override
  String get deleteUppercase => 'ডিলিট';

  @override
  String get currentDownload => 'বর্তমান ডাউনলোড';

  @override
  String get noActiveDownloads => 'কোনো সচল ডাউনলোড নেই';

  @override
  String get completedDownloads => 'শেষ হওয়া ডাউনলোড সমূহ';

  @override
  String get clearAll => 'সব মুছে ফেলুন';

  @override
  String get importToMc => 'মাইনক্রাফটে ইম্পোর্ট করুন';

  @override
  String get openFileinExplorer => 'Open in file explorer';

  @override
  String get shareFile => 'ফাইল শেয়ার করুন';

  @override
  String get debugTerminal => 'ডিবাগ টার্মিনাল';

  @override
  String get clearLogs => 'Logs মুছে ফেলুন';

  @override
  String get noLogs => 'কোনো logs নেই...';

  @override
  String get saveLogs => 'Save logs';

  @override
  String logsSaved(String filePath) {
    return 'Logs saved to $filePath';
  }

  @override
  String get selectingFile => 'ফাইল নির্বাচন করা হচ্ছে...';

  @override
  String get processingFile => 'ফাইল প্রসেস করা হচ্ছে...';

  @override
  String get fileProcessed => 'ফাইল প্রসেস সফল!';

  @override
  String get noFileSelected => 'কোনো ফাইল সিলেক্ট করা হয়নি।';

  @override
  String customKeysLoaded(int count) {
    return '$count টা কাস্টম key অ্যাড করা হয়েছে';
  }

  @override
  String get noCustomKeysLoaded => 'কোনো কাস্টম key লোড করা হয়নি';

  @override
  String get importFileFormat => 'একটা ফাইল ইম্পোর্ট করুন UUID=KEY ফরম্যাট সহ';

  @override
  String creatorItemsWithType(String contentType) {
    return '$contentType আইটেমসমূহ';
  }

  @override
  String creatorItemsWithTypeAndCount(String contentType, int count) {
    return '$contentType আইটেমসমূহ ($count)';
  }

  @override
  String get creatorItemsDefault => 'ক্রিয়েটর আইটেমসমূহ';

  @override
  String get noItemCreator => 'এই ক্রিয়েটরের কোনো কন্টেন্ট নেই';

  @override
  String get noStatistic => 'কোনো statistics নেই';

  @override
  String get failedLoadStatistic => 'Statistics লোড করা যাচ্ছে না';

  @override
  String get noResultsFound => 'কোনো কিছু পাওয়া যায়নি';

  @override
  String get microsoftAuth => 'মাইক্রোসফট অথেন্টিকেশন';

  @override
  String get exchangingToken =>
      'অথোরাইজেশন কোড বদল দেওয়া হচ্ছে টোকেন এর জন্য...';

  @override
  String authenticationFailed(String error) {
    return 'অথেন্টিকেশন এ সমস্যা হয়েছে: $error';
  }

  @override
  String get authenticationSuccessful => 'অথেন্টিকেশন সফল!';

  @override
  String failedToExchangeToken(String error) {
    return 'কোড বদল দিয়ে টোকেন নিতে সমস্যা হয়েছে: $error';
  }

  @override
  String get noAuthorizationCodeReceived => 'কোনো অথোরাইজেশন কোড পাওয়া যায়নি';

  @override
  String get noNewKeysCopy => 'কোনো নতুন key পাওয়া যায়নি কপি করার জন্য';

  @override
  String get keysCopyClipboard => 'Key সমূহ ক্লিপবোর্ডে কপি করা হয়েছে!';

  @override
  String get noNewKeysShare => 'নতুন কোনো key পাওয়া যায়নি শেয়ার করার জন্য';

  @override
  String get keysShared => 'Key শেয়ার সফল!';

  @override
  String get authCheck => 'বর্তমান অথেন্টিকেশন চেক করা হচ্ছে...';

  @override
  String get alreadyAuth => 'ইতোমধ্যে অথেন্টিকেশন করা আছে!';

  @override
  String get readyAuth => 'অথেন্টিকেশনের জন্য প্রস্তুত';

  @override
  String get authURL => 'URL দিয়ে অথেন্টিকেট করুন';

  @override
  String get completeAuthButton => 'Complete Authentication';

  @override
  String get openAuthPageButton => 'Open Auth Page';

  @override
  String get completeAuth =>
      'ব্রাউজারে অথেন্টিকেশন সম্পন্ন করুন। এরপর অ্যাপে ফিরিয়ে আনা হবে।';

  @override
  String get copyUrl => 'Copy URL';

  @override
  String get authPageFail => 'অথেন্টিকেশন পেজ ওপেন করা যাচ্ছে না';

  @override
  String get logout => 'লগ আউট করা হচ্ছে...';

  @override
  String get logoutOk => 'লগ আউট সফল';

  @override
  String get usingCachedSession => 'ক্যাশে সেশন ব্যবহৃত হচ্ছে...';

  @override
  String get loadingMinecraftKeys => 'মাইনক্রাফটের key সমূহ লোড করা হচ্ছে...';

  @override
  String get requestingXboxLiveToken =>
      'Xbox লাইভ টোকেন রিকুয়েস্ট করা হচ্ছে...';

  @override
  String get loggingInToPlayFab => 'PlayFab এ লগিন করা হচ্ছে...';

  @override
  String get gettingUserInformation => 'ইউজার ইনফরমেশন সংগ্রহ করা হচ্ছে...';

  @override
  String get startingMinecraftSession => 'মাইনক্রাফট সেশন শুরু করা হচ্ছে...';

  @override
  String get loadingMinecraftInventory =>
      'মাইনক্রাফট ইনভেন্টরি লোড করা হচ্ছে...';

  @override
  String successfullyLoadedKeys(int keyCount) {
    return '$keyCount টা key সফলভাবে লোড করা হয়েছে!';
  }

  @override
  String errorLoadingKeys(String error) {
    return 'Key লোড করতে সমস্যা হয়েছে: $error';
  }

  @override
  String get copyClipboard => 'ক্লিপবোর্ডে কপি করা হয়েছে';

  @override
  String get authOk => 'অথেন্টিকেট হয়েছে';

  @override
  String get authNotOk => 'অথেন্টিকেট করা হয়নি';

  @override
  String get urlAuth => 'অথেন্টিকেশন URL';

  @override
  String get loadedKeys => 'লোড করা key সমূহ';

  @override
  String get exportNewKeys => 'শুধু নতুন key এক্সপোর্ট করুন';

  @override
  String get loadKeysButton => 'Key লোড করুন';

  @override
  String get logoutButton => 'লগ আউট';

  @override
  String get startAuthButton => 'অথেন্টিকেশন শুরু করুন';

  @override
  String get greetings => 'Hi';

  @override
  String get copy => 'Copy';

  @override
  String get save => 'Save';

  @override
  String get share => 'Share';

  @override
  String get keysSaved => 'Keys saved successfully';

  @override
  String get startingDownload => 'ডাউনলোড শুরু করা হচ্ছে...';

  @override
  String get downloadsCompleted => 'ডাউনলোডসমূহ সম্পন্ন';

  @override
  String get completed => 'সম্পন্ন!';

  @override
  String get downloadFailed => 'ডাউনলোডে সমস্যা হয়েছে';

  @override
  String get downloading => 'ডাউনলোড করা হচ্ছে';

  @override
  String get processing => 'প্রোসেস করা হচ্ছে';

  @override
  String get extractingZipFile => 'ZIP ফাইল এক্সট্রাক্ট করা হচ্ছে...';

  @override
  String get decryptingContents => 'কন্টেন্টসমূহ ডিক্রিপ্ট করা হচ্ছে...';

  @override
  String get compressingPack => 'প্যাক কম্প্রেস করা হচ্ছে...';

  @override
  String get cleaningUp => 'পরিষ্কার করা হচ্ছে...';

  @override
  String get showAll => 'সব দেখান';

  @override
  String get onlyAvailable => 'শুধু লভ্যগুলো';

  @override
  String get onlyNotAvailable => 'শুধু অলভ্যগুলো';

  @override
  String get customColor => 'Custom Color';

  @override
  String get changeCustomColor => 'Tap to change your custom color';

  @override
  String get createCustomColor => 'Create your own color scheme';

  @override
  String get pickColor => 'Pick Color';

  @override
  String get selectColor => 'Select';

  @override
  String get images => 'Images';

  @override
  String get saveToPng => 'Save to PNG';

  @override
  String get saveToGallery => 'Save to Gallery';

  @override
  String get compression => 'Compression';

  @override
  String get normalCompression => 'Normal Compression';

  @override
  String get noCompression => 'No Compression';

  @override
  String get copyUUID => 'Copy UUID';

  @override
  String get openInMinecraft => 'Open in Minecraft';

  @override
  String get creator => 'Creator';

  @override
  String get addToCart => 'Add to Cart';

  @override
  String get removeFromCart => 'Remove from Cart';

  @override
  String get addedToCart => 'Added to cart';

  @override
  String get removedFromCart => 'Removed from cart';

  @override
  String get authRequired => 'Authentication required';

  @override
  String get authRequiredDesc =>
      'You need to be fully authenticated to view your cart. Please authenticate from the Account login page.';

  @override
  String get newUpdate => 'New update';

  @override
  String get newDlc => 'New dlc';

  @override
  String get hidden => 'Hidden';

  @override
  String get persona => 'Persona';

  @override
  String get skins => 'Skins';

  @override
  String get mashups => 'Mashups';

  @override
  String get worlds => 'Worlds';

  @override
  String get textures => 'Textures';

  @override
  String get addons => 'Add-Ons';

  @override
  String get capes => 'Capes';

  @override
  String get vibrantVisuals => 'Vibrant visuals';

  @override
  String get favorites => 'Favorites';

  @override
  String get unfiltered => 'Unfiltered';

  @override
  String get sorting => 'Sorting';

  @override
  String get type => 'Type';

  @override
  String get newFilter => 'New';

  @override
  String get other => 'Other';

  @override
  String get newest => 'Newest';

  @override
  String get oldest => 'Oldest';

  @override
  String get mostRated => 'Most Rated';

  @override
  String get leastRated => 'Least Rated';

  @override
  String get menu => 'Menu';

  @override
  String imageSavedToGallery(String filePath) {
    return 'Image saved to gallery: $filePath';
  }

  @override
  String get vibrantVisualEnhanced => 'Vibrant Visuals Enhanced';

  @override
  String get uuidCopied => 'UUID copied to clipboard';

  @override
  String get scrollRight => 'Scroll right';

  @override
  String get scrollLeft => 'Scroll left';

  @override
  String get previousImage => 'Previous image';

  @override
  String get nextImage => 'Next image';

  @override
  String get favoriteEmpty => 'Your favorites list is empty';

  @override
  String get favoriteDescription =>
      'Tap the heart icon on any item\'s details page to add it to your favorites and build your collection';

  @override
  String get removeFromFavorites => 'Remove from favorites';

  @override
  String get addToFavorites => 'Add to favorites';

  @override
  String get addedToFavorites => 'Added to favorites';

  @override
  String get removedFromFavorites => 'Removed from favorites';

  @override
  String get noNewKeysFoundToSave => 'No keys found to save';

  @override
  String get keysSavedSuccessfully =>
      'Keys saved successfully into the Kyzen folder.';

  @override
  String get entitlementKeys => 'Entitlement Keys';

  @override
  String get searchBoughContent => 'Search your Minecraft bought content.';

  @override
  String get saveKeys => 'Save Keys';

  @override
  String get refresh => 'Refresh';

  @override
  String get searchKeys => 'Search Keys';

  @override
  String get loadSkinPersona => 'Load SkinPack/Persona';

  @override
  String get descriptionSkinPersona =>
      'Include skinpack and persona on the list';

  @override
  String get loadOnlyNewKeys => 'Load only new keys';

  @override
  String get descriptionLoadOnlyNewKeys =>
      'Load only content not present on the app keys database';

  @override
  String get descriptionExportNewKeys =>
      'Whether \"save keys\" should only export new keys';

  @override
  String processedEntitlementKeys(int countFiles, int countKeys) {
    return 'Successfully Processed ($countFiles files, $countKeys keys)';
  }

  @override
  String get noResultsYet => 'No results yet';

  @override
  String get clickSearchKeysToLoadContent =>
      'Click \"Search Keys\" to load your content';

  @override
  String get tryadifferentSearch => 'Try a different search term';

  @override
  String get minecraftNotInstalled =>
      'No valid Minecraft installation paths found. Please ensure Minecraft Bedrock Edition (UWP or GDK) is installed and has been launched at least once.';

  @override
  String get processingError => 'Processing Errors';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get failedFiles => 'Failed Files:';

  @override
  String get minecraftFont => 'Minecraft Font';

  @override
  String get usingMinecraftFont => 'Using Minecraft-style font';

  @override
  String get usingDefaultFont => 'Using default font';

  @override
  String get dlcLanguage => 'DLC Language';

  @override
  String get dlcLangInfo => 'DLC Language Info';

  @override
  String get dlcLangInfoText =>
      'Note that some DLCs may not have a translation available. This solely depends on the marketplace and not by the app.';

  @override
  String get pageSize => 'Page Size';

  @override
  String get pageSizeInfo => 'Page Size Info';

  @override
  String get pageSizeInfoText =>
      'Controls how many items load at once.\n\n • Lower values: Better for weak connections (more frequent requests)\n • Higher values: Better for fast connections (fewer requests)\n\nAll results remain accessible regardless of page size. Additional items load automatically when you reach the bottom of the list.';

  @override
  String get selectDlcLanguage => 'Select DLC language';

  @override
  String get downloadPathUpdated => 'Download path updated';

  @override
  String get downloadPathReset => 'Download path reset to default';

  @override
  String get resetDefaults => 'Reset to default';

  @override
  String get chooseFolder => 'Choose folder';

  @override
  String get downloadPath => 'Download Path';

  @override
  String get version => 'Version';

  @override
  String get purchasing => 'Purchasing';

  @override
  String get failedPurchase => 'Failed to purchase';

  @override
  String get allItemsSuccessfullyPurchased =>
      'All items purchased successfully!';

  @override
  String insufficientFunds(int insufficientFundsItems) {
    return 'Insufficient funds for $insufficientFundsItems item(s)';
  }

  @override
  String get somePurchasesFailed => 'Some purchases failed';

  @override
  String numItemsAreNotPurchasable(int numItems) {
    return '$numItems item(s) are not purchasable';
  }

  @override
  String get purchaseComplete => 'Purchase completed';

  @override
  String get confirmPurchase => 'Confirm Purchase';

  @override
  String confirmPurchaseMessage(String itemsText) {
    return 'Are you sure you want to purchase $itemsText?';
  }

  @override
  String get totalPrice => 'Total Price:';

  @override
  String get purchaseResults => 'Purchase Results';

  @override
  String successfullyPurchased(int successItems) {
    return 'Successfully purchased: $successItems item(s)';
  }

  @override
  String alreadyOwnded(int alreadyOwnedItems) {
    return 'Already owned: $alreadyOwnedItems item(s)';
  }

  @override
  String numItemsNotPurchasable(int notPurchasableItems) {
    return 'Not purchasable: $notPurchasableItems item(s)';
  }

  @override
  String numItemsInsufficientFunds(int insufficientFundsItems) {
    return 'Insufficient funds: $insufficientFundsItems item(s)';
  }

  @override
  String numItemsFailed(int failedItemsCount) {
    return 'Failed purchases: $failedItemsCount item(s)';
  }

  @override
  String get clearCart => 'Clear Cart';

  @override
  String get clearCartConfirmation =>
      'Are you sure you want to remove all items from your cart?';

  @override
  String cartTitleNum(int count) {
    return 'Cart ($count)';
  }

  @override
  String get cartisEmpty => 'Your cart is empty';

  @override
  String get cartEmptyDescription =>
      'Tap the cart icon on any item\'s details page to add it to your cart and purchase it';

  @override
  String get purchasingInProgress => 'Purchasing...';

  @override
  String purchaseAllnum(int count) {
    return 'Purchase All ($count)';
  }

  @override
  String get nowNewdlcFound => 'No New DLCs Found';

  @override
  String get nowNewDlcFoundDescription =>
      'All DLCs are already present on the app database';

  @override
  String get noDlcFound => 'No DLCs Found';

  @override
  String get noDlcAvailable => 'No DLC content available';

  @override
  String get openDlcsList => 'Open DLCs';

  @override
  String get appUpdates => 'App Updates';

  @override
  String get appUpdatesDescription =>
      'See what\'s new in recent versions of the app';

  @override
  String get socials => 'Socials';

  @override
  String get selectApp => 'Select App';

  @override
  String get noAppsFound => 'No apps found';

  @override
  String get errorLoadingDlcs => 'Error loading DLCs';

  @override
  String get dlcs => 'DLCs';

  @override
  String errorSavingKeys(String error) {
    return 'Error saving keys: $error';
  }

  @override
  String errorOpeningAuthPage(String error) {
    return 'Error opening authentication page: $error';
  }

  @override
  String get gettingEntityToken => 'Getting entity token...';

  @override
  String get loadingMinecoinBalance => 'Loading Minecoin balance...';

  @override
  String get completeAuthFirst => 'Please complete authentication first';

  @override
  String get sessionExpired => 'Session expired. Please try again.';

  @override
  String get accessDenied => 'Access denied. Please re-authenticate.';

  @override
  String get connectionTimeout =>
      'Connection timeout. Please check your internet and try again.';

  @override
  String get serverError => 'Server error. Please try again in a few moments.';

  @override
  String get backToSettings => 'Back to Settings';

  @override
  String errorInitializingCart(String error) {
    return 'Error initializing cart: $error';
  }

  @override
  String errorLoadingCartItems(String error) {
    return 'Error loading cart items: $error';
  }

  @override
  String failedLoadMoreItems(String error) {
    return 'Failed to load more items: $error';
  }

  @override
  String errorSavingLog(String error) {
    return 'Error saving log: $error';
  }

  @override
  String get failedToDeleteFile => 'Failed to delete file';

  @override
  String failedToShareFile(String error) {
    return 'Failed to share file: $error';
  }

  @override
  String get personaWarning =>
      'Persona items cannot be imported in-game (such as emotes, cosmetics, and capes)';

  @override
  String get initializingMcDec => 'Initializing McDec...';

  @override
  String failedToSaveKeys(String error) {
    return 'Failed to save keys: $error';
  }

  @override
  String get itemDetailsTitle => 'Item Details';

  @override
  String byCreator(String creator) {
    return 'by $creator';
  }

  @override
  String get couldNotLoadSocials =>
      'Could not load social links, using defaults';

  @override
  String get sdCardExternalStorage => 'SD Card / External Storage';

  @override
  String get customLocation => 'Custom Location';

  @override
  String couldNotOpenLink(String error) {
    return 'Could not open link: $error';
  }

  @override
  String get minecraftPackage => 'Minecraft Package';

  @override
  String get freeDroidWarnMessage =>
      'Google has announced that, starting in 2026/2027, all apps on certified Android devices will require the developer to submit personal identity details directly to Google. Since the developers of this app do not agree to this requirement, this app will no longer work on certified Android devices after that time.';

  @override
  String get freeDroidWarnDetails => 'Details';

  @override
  String get freeDroidWarnSolution => 'Solution';

  @override
  String get unsupported3DTitle => '3D Preview Unsupported';

  @override
  String get unsupported3DMessage =>
      '3D preview is unsupported on this device and has been disabled.';

  @override
  String get failedToLoadAnnouncements => 'Failed to load announcements';

  @override
  String get noAnnouncementsAvailable => 'No announcements available';

  @override
  String errorCopyingKeys(String error) {
    return 'Error copying keys: $error';
  }

  @override
  String errorSharingKeys(String error) {
    return 'Error sharing keys: $error';
  }

  @override
  String get skinAndPersonaAlwaysAvailable =>
      'Skin and Persona items are always available';

  @override
  String get changeFilterInSettingsNotice =>
      'Change the filter in Settings to \"Show all\" or \"Only available\" to view them.';

  @override
  String get faqQuestionUnavailable => 'What does \"UNAVAILABLE\" mean?';

  @override
  String get faqUnavailableDescription =>
      'UNAVAILABLE: The app currently does not have the key for this DLC.';

  @override
  String get faqNoOverlayDescription =>
      'No overlay: The key for this DLC is available for download.';

  @override
  String reviewsCount(int count) {
    return '($count reviews)';
  }

  @override
  String get viewPack => 'View Pack';

  @override
  String get newReleases => 'New Releases';

  @override
  String get scaryDlc => 'Scary DLC';

  @override
  String get sounds => 'Sounds';

  @override
  String get texturePacks => 'Texture Packs';

  @override
  String get more => 'More';

  @override
  String get failedToLoadDiscoverContent => 'Failed to load discover content';

  @override
  String get imageNotAvailable => 'Image not available';

  @override
  String get unavailableUppercase => 'UNAVAILABLE';

  @override
  String get keyServerConnectionFailed => 'Key Server Connection Failed';

  @override
  String get unableToReachKeyServer =>
      'Unable to reach the key server to download the latest keys';

  @override
  String get restrictedRegionOrNetwork => 'Restricted Region or Network';

  @override
  String get restrictedRegionOrNetworkDescription =>
      'If you are located in a region with internet restrictions or ISP censorship, access to the server may be blocked\\n\\nPlease enable a VPN or proxy and tap Retry to download new keys';

  @override
  String get keyServerOfflineNote =>
      'Note: You can still use the app with cached/offline keys, but certain dlcs may not be available until keys are updated';

  @override
  String get continueOffline => 'Continue Offline';

  @override
  String get retrying => 'Retrying...';

  @override
  String get mcDecryptor => 'McDecryptor';

  @override
  String get notificationPermission => 'Notification Permission';

  @override
  String get notificationPermissionDescription =>
      'Notification permission should be granted if you want background download to properly work';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get loading3DPersona => 'Loading 3D persona...';

  @override
  String get openFull3DViewer => 'Open Full 3D Viewer';

  @override
  String get manage => 'Manage';

  @override
  String get signInWithMicrosoftDescription =>
      'Sign in with Microsoft to access your bought DLCs';

  @override
  String get downloadsAndStorage => 'Downloads & Storage';

  @override
  String get downloadsAndStorageSubtitle =>
      'Custom path, zip compression, cache';

  @override
  String get keysAndTools => 'Keys & Tools';

  @override
  String get supportAndCommunity => 'Support & Community';

  @override
  String get frequentlyAskedQuestions => 'Frequently asked questions';

  @override
  String get aboutAndDiagnostics => 'About & Diagnostics';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get youAreUsingTheLatestVersion => 'You are using the latest version.';

  @override
  String get close => 'Close';

  @override
  String get ignore1Day => 'Ignore 1 day';

  @override
  String get openInBrowser => 'Open in Browser';

  @override
  String get installApk => 'Install APK';

  @override
  String get openFile => 'Open File';

  @override
  String savedTo(String path) {
    return 'Saved to: $path';
  }

  @override
  String get zipPassword => 'ZIP Password:';

  @override
  String get copyPassword => 'Copy password';

  @override
  String get unsupportedSkinFormat => 'Unsupported Skin Format';

  @override
  String get invalidSkinFormatMessage =>
      'Invalid skin format. Please select a valid Minecraft skin PNG (64x64, 128x128, or 64x32).';

  @override
  String customPersonaSkinUpdated(String skinName) {
    return 'Custom 3D persona skin updated to \"$skinName\"';
  }

  @override
  String get resetPersonaSkinQuestion => 'Reset 3D Persona Skin?';

  @override
  String get resetPersonaSkinDescription =>
      'This will restore the default 3D persona mannequin model.';

  @override
  String get reset => 'Reset';

  @override
  String get resetPersonaSkinSuccess =>
      'Reset to default 3D persona mannequin model';

  @override
  String get themeAndFont => 'Theme & Font';

  @override
  String get options3D => '3D Options';

  @override
  String get preview3D => '3D Preview';

  @override
  String get show3DPreviewSubtitle => 'Show 3D preview for skins and emotes';

  @override
  String get hide3DPreviewSubtitle => 'Hide 3D preview for skins and emotes';

  @override
  String get adaptiveResolution => 'Adaptive Resolution';

  @override
  String get adaptiveResolutionDescription =>
      'Dynamically adjust 3D preview resolution (recommended for weaker devices)';

  @override
  String get customCharacterSkin => 'Custom Character Skin';

  @override
  String get updating3DPersona => 'Updating 3D persona...';

  @override
  String activeCustomSkin(String skinName) {
    return 'Active: $skinName';
  }

  @override
  String get defaultMannequin => 'Default (Mannequin)';

  @override
  String get chooseSkinPng => 'Choose skin PNG';

  @override
  String get languages => 'Languages';

  @override
  String get downloadPathResetTitle => 'Download path reset';

  @override
  String downloadPathResetFallback(String stale, String fallback) {
    return 'Couldn\'t find $stale, falling back to $fallback';
  }

  @override
  String get downloadLocation => 'Download Location';

  @override
  String get fileAndImageFormats => 'File & Image Formats';

  @override
  String get temporaryFiles => 'Temporary files';

  @override
  String get checkForKeysUpdate => 'Check for keys update';

  @override
  String get filtersAndDisplay => 'Filters & Display';

  @override
  String get tools => 'Tools';

  @override
  String get dark => 'Dark';

  @override
  String get light => 'Light';

  @override
  String get discovery => 'Discovery';

  @override
  String get relevance => 'Relevance';

  @override
  String get emotes => 'Emotes';

  @override
  String failedToLoad3dPreview(String error) {
    return 'Failed to load 3D preview: $error';
  }

  @override
  String get idle => 'Idle';

  @override
  String get walk => 'Walk';

  @override
  String get pauseTurntable => 'Pause Turntable';

  @override
  String get autoRotate => 'Auto Rotate';

  @override
  String get switchToElytra => 'Switch to Elytra';

  @override
  String get switchToCape => 'Switch to Cape';

  @override
  String get includedSkins => 'Included Skins';

  @override
  String tapToExpand3dSkinPreview(int current, int total) {
    return 'Tap to expand 3D skin preview ($current/$total)';
  }

  @override
  String get tapToPreview3dSkins => 'Tap to preview 3D skins';

  @override
  String get tapToPreviewIncluded3dSkins => 'Tap to preview included 3D skins';

  @override
  String get open3dViewer => 'Open 3D Viewer';

  @override
  String get downloadSkinPack => 'Download skin pack';

  @override
  String get previousSkin => 'Previous skin';

  @override
  String get nextSkin => 'Next skin';

  @override
  String get dragToRotate => 'Drag to rotate';

  @override
  String downloadingAndPreparingSkins(int percent) {
    return 'Downloading & Preparing Skins: $percent%';
  }

  @override
  String get preparing3dSkins => 'Preparing 3D Skins...';

  @override
  String failedToLoadSkins(String error) {
    return 'Failed to load skins: $error';
  }

  @override
  String get viewer3d => '3D Viewer';

  @override
  String get highQualityNativeDpr => 'High Quality (Native DPR)';

  @override
  String get balancedModeOptimized => 'Balanced Mode (Optimized)';

  @override
  String highQualityEnabledNative(String dpr) {
    return 'High Quality enabled (Native ${dpr}x DPR)';
  }

  @override
  String balancedModeEnabled(String dpr) {
    return 'Balanced mode enabled (${dpr}x DPR)';
  }

  @override
  String get resetView => 'Reset View';

  @override
  String get building3dModel => 'Building 3D model...';

  @override
  String get stand => 'Stand';

  @override
  String get cape => 'Cape';

  @override
  String get elytra => 'Elytra';

  @override
  String get turntable => 'Turntable';

  @override
  String get skin => 'Skin';

  @override
  String get keysAreUpToDate => 'Keys are up to date';

  @override
  String get news => 'News';

  @override
  String get stillUnableToReachServer =>
      'Still unable to reach the server. Please check your VPN connection and try again';
}
