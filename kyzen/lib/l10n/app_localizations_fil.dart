// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Filipino Pilipino (`fil`).
class AppLocalizationsFil extends AppLocalizations {
  AppLocalizationsFil([String locale = 'fil']) : super(locale);

  @override
  String get home => 'Bahay';

  @override
  String get downloads => 'Mga download';

  @override
  String get settings => 'Mga setting';

  @override
  String get selectLanguage => 'Piliin ang Wika';

  @override
  String get language => 'Wika';

  @override
  String get download => 'I-download';

  @override
  String get hintText => 'Hanapin...';

  @override
  String get default1 => 'Default';

  @override
  String get creators => 'Mga tagalikha';

  @override
  String get checkingKeys => 'Sinusuri ang mga susi';

  @override
  String get apiLogin => 'Pag-login sa API';

  @override
  String addedNewKeys(int keyCount) {
    return 'Nagdagdag ng $keyCount ng mga bagong key';
  }

  @override
  String get noResult => 'Walang nakitang resulta';

  @override
  String get open => 'Bukas';

  @override
  String get clear => 'Maaliwalas';

  @override
  String get retry => 'Subukan muli';

  @override
  String get ok => 'OK';

  @override
  String queuePosition(int count) {
    return 'Nakapila (Posisyon #$count)';
  }

  @override
  String queuePosition2(int count) {
    return 'Nakapila #$count)';
  }

  @override
  String imageSaved(String filePath) {
    return 'Na-save ang larawan sa $filePath';
  }

  @override
  String errorDownloadingImage(String error) {
    return 'Error sa pag-download ng larawan: $error';
  }

  @override
  String get changelog => 'Mga Pinagbago (Changelog)';

  @override
  String get downloaded => 'Na-download';

  @override
  String get retryDownload => 'Subukan muli ang pag-download';

  @override
  String get downloadImage => 'I-download ang Larawan';

  @override
  String get downloadImageQuestion => 'I-download ang larawang ito?';

  @override
  String get cancel => 'Kanselahin';

  @override
  String get trailer => 'Panoorin ang Trailer';

  @override
  String trailerError(String error) {
    return 'Hindi mabuksan ang trailer: $error';
  }

  @override
  String get appearance => 'Hitsura';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get darkEnabled => 'Naka-enable ang madilim na tema';

  @override
  String get lightEnabled => 'Banayad na tema ay pinagana';

  @override
  String get colorScheme => 'Kulay Scheme';

  @override
  String get defaultColor => 'Default';

  @override
  String get defaultPurple => 'Default (Purple)';

  @override
  String get colorSchemeBlue => 'Asul';

  @override
  String get colorSchemeGreen => 'Berde';

  @override
  String get colorSchemeOrange => 'Kahel';

  @override
  String get colorSchemeRed => 'Pula';

  @override
  String get colorSchemeTeal => 'Teal';

  @override
  String get colorSchemePink => 'Rosas';

  @override
  String get colorSchemeLime => 'Dayap';

  @override
  String get filters => 'Mga filter';

  @override
  String get filter => 'Salain:';

  @override
  String get showSkins => 'Ipakita ang mga skins';

  @override
  String get keys => 'Mga susi';

  @override
  String get autoUpdate => 'Auto-update';

  @override
  String get customDb => 'Custom na DB';

  @override
  String get accountLogin => 'Pag-login sa account';

  @override
  String get extras => 'Mga extra';

  @override
  String get cache => 'Cache';

  @override
  String cacheCleared(String size) {
    return 'Na-clear ang $size MB ng cache';
  }

  @override
  String get faq => 'Faq';

  @override
  String get faqUppercase => 'FAQ';

  @override
  String get terminal => 'Terminal';

  @override
  String get faqQuestion1 =>
      'Pakidagdag ang mga susi para dito at sa paketeng iyon!';

  @override
  String get faqQuestion2 => 'Kailan maa-update ang mga susi?';

  @override
  String get faqQuestion3 =>
      'Ano ang pagkakaiba sa pagitan ng naka-encrypt at naka-decrypt?';

  @override
  String get faqQuestion4 => 'Saan ko mahahanap ang mga na-download na pack?';

  @override
  String get faqQuestion5 => 'Ano ang keys.tsv';

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
      'Ang proseso ng pagkuha ng mga susi ay hindi magic: kailangan pa ring bilhin ng isang tao ang pakete at ibahagi ang mga susi sa amin. Kung walang bibili nito, walang mga decryption key sa unang lugar. Ito ay hindi';

