// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get home => 'Головна';

  @override
  String get downloads => 'Завантаження';

  @override
  String get settings => 'Налаштування';

  @override
  String get selectLanguage => 'Вибрати Мову';

  @override
  String get language => 'Мова';

  @override
  String get download => 'Завантажити';

  @override
  String get hintText => 'Пошук...';

  @override
  String get default1 => 'За замовчуванням';

  @override
  String get creators => 'Автори';

  @override
  String get checkingKeys => 'Перевірка ключів';

  @override
  String get apiLogin => 'API Вхід';

  @override
  String addedNewKeys(int keyCount) {
    return 'Додано $keyCount нових ключів';
  }

  @override
  String get noResult => 'Нічого не знайдено';

  @override
  String get open => 'Відкрити';

  @override
  String get clear => 'Очистити';

  @override
  String get retry => 'Повторити';

  @override
  String get ok => 'OK';

  @override
  String queuePosition(int count) {
    return 'В черзі (Позиція №$count)';
  }

  @override
  String queuePosition2(int count) {
    return 'В черзі №$count)';
  }

  @override
  String imageSaved(String filePath) {
    return 'Зображення збережено за шляхом $filePath';
  }

  @override
  String errorDownloadingImage(String error) {
    return 'Помилка завантаження зображення: $error';
  }

  @override
  String get changelog => 'Історія змін';

  @override
  String get downloaded => 'Завантажено';

  @override
  String get retryDownload => 'Повторити Завантаження';

  @override
  String get downloadImage => 'Завантажити Зображення';

  @override
  String get downloadImageQuestion => 'Завантажити це зображення?';

  @override
  String get cancel => 'Скасувати';

  @override
  String get trailer => 'Дивитись Трейлер';

  @override
  String trailerError(String error) {
    return 'Не вдалося відкрити трейлер: $error';
  }

  @override
  String get appearance => 'Зовнішній Вигляд';

  @override
  String get darkMode => 'Тема';

  @override
  String get darkEnabled => 'Темна тема';

  @override
  String get lightEnabled => 'Світла тема';

  @override
  String get colorScheme => 'Кольорова схема';

  @override
  String get defaultColor => 'За замовчуванням';

  @override
  String get defaultPurple => 'За замовчуванням (Фіолетовий)';

  @override
  String get colorSchemeBlue => 'Синій';

  @override
  String get colorSchemeGreen => 'Зелений';

  @override
  String get colorSchemeOrange => 'Помаранчевий';

  @override
  String get colorSchemeRed => 'Червоний';

  @override
  String get colorSchemeTeal => 'Бірюзовий';

  @override
  String get colorSchemePink => 'Рожевий';

  @override
  String get colorSchemeLime => 'Лаймовий';

  @override
  String get filters => 'Фільтри';

  @override
  String get filter => 'Фільтр:';

  @override
  String get showSkins => 'Показувати скіни';

  @override
  String get keys => 'Ключі';

  @override
  String get autoUpdate => 'Авто-оновлення';

  @override
  String get customDb => 'Користувацька БД';

  @override
  String get accountLogin => 'Вхід в акаунт';

  @override
  String get extras => 'Додатково';

  @override
  String get cache => 'Кеш';

  @override
  String cacheCleared(String size) {
    return 'Очищено $size МБ кешу';
  }

  @override
  String get faq => 'ЧаПи';

  @override
  String get faqUppercase => 'ЧАПИ';

  @override
  String get terminal => 'Термінал';

  @override
  String get faqQuestion1 =>
      'Будь ласка, додайте ключі для цього і того пакету!';

  @override
  String get faqQuestion2 => 'Коли ключі будуть оновлені?';

  @override
  String get faqQuestion3 => 'У чому різниця між зашифрованим і розшифрованим?';

  @override
  String get faqQuestion4 => 'Де я можу знайти завантажені пакети?';

  @override
  String get faqQuestion5 => 'Що таке keys.tsv?';

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
      'Процес отримання ключів — це не магія: людина все одно має купити пакет і поділитися з нами ключами. Якщо ніхто не купить, то і ключів для розшифровки не буде. Отримати їх яким-небудь іншим способом неможливо. Чекайте терпляче або купуйте самі.';

  @override
  String get faqAnswer2 => 'Коли ми вирішимо оновити і точка';

  @override
  String get faqAnswer3 =>
      'Зашифрований означає, що файл перетворюється на набір безглуздих символів. Ніхто не може прочитати його без спеціального ключа. Зашифровані матеріали Minecraft не можна використовувати.\n\nРозшифрований означає використання спеціального ключа для перетворення безглуздих символів назад у вміст. Тепер матеріали Minecraft можна використовувати.';

  @override
  String get faqAnswer4 => 'Ви можете знайти пакети тут: Downloads/Kyzen';

  @override
  String get faqAnswer5 =>
      'Це файл, який зберігає UUID пакетів з відповідними ключами дешифрування. Без ключів дешифрування завантажені пакети не можна буде використовувати.';

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
  String get fileDeleted => 'Файл видалено';

  @override
  String get storedFiles => 'Збережені Файли';

  @override
  String get refreshFiles => 'Оновити файли';

  @override
  String get deleteFile => 'Видалити файл';

  @override
  String deleteFileConfirmation(String fileName) {
    return 'Ви впевнені, що хочете видалити $fileName?';
  }

  @override
  String get cancelUppercase => 'СКАСУВАТИ';

  @override
  String get deleteUppercase => 'ВИДАЛИТИ';

  @override
  String get currentDownload => 'Поточне Завантаження';

  @override
  String get noActiveDownloads => 'Немає активних завантажень';

  @override
  String get completedDownloads => 'Завершені Завантаження';

  @override
  String get clearAll => 'Очистити Все';

  @override
  String get importToMc => 'Імпорт в Minecraft';

  @override
  String get openFileinExplorer => 'Відкрити у Провіднику';

  @override
  String get shareFile => 'Поділитися файлом';

  @override
  String get debugTerminal => 'Термінал Зневадження';

  @override
  String get clearLogs => 'Очистити Логи';

  @override
  String get noLogs => 'Логів поки що немає...';

  @override
  String get saveLogs => 'Save logs';

  @override
  String logsSaved(String filePath) {
    return 'Logs saved to $filePath';
  }

  @override
  String get selectingFile => 'Вибір файлу...';

  @override
  String get processingFile => 'Обробка файлу...';

  @override
  String get fileProcessed => 'Файл успішно оброблено!';

  @override
  String get noFileSelected => 'Файл не вибрано';

  @override
  String customKeysLoaded(int count) {
    return 'Завантажено $count користувацьких ключів';
  }

  @override
  String get noCustomKeysLoaded => 'Користувацькі ключі не завантажено';

  @override
  String get importFileFormat => 'Імпорт файлу у форматі UUID=KEY';

  @override
  String creatorItemsWithType(String contentType) {
    return 'Елементи $contentType';
  }

  @override
  String creatorItemsWithTypeAndCount(String contentType, int count) {
    return 'Елементи $contentType ($count)';
  }

  @override
  String get creatorItemsDefault => 'Елементи Автора';

  @override
  String get noItemCreator => 'У цього автора немає контенту';

  @override
  String get noStatistic => 'Немає доступної статистики';

  @override
  String get failedLoadStatistic => 'Не вдалося завантажити статистику';

  @override
  String get noResultsFound => 'Нічого не знайдено';

  @override
  String get microsoftAuth => 'Аутентифікація Microsoft';

  @override
  String get exchangingToken => 'Обмін коду авторизації на токен...';

  @override
  String authenticationFailed(String error) {
    return 'Помилка аутентифікації: $error';
  }

  @override
  String get authenticationSuccessful => 'Аутентифікація успішна!';

  @override
  String failedToExchangeToken(String error) {
    return 'Помилка обміну коду на токен: $error';
  }

  @override
  String get noAuthorizationCodeReceived => 'Код авторизації не отримано';

  @override
  String get noNewKeysCopy => 'Немає нових ключів для копіювання';

  @override
  String get keysCopyClipboard => 'Ключі скопійовано в буфер!';

  @override
  String get noNewKeysShare => 'Немає нових ключів для відправки';

  @override
  String get keysShared => 'Ключі успішно відправлено!';

  @override
  String get authCheck => 'Перевірка існуючої аутентифікації...';

  @override
  String get alreadyAuth => 'Вже аутентифіковано!';

  @override
  String get readyAuth => 'Готовий до аутентифікації';

  @override
  String get authURL => 'Аутентифікація за URL';

  @override
  String get completeAuthButton => 'Complete Authentication';

  @override
  String get openAuthPageButton => 'Open Auth Page';

  @override
  String get completeAuth =>
      'Завершіть аутентифікацію в браузері. Вас буде перенаправлено назад в додаток.';

  @override
  String get copyUrl => 'Copy URL';

  @override
  String get authPageFail => 'Не вдалося відкрити сторінку аутентифікації';

  @override
  String get logout => 'Вихід з системи...';

  @override
  String get logoutOk => 'Вихід виконано успішно';

  @override
  String get usingCachedSession => 'Використання кешованої сесії...';

  @override
  String get loadingMinecraftKeys => 'Завантаження ключів Minecraft...';

  @override
  String get requestingXboxLiveToken => 'Запит токена Xbox Live...';

  @override
  String get loggingInToPlayFab => 'Вхід в PlayFab...';

  @override
  String get gettingUserInformation =>
      'Отримання інформації про користувача...';

  @override
  String get startingMinecraftSession => 'Запуск сесії Minecraft...';

  @override
  String get loadingMinecraftInventory => 'Завантаження інвентарю Minecraft...';

  @override
  String successfullyLoadedKeys(int keyCount) {
    return 'Успішно завантажено $keyCount ключів!';
  }

  @override
  String errorLoadingKeys(String error) {
    return 'Помилка завантаження ключів: $error';
  }

  @override
  String get copyClipboard => 'Скопійовано в буфер';

  @override
  String get authOk => 'Аутентифіковано';

  @override
  String get authNotOk => 'Не аутентифіковано';

  @override
  String get urlAuth => 'URL аутентифікації';

  @override
  String get loadedKeys => 'Завантажені ключі';

  @override
  String get exportNewKeys => 'Експорт лише нових ключів';

  @override
  String get loadKeysButton => 'Завантажити ключі';

  @override
  String get logoutButton => 'Вийти';

  @override
  String get startAuthButton => 'Почати аутентифікацію';

  @override
  String get greetings => 'Вітаю, ';

  @override
  String get copy => 'Copy';

  @override
  String get save => 'Save';

  @override
  String get share => 'Share';

  @override
  String get keysSaved => 'Keys saved successfully';

  @override
  String get startingDownload => 'Початок завантаження...';

  @override
  String get downloadsCompleted => 'Завантаження завершено';

  @override
  String get completed => 'Завершено!';

  @override
  String get downloadFailed => 'Помилка завантаження';

  @override
  String get downloading => 'Завантаження';

  @override
  String get processing => 'Обробка';

  @override
  String get extractingZipFile => 'Розпаковка zip-файлу...';

  @override
  String get decryptingContents => 'Розшифровка вмісту...';

  @override
  String get compressingPack => 'Стиснення пакета...';

  @override
  String get cleaningUp => 'Очищення...';

  @override
  String get showAll => 'Показувати все';

  @override
  String get onlyAvailable => 'Лише доступне';

  @override
  String get onlyNotAvailable => 'Лише недоступне';

  @override
  String get customColor => 'Свій колір';

  @override
  String get changeCustomColor => 'Натисніть, щоб змінити свій колір';

  @override
  String get createCustomColor => 'Створити свою кольорову схему';

  @override
  String get pickColor => 'Вибрати колір';

  @override
  String get selectColor => 'Вибрати';

  @override
  String get images => 'Зображення';

  @override
  String get saveToPng => 'Зберегти в PNG';

  @override
  String get saveToGallery => 'Зберегти в галерею';

  @override
  String get compression => 'Стиснення';

  @override
  String get normalCompression => 'Звичайне стиснення';

  @override
  String get noCompression => 'Без стиснення';

  @override
  String get copyUUID => 'Скопіювати UUID';

  @override
  String get openInMinecraft => 'Відкрити в Minecraft';

  @override
  String get creator => 'Автор';

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
  String get newUpdate => 'Нове оновлення';

  @override
  String get newDlc => 'Новий DLC';

  @override
  String get hidden => 'Приховано';

  @override
  String get persona => 'Аксесуари';

  @override
  String get skins => 'Скіни';

  @override
  String get mashups => 'Збірки';

  @override
  String get worlds => 'Світи';

  @override
  String get textures => 'Текстури';

  @override
  String get addons => 'Аддони';

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
  String get menu => 'Меню';

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
