// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class AppLocalizationsCs extends AppLocalizations {
  AppLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get home => 'Domov';

  @override
  String get downloads => 'Stažení';

  @override
  String get settings => 'Nastavení';

  @override
  String get selectLanguage => 'Vyberte jazyk';

  @override
  String get language => 'Jazyk';

  @override
  String get download => 'Stáhnout';

  @override
  String get hintText => 'Vyhledávání...';

  @override
  String get default1 => 'Výchozí';

  @override
  String get creators => 'Tvůrci';

  @override
  String get checkingKeys => 'Kontrola klíčů';

  @override
  String get apiLogin => 'Přihlášení k API';

  @override
  String addedNewKeys(int keyCount) {
    return 'Přidáno $keyCount nových klíčů';
  }

  @override
  String get noResult => 'Nenalezeny žádné výsledky';

  @override
  String get open => 'OTEVŘENO';

  @override
  String get clear => 'Jasný';

  @override
  String get retry => 'Zkusit znovu';

  @override
  String get ok => 'OK';

  @override
  String queuePosition(int count) {
    return 'Zařazeno do fronty (Position $count)';
  }

  @override
  String queuePosition2(int count) {
    return 'Fronta #$count)';
  }

  @override
  String imageSaved(String filePath) {
    return 'Obrázek uložen do $filePath';
  }

  @override
  String errorDownloadingImage(String error) {
    return 'Chyba při stahování obrázku: $error';
  }

  @override
  String get changelog => 'Seznam změn';

  @override
  String get downloaded => 'Staženo';

  @override
  String get retryDownload => 'Zkusit stáhnout znovu';

  @override
  String get downloadImage => 'Stáhnout obrázek';

  @override
  String get downloadImageQuestion => 'Stáhnout tento obrázek?';

  @override
  String get cancel => 'Zrušit';

  @override
  String get trailer => 'Sledovat upoutávku';

  @override
  String trailerError(String error) {
    return 'Nepodařilo se otevřít upoutávku: $error';
  }

  @override
  String get appearance => 'Vzhled';

  @override
  String get darkMode => 'Tmavý režim';

  @override
  String get darkEnabled => 'Tmavý motiv povolen';

  @override
  String get lightEnabled => 'Světlý motiv povolen';

  @override
  String get colorScheme => 'Barevné schéma';

  @override
  String get defaultColor => 'Výchozí';

  @override
  String get defaultPurple => 'Výchozí (fialová)';

  @override
  String get colorSchemeBlue => 'Zapomenout';

  @override
  String get colorSchemeGreen => 'Zelený';

  @override
  String get colorSchemeOrange => 'Pomerančový';

  @override
  String get colorSchemeRed => 'Červený';

  @override
  String get colorSchemeTeal => 'Tyrkysová';

  @override
  String get colorSchemePink => 'Růžový';

  @override
  String get colorSchemeLime => 'Jako';

  @override
  String get filters => 'Filtry';

  @override
  String get filter => 'Filtr:';

  @override
  String get showSkins => 'Zobrazit skiny';

  @override
  String get keys => 'Klíče';

  @override
  String get autoUpdate => 'Automatická aktualizace';

  @override
  String get customDb => 'Vlastní databáze';

  @override
  String get accountLogin => 'Přihlášení k účtu';

  @override
  String get extras => 'Doplňky';

  @override
  String get cache => 'Mezipaměť';

  @override
  String cacheCleared(String size) {
    return 'Vymazána mezipaměť $size MB';
  }

  @override
  String get faq => 'Často kladené otázky';

  @override
  String get faqUppercase => 'Často kladené otázky';

  @override
  String get terminal => 'Terminál';

  @override
  String get faqQuestion1 =>
      'Prosím, přidejte klíče k tomuto a tamtomu balíčku!';

  @override
  String get faqQuestion2 => 'Kdy budou klíče aktualizovány?';

  @override
  String get faqQuestion3 => 'Jaký je rozdíl mezi šifrovaným a dešifrovaným';

  @override
  String get faqQuestion4 => 'Kde najdu stažené balíčky?';

  @override
  String get faqQuestion5 => 'Co je keys.tsv';

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
      'Proces získávání klíčů není magie: člověk si stále musí balíček koupit a sdílet s námi klíče. Bez toho, aby si je někdo koupil, by v první řadě neexistovaly žádné dešifrovací klíče. Je to tak není možné je získat jiným způsobem. Trpělivě počkejte nebo si je kupte';

  @override
  String get faqAnswer2 => 'Jakmile jsme se pro to rozhodli.';

  @override
  String get faqAnswer3 =>
      'Zašifrování znamená převedení souboru na zmačkaná slova, která vypadají jako nesmysl. Nikdo si je nemůže přečíst bez speciálního klíče. Zašifrovaný obsah Minecraftu je nehratelný. Dešifrování znamená použití speciálního klíče k převedení nesmyslu zpět do původní podoby. Nyní lze obsah Minecraftu použít.';

  @override
  String get faqAnswer4 => 'Balíčky najdete zde Download/Kyzen';

  @override
  String get faqAnswer5 =>
      'Je to soubor, který ukládá UUID balíčků s příslušnými dešifrovacími klíči. Bez dešifrovacích klíčů by stažené balíčky nebylo možné přehrát.';

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
  String get fileDeleted => 'Soubor smazán';

  @override
  String get storedFiles => 'Uložené soubory';

  @override
  String get refreshFiles => 'Obnovit soubory';

  @override
  String get deleteFile => 'Smazat soubor';

  @override
  String deleteFileConfirmation(String fileName) {
    return 'Opravdu chcete smazat soubor $fileName?';
  }

  @override
  String get cancelUppercase => 'ZRUŠIT';

  @override
  String get deleteUppercase => 'VYMAZAT';

  @override
  String get currentDownload => 'Aktuální stahování';

  @override
  String get noActiveDownloads => 'Žádné aktivní stahování';

  @override
  String get completedDownloads => 'Dokončené stahování';

  @override
  String get clearAll => 'Vymazat vše';

  @override
  String get importToMc => 'Importovat do Minecraftu';

  @override
  String get openFileinExplorer => 'Open in file explorer';

  @override
  String get shareFile => 'Sdílet soubor';

  @override
  String get debugTerminal => 'Ladicí terminál';

  @override
  String get clearLogs => 'Vymazat protokoly';

  @override
  String get noLogs => 'Zatím žádné protokoly...';

  @override
  String get saveLogs => 'Save logs';

  @override
  String logsSaved(String filePath) {
    return 'Logs saved to $filePath';
  }

  @override
  String get selectingFile => 'Výběr souboru...';

  @override
  String get processingFile => 'Zpracování souboru...';

  @override
  String get fileProcessed => 'Soubor byl úspěšně zpracován!';

  @override
  String get noFileSelected => 'Žádný výběr souboru';

  @override
  String customKeysLoaded(int count) {
    return '$count načteny vlastní klíče';
  }

  @override
  String get noCustomKeysLoaded => 'Žádné vlastní klíče nejsou načteny';

  @override
  String get importFileFormat => 'Importovat soubor s formátem UUID=KEY';

  @override
  String creatorItemsWithType(String contentType) {
    return 'Položky typu $contentType';
  }

  @override
  String creatorItemsWithTypeAndCount(String contentType, int count) {
    return '$contentType položek ($count)';
  }

  @override
  String get creatorItemsDefault => 'Položky pro tvůrce';

  @override
  String get noItemCreator => 'Tento tvůrce nemá žádný obsah';

  @override
  String get noStatistic => 'Žádné statické údaje k dispozici';

  @override
  String get failedLoadStatistic => 'Nepodařilo se načíst statické údaje';

  @override
  String get noResultsFound => 'Nenalezeny žádné výsledky';

  @override
  String get microsoftAuth => 'Ověřování Microsoftu';

  @override
  String get exchangingToken => 'Výměna autorizačního kódu za token...';

  @override
  String authenticationFailed(String error) {
    return 'Ověření se nezdařilo: $error';
  }

  @override
  String get authenticationSuccessful => 'Ověření úspěšné!';

  @override
  String failedToExchangeToken(String error) {
    return 'Výměna kódu za token se nezdařilo: $error';
  }

  @override
  String get noAuthorizationCodeReceived => 'Nebyl přijat autorizační kód';

  @override
  String get noNewKeysCopy => 'Nebyly nalezeny žádné nové klíče ke kopírování.';

  @override
  String get keysCopyClipboard => 'Klíče zkopírovány do schránky!';

  @override
  String get noNewKeysShare => 'Nenalezeny žádné nové klíče ke sdílení';

  @override
  String get keysShared => 'Klíče byly úspěšně sdíleny!';

  @override
  String get authCheck => 'Kontrola stávajícího ověřování...';

  @override
  String get alreadyAuth => 'Již ověřeno!';

  @override
  String get readyAuth => 'Připraveno k ověření';

  @override
  String get authURL => 'Ověření pomocí URL adresy';

  @override
  String get completeAuthButton => 'Complete Authentication';

  @override
  String get openAuthPageButton => 'Open Auth Page';

  @override
  String get completeAuth =>
      'Dokončete ověření ve vašem prohlížeči. Budete přesměrováni zpět do aplikace.';

  @override
  String get copyUrl => 'Copy URL';

  @override
  String get authPageFail => 'Nepodařilo se otevřít ověřovací stránku';

  @override
  String get logout => 'Odhlašování...';

  @override
  String get logoutOk => 'Úspěšně odhlášen/a';

  @override
  String get usingCachedSession => 'Používání relace uložené v mezipaměti';

  @override
  String get loadingMinecraftKeys => 'Načítání klíčů Minecraftu...';

  @override
  String get requestingXboxLiveToken => 'Žádost o token Xbox Live...';

  @override
  String get loggingInToPlayFab => 'Přihlášení do PlayFabu';

  @override
  String get gettingUserInformation => 'Získávání informací o uživateli...';

  @override
  String get startingMinecraftSession => 'Zahájení hry Minecraft...';

  @override
  String get loadingMinecraftInventory => 'Načítání inventáře Minecraftu...';

  @override
  String successfullyLoadedKeys(int keyCount) {
    return 'Úspěšně vytvořeno $keyCount klíčů!';
  }

  @override
  String errorLoadingKeys(String error) {
    return 'Chyba při načítání klíčů: $error';
  }

  @override
  String get copyClipboard => 'Zkopírováno do schránky';

  @override
  String get authOk => 'Ověřeno';

  @override
  String get authNotOk => 'Neověřeno';

  @override
  String get urlAuth => 'URL ověřování';

  @override
  String get loadedKeys => 'Nabité klíče';

  @override
  String get exportNewKeys => 'Exportovat pouze nové klíče';

  @override
  String get loadKeysButton => 'Načíst klíče';

  @override
  String get logoutButton => 'Odhlásit se';

  @override
  String get startAuthButton => 'Spustit ověřování';

  @override
  String get greetings => 'Ahoj';

  @override
  String get copy => 'Copy';

  @override
  String get save => 'Save';

  @override
  String get share => 'Share';

  @override
  String get keysSaved => 'Keys saved successfully';

  @override
  String get startingDownload => 'Zahájení stahování...';

  @override
  String get downloadsCompleted => 'Stahování dokončeno';

  @override
  String get completed => 'Dokončeno!';

  @override
  String get downloadFailed => 'Stahování se nezdařilo';

  @override
  String get downloading => 'Stahování';

  @override
  String get processing => 'Zpracování';

  @override
  String get extractingZipFile => 'Extrahování zip souboru...';

  @override
  String get decryptingContents => 'Dešifrování obsahu...';

  @override
  String get compressingPack => 'Kompresní balení...';

  @override
  String get cleaningUp => 'Úklid...';

  @override
  String get showAll => 'Zobrazit vše';

  @override
  String get onlyAvailable => 'K dispozici pouze';

  @override
  String get onlyNotAvailable => 'Pouze není k dispozici';

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
      'Společnost Google oznámila, že od roku 2026/2027 budou všechny aplikace na certifikovaných zařízeních Android vyžadovat, aby vývojář odeslal své osobní identifikační údaje přímo společnosti Google. Jelikož vývojáři této aplikace s tímto požadavkem nesouhlasí, aplikace po tomto datu přestane na certifikovaných zařízeních Android fungovat.';

  @override
  String get freeDroidWarnDetails => 'Podrobnosti';

  @override
  String get freeDroidWarnSolution => 'Řešení';

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