  @override
  String get faqAnswer2 => 'Sa sandaling nagpasya kaming.';

  @override
  String get faqAnswer3 =>
      'Nangangahulugan ang naka-encrypt na gawing mga scrambled na salita ang file na mukhang walang kwenta. Walang makakabasa nito nang walang espesyal na susi. Ang mga naka-encrypt na nilalaman ng Minecraft ay hindi nape-play. Ang ibig sabihin ng decrypted ay ang paggamit ng espesyal';

  @override
  String get faqAnswer4 =>
      'Maaari mong mahanap ang mga pack dito Download/Kyzen';

  @override
  String get faqAnswer5 =>
      'Ito ay isang file na nag-iimbak ng mga UUID ng pack kasama ng kani-kanilang mga decryption key, kung wala ang mga decryption key, ang mga na-download na pack ay hindi mailalaro';

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
  String get fileDeleted => 'Tinanggal ang file';

  @override
  String get storedFiles => 'Mga Naka-imbak na File';

  @override
  String get refreshFiles => 'I-refresh ang mga file';

  @override
  String get deleteFile => 'Tanggalin ang file';

  @override
  String deleteFileConfirmation(String fileName) {
    return 'Sigurado ka bang gusto mong tanggalin ang $fileName?';
  }

  @override
  String get cancelUppercase => 'KANSELAHIN';

  @override
  String get deleteUppercase => 'I-DELETE';

  @override
  String get currentDownload => 'Kasalukuyang Download';

  @override
  String get noActiveDownloads => 'Walang aktibong pag-download';

  @override
  String get completedDownloads => 'Mga Nakumpletong Pag-download';

  @override
  String get clearAll => 'I-clear ang Lahat';

  @override
  String get importToMc => 'Mag-import sa Minecraft';

  @override
  String get openFileinExplorer => 'Buksan sa file explorer';

  @override
  String get shareFile => 'Ibahagi ang file';

  @override
  String get debugTerminal => 'Debug Terminal';

  @override
  String get clearLogs => 'I-clear ang mga log';

  @override
  String get noLogs => 'Wala pang log...';

  @override
  String get saveLogs => 'Save logs';

  @override
  String logsSaved(String filePath) {
    return 'Logs saved to $filePath';
  }

  @override
  String get selectingFile => 'Pinipili ang file...';

  @override
  String get processingFile => 'Pinoproseso ang file...';

  @override
  String get fileProcessed => 'Matagumpay na naproseso ang file!';

  @override
  String get noFileSelected => 'Walang napiling file';

  @override
  String customKeysLoaded(int count) {
    return 'Na-load ang $count custom na key';
  }

  @override
  String get noCustomKeysLoaded => 'Walang na-load na custom na key.';

  @override
  String get importFileFormat => 'Mag-import ng file na may UUID=KEY na format';

  @override
  String creatorItemsWithType(String contentType) {
    return '$contentType Mga Item';
  }

  @override
  String creatorItemsWithTypeAndCount(String contentType, int count) {
    return '$contentType Mga Item ($count)';
  }

  @override
  String get creatorItemsDefault => 'Mga Item ng Tagapaglikha';

  @override
  String get noItemCreator => 'Walang content ang creator na ito';

  @override
  String get noStatistic => 'Walang available na static';

  @override
  String get failedLoadStatistic => 'Nabigong mag-load ng statics';

  @override
  String get noResultsFound => 'Walang nakitang resulta';

  @override
  String get microsoftAuth => 'Microsoft Authentication';

  @override
  String get exchangingToken =>
      'Pagpapalitan ng authorization code para sa token...';

  @override
  String authenticationFailed(String error) {
    return 'Nabigo ang pagpapatotoo: $error';
  }

  @override
  String get authenticationSuccessful => 'Matagumpay ang pagpapatotoo!';

  @override
  String failedToExchangeToken(String error) {
    return 'Nabigong palitan ang code para sa token: $error';
  }

  @override
  String get noAuthorizationCodeReceived =>
      'Walang natanggap na authorization code';

  @override
  String get noNewKeysCopy => 'Walang nakitang mga bagong key upang kopyahin';

  @override
  String get keysCopyClipboard => 'Nakopya ang mga key sa clipboard!';

  @override
  String get noNewKeysShare => 'Walang nakitang mga bagong key upang ibahagi';

  @override
  String get keysShared => 'Matagumpay na naibahagi ang mga susi!';

  @override
  String get authCheck => 'Sinusuri ang kasalukuyang pagpapatunay...';

  @override
  String get alreadyAuth => 'Na-authenticate na';

  @override
  String get readyAuth => 'Handa nang magpatotoo';

  @override
  String get authURL => 'Patotohanan gamit ang URL';

  @override
  String get completeAuthButton => 'Complete Authentication';

  @override
  String get openAuthPageButton => 'Open Auth Page';

  @override
  String get completeAuth =>
      'Kumpletuhin ang pagpapatunay sa iyong browser. Ire-redirect ka pabalik sa aplikasyon';

  @override
  String get copyUrl => 'Copy URL';

  @override
  String get authPageFail =>
      'Hindi binuksan ng Cloud ang pahina ng pagpapatunay';

  @override
  String get logout => 'Nagla-log out...';

  @override
  String get logoutOk => 'Matagumpay na naka-log out';

  @override
  String get usingCachedSession => 'Gamit ang naka-cache na session';

  @override
  String get loadingMinecraftKeys => 'Nilo-load ang mga Minecraft key...';

  @override
  String get requestingXboxLiveToken => 'Humihiling ng Xbox Live token';

  @override
  String get loggingInToPlayFab => 'Nagla-log in sa PlayFab...';

  @override
  String get gettingUserInformation => 'Pagkuha ng impormasyon ng user...';

  @override
  String get startingMinecraftSession =>
      'Sinisimulan ang sesyon ng Minecraft...';

  @override
  String get loadingMinecraftInventory =>
      'Nilo-load ang imbentaryo ng Minecraft...';

  @override
  String successfullyLoadedKeys(int keyCount) {
    return 'Matagumpay na na-load ang $keyCount na mga key!';
  }

  @override
  String errorLoadingKeys(String error) {
    return 'Error sa paglo-load ng mga key: $error';
  }

  @override
  String get copyClipboard => 'Kinopya sa clipboard';

  @override
  String get authOk => 'Napatotohanan';

  @override
  String get authNotOk => 'Hindi Na-authenticate';

  @override
  String get urlAuth => 'URL ng pagpapatunay';

  @override
  String get loadedKeys => 'Mga Na-load na Susi';

  @override
  String get exportNewKeys => 'I-export lamang ang mga bagong key';

  @override
  String get loadKeysButton => 'Mag-load ng mga susi';

  @override
  String get logoutButton => 'Mag-logout';

  @override
  String get startAuthButton => 'Simulan ang Authentication';

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
  String get startingDownload => 'Sinisimulan ang pag-download...';

  @override
  String get downloadsCompleted => 'Nakumpleto ang mga pag-download';

  @override
  String get completed => 'Comeplted!';

  @override
  String get downloadFailed => 'Nabigo ang pag-download';

  @override
  String get downloading => 'Nagda-download';

  @override
  String get processing => 'Pinoproseso';

  @override
  String get extractingZipFile => 'Pag-extract ng zip file';

  @override
  String get decryptingContents => 'Nagde-decrypt ng mga nilalaman...';

  @override
  String get compressingPack => 'Kino-compress ang pack...';

  @override
  String get cleaningUp => 'Naglilinis...';

  @override
  String get showAll => 'Ipakita ang lahat';

  @override
  String get onlyAvailable => 'Available lang';

  @override
  String get onlyNotAvailable => 'Hindi lang available';

  @override
  String get customColor => 'Pasadyang kulay';

  @override
  String get changeCustomColor =>
      'I-tap para baguhin ang iyong custom na kulay';

  @override
  String get createCustomColor => 'Lumikha ng iyong sariling scheme ng kulay';

  @override
  String get pickColor => 'Pumili ng mga kulay';

  @override
  String get selectColor => 'Pumili';

  @override
  String get images => 'Mga imahe';

  @override
  String get saveToPng => 'I-save sa PNG';

  @override
  String get saveToGallery => 'I-save sa gallery';

  @override
  String get compression => 'Compression';

  @override
  String get normalCompression => 'Normal na Compression';

  @override
  String get noCompression => 'Walang Compression';

  @override
  String get copyUUID => 'Kopyahin ang UUID';

  @override
  String get openInMinecraft => 'Buksan sa Minecraft';

  @override
  String get creator => 'Tagapaglikha';

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
  String get newUpdate => 'Bagong update';

  @override
  String get newDlc => 'Bagong dlc';

  @override
  String get hidden => 'Nakatago';

  @override
  String get persona => 'Persona';

  @override
  String get skins => 'Skins';

  @override
  String get mashups => 'Mga Mashup';

  @override
  String get worlds => 'mga mundo';

  @override
  String get textures => 'Mga texture';

  @override
  String get addons => 'Mga Add-On';

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
