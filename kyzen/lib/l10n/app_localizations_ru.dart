// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get home => 'Главная';

  @override
  String get downloads => 'Загрузки';

  @override
  String get settings => 'Настройки';

  @override
  String get selectLanguage => 'Выбрать язык';

  @override
  String get language => 'Язык';

  @override
  String get download => 'Скачать';

  @override
  String get hintText => 'Поиск...';

  @override
  String get default1 => 'По умолчанию';

  @override
  String get creators => 'Авторы';

  @override
  String get checkingKeys => 'Проверка ключей';

  @override
  String get apiLogin => 'Подключение API';

  @override
  String addedNewKeys(int keyCount) {
    return 'Добавлено $keyCount новых ключей';
  }

  @override
  String get noResult => 'Ничего не найдено';

  @override
  String get open => 'Открыть';

  @override
  String get clear => 'Очистить';

  @override
  String get retry => 'Повторить';

  @override
  String get ok => 'ОК';

  @override
  String queuePosition(int count) {
    return 'В очереди (Позиция #$count)';
  }

  @override
  String queuePosition2(int count) {
    return 'В очереди #$count';
  }

  @override
  String imageSaved(String filePath) {
    return 'Изображение сохранено по пути $filePath';
  }

  @override
  String errorDownloadingImage(String error) {
    return 'Ошибка загрузки изображения: $error';
  }

  @override
  String get changelog => 'История изменений';

  @override
  String get downloaded => 'Загружено';

  @override
  String get retryDownload => 'Повторить загрузку';

  @override
  String get downloadImage => 'Скачать изображение';

  @override
  String get downloadImageQuestion => 'Скачать это изображение?';

  @override
  String get cancel => 'Отмена';

  @override
  String get trailer => 'Смотреть трейлер';

  @override
  String trailerError(String error) {
    return 'Не удалось открыть трейлер: $error';
  }

  @override
  String get appearance => 'Внешний вид';

  @override
  String get darkMode => 'Тема';

  @override
  String get darkEnabled => 'Тёмная тема';

  @override
  String get lightEnabled => 'Светлая тема';

  @override
  String get colorScheme => 'Цветовая схема';

  @override
  String get defaultColor => 'По умолчанию';

  @override
  String get defaultPurple => 'По умолчанию (Фиолетовый)';

  @override
  String get colorSchemeBlue => 'Синий';

  @override
  String get colorSchemeGreen => 'Зелёный';

  @override
  String get colorSchemeOrange => 'Оранжевый';

  @override
  String get colorSchemeRed => 'Красный';

  @override
  String get colorSchemeTeal => 'Бирюзовый';

  @override
  String get colorSchemePink => 'Розовый';

  @override
  String get colorSchemeLime => 'Лаймовый';

  @override
  String get filters => 'Фильтры';

  @override
  String get filter => 'Фильтр:';

  @override
  String get showSkins => 'Показывать скины';

  @override
  String get keys => 'Ключи';

  @override
  String get autoUpdate => 'Авто-обновление';

  @override
  String get customDb => 'Пользовательская БД';

  @override
  String get accountLogin => 'Вход в аккаунт';

  @override
  String get extras => 'Дополнительно';

  @override
  String get cache => 'Кэш';

  @override
  String cacheCleared(String size) {
    return 'Очищено $size МБ кэша';
  }

  @override
  String get faq => 'ЧаВо';

  @override
  String get faqUppercase => 'ЧАВО';

  @override
  String get terminal => 'Терминал';

  @override
  String get faqQuestion1 =>
      'Пожалуйста, добавьте ключи для этого и того пакета!';

  @override
  String get faqQuestion2 => 'Когда ключи будут обновлены?';

  @override
  String get faqQuestion3 =>
      'В чем разница между зашифрованным и расшифрованным?';

  @override
  String get faqQuestion4 => 'Где я могу найти загруженные пакеты?';

  @override
  String get faqQuestion5 => 'Что такое keys.tsv?';

  @override
  String get faqQuestion6 => 'Как использовать аксессуары (Persona)?';

  @override
  String get faqQuestion7 =>
      'Почему некоторые наборы скинов выглядят сломанными?';

  @override
  String get faqQuestion8 => 'Для чего нужна страница «Вход в аккаунт»?';

  @override
  String get faqQuestion9 => 'Что означает галочка?';

  @override
  String get faqAnswer1 =>
      'Процесс получения ключей - это не магия: человек всё равно должен купить пакет и поделиться с нами ключами. Если никто не купит, то и ключей для расшифровки не будет. Получить их каким-либо другим способом невозможно. Ждите терпеливо или покупайте сами.';

  @override
  String get faqAnswer2 => 'Когда мы решим.';

  @override
  String get faqAnswer3 =>
      'Зашифрованный означает, что файл превращается в набор бессмысленных символов. Никто не может прочитать его без специального ключа. Зашифрованные материалы Minecraft нельзя использовать.\n\nРасшифрованный означает использование специального ключа для преобразования бессмысленных символов обратно в исходное содержимое. Теперь материалы Minecraft можно использовать.';

  @override
  String get faqAnswer4 => 'Вы можете найти пакеты здесь: Downloads/Kyzen';

  @override
  String get faqAnswer5 =>
      'Это файл, который хранит UUID пакетов с соответствующими ключами дешифровки. Без ключей дешифровки загруженные пакеты нельзя будет использовать.';

  @override
  String get faqAnswer6 =>
      'Нельзя. Существуют некоторые методы, но учитывая сложность их реализации, это нецелесообразно.';

  @override
  String get faqAnswer7 =>
      'Некоторые наборы скинов (особенно коллаборации с франшизами) используют пользовательскую геометрию, которую Minecraft не позволяет использовать в обычном режиме, если вы не купили набор скинов. Вы можете проверить, использует ли набор скинов пользовательскую геометрию, проверив наличие файла \"geometry.json\" в пакете. Помните, что эта проблема никак не связана с данным инструментом';

  @override
  String get faqAnswer8 =>
      'Страница входа в аккаунт позволяет аутентифицироваться с помощью вашей учетной записи Microsoft, чтобы напрямую загружать ключи Minecraft из вашего инвентаря. Это полезно, когда в Kyzen нет ключа для определенного DLC, но он есть у вас в аккаунте. Как только ваши ключи будут загружены, этот DLC станет доступен для скачивания. Обратите внимание, что ключи автоматически загружаются в нашу базу данных, где позже они будут объединены с основной базой ключей Kyzen, чтобы все могли наслаждаться новыми DLC. Пожалуйста, используйте эту функцию, если хотите внести свой вклад';

  @override
  String get faqAnswer9Checkmark => 'Ключ для этого DLC доступен.';

  @override
  String get faqAnswer9NoCheckmark =>
      'В приложении на данный момент нет ключа для этого DLC.';

  @override
  String get faqAnswer9ExtraInfo => 'Ключи необходимы для разблокировки DLC.';

  @override
  String get faqQuestionDownload => 'Почему кнопка скачивания недоступна?';

  @override
  String get faqAnswerDownload =>
      'Ключ для разблокировки этого DLC недоступен, подождите или купите его.';

  @override
  String get faqQuestionKey => 'Как мне получить ключ?';

  @override
  String get faqAnswerKey =>
      'Купите DLC на свой аккаунт, затем перейдите в Настройки > Вход в аккаунт > Нажмите «Начать аутентификацию» > Нажмите «Загрузить ключи», затем нажмите «Поделиться» и отправьте файлы ключей в чат Bluecoin, ключи будут добавлены в базу данных приложения. Если вы не можете поделиться файлом ключей в группе, не волнуйтесь, ключи автоматически загружаются в базу данных.';

  @override
  String get faqMoreHelp => 'Дополнительная помощь';

  @override
  String get faqNotAdlc => 'Не является DLC';

  @override
  String get faqNotAdlcDescription => 'Этот предмет не является DLC.';

  @override
  String get faqServerContent => 'Серверный контент';

  @override
  String get faqServerContentDescription =>
      'Этот предмет является эксклюзивным для конкретного сервера и не может быть загружен напрямую.';

  @override
  String get fileDeleted => 'Файл удалён';

  @override
  String get storedFiles => 'Сохранённые файлы';

  @override
  String get refreshFiles => 'Обновить файлы';

  @override
  String get deleteFile => 'Удалить файл';

  @override
  String deleteFileConfirmation(String fileName) {
    return 'Вы уверены, что хотите удалить $fileName?';
  }

  @override
  String get cancelUppercase => 'ОТМЕНА';

  @override
  String get deleteUppercase => 'УДАЛИТЬ';

  @override
  String get currentDownload => 'Текущая загрузка';

  @override
  String get noActiveDownloads => 'Нет активных загрузок';

  @override
  String get completedDownloads => 'Завершённые загрузки';

  @override
  String get clearAll => 'Очистить всё';

  @override
  String get importToMc => 'Импорт в Minecraft';

  @override
  String get openFileinExplorer => 'Открыть в Проводнике';

  @override
  String get shareFile => 'Поделиться файлом';

  @override
  String get debugTerminal => 'Терминал отладки';

  @override
  String get clearLogs => 'Очистить логи';

  @override
  String get noLogs => 'Логов пока что нет...';

  @override
  String get saveLogs => 'Сохранить логи';

  @override
  String logsSaved(String filePath) {
    return 'Логи сохранены по пути $filePath';
  }

  @override
  String get selectingFile => 'Выбор файла...';

  @override
  String get processingFile => 'Обработка файла...';

  @override
  String get fileProcessed => 'Файл успешно обработан!';

  @override
  String get noFileSelected => 'Файл не выбран';

  @override
  String customKeysLoaded(int count) {
    return 'Загружено $count пользовательских ключей';
  }

  @override
  String get noCustomKeysLoaded => 'Пользовательские ключи не загружены';

  @override
  String get importFileFormat => 'Импорт файла в формате UUID=KEY';

  @override
  String creatorItemsWithType(String contentType) {
    return 'Элементы $contentType';
  }

  @override
  String creatorItemsWithTypeAndCount(String contentType, int count) {
    return 'Элементы $contentType ($count)';
  }

  @override
  String get creatorItemsDefault => 'Элементы автора';

  @override
  String get noItemCreator => 'У этого автора нет контента';

  @override
  String get noStatistic => 'Нет доступной статистики';

  @override
  String get failedLoadStatistic => 'Не удалось загрузить статистику';

  @override
  String get noResultsFound => 'Ничего не найдено';

  @override
  String get microsoftAuth => 'Аутентификация Microsoft';

  @override
  String get exchangingToken => 'Обмен кода авторизации на токен...';

  @override
  String authenticationFailed(String error) {
    return 'Ошибка аутентификации: $error';
  }

  @override
  String get authenticationSuccessful => 'Аутентификация успешна!';

  @override
  String failedToExchangeToken(String error) {
    return 'Ошибка обмена кода на токен: $error';
  }

  @override
  String get noAuthorizationCodeReceived => 'Код авторизации не получен';

  @override
  String get noNewKeysCopy => 'Нет новых ключей для копирования';

  @override
  String get keysCopyClipboard => 'Ключи скопированы в буфер!';

  @override
  String get noNewKeysShare => 'Нет новых ключей для отправки';

  @override
  String get keysShared => 'Ключи успешно отправлены!';

  @override
  String get authCheck => 'Проверка существующей аутентификации...';

  @override
  String get alreadyAuth => 'Уже аутентифицирован!';

  @override
  String get readyAuth => 'Готово к аутентификации';

  @override
  String get authURL => 'URL аутентификация';

  @override
  String get completeAuthButton => 'Завершить аутентификацию';

  @override
  String get openAuthPageButton => 'Открыть страницу авторизации';

  @override
  String get completeAuth =>
      'Завершите аутентификацию в браузере. Вы будете перенаправлены обратно в приложение.';

  @override
  String get copyUrl => 'Скопировать URL';

  @override
  String get authPageFail => 'Не удалось открыть страницу аутентификации';

  @override
  String get logout => 'Выход из системы...';

  @override
  String get logoutOk => 'Выход выполнен успешно';

  @override
  String get usingCachedSession => 'Использование кэшированной сессии...';

  @override
  String get loadingMinecraftKeys => 'Загрузка ключей Minecraft...';

  @override
  String get requestingXboxLiveToken => 'Запрос токена Xbox Live...';

  @override
  String get loggingInToPlayFab => 'Вход в PlayFab...';

  @override
  String get gettingUserInformation => 'Получение информации о пользователе...';

  @override
  String get startingMinecraftSession => 'Запуск сессии Minecraft...';

  @override
  String get loadingMinecraftInventory => 'Загрузка инвентаря Minecraft...';

  @override
  String successfullyLoadedKeys(int keyCount) {
    return 'Успешно загружено $keyCount ключей!';
  }

  @override
  String errorLoadingKeys(String error) {
    return 'Ошибка загрузки ключей: $error';
  }

  @override
  String get copyClipboard => 'Скопировано в буфер';

  @override
  String get authOk => 'Аутентифицирован';

  @override
  String get authNotOk => 'Не аутентифицирован';

  @override
  String get urlAuth => 'URL аутентификации';

  @override
  String get loadedKeys => 'Загруженные ключи';

  @override
  String get exportNewKeys => 'Экспорт только новых ключей';

  @override
  String get loadKeysButton => 'Загрузить ключи';

  @override
  String get logoutButton => 'Выйти';

  @override
  String get startAuthButton => 'Начать аутентификацию';

  @override
  String get greetings => 'Привет, ';

  @override
  String get copy => 'Копировать';

  @override
  String get save => 'Сохранить';

  @override
  String get share => 'Поделиться';

  @override
  String get keysSaved => 'Ключи успешно сохранены';

  @override
  String get startingDownload => 'Начало загрузки...';

  @override
  String get downloadsCompleted => 'Загрузки завершены';

  @override
  String get completed => 'Завершено!';

  @override
  String get downloadFailed => 'Ошибка загрузки';

  @override
  String get downloading => 'Загрузка';

  @override
  String get processing => 'Обработка';

  @override
  String get extractingZipFile => 'Распаковка zip-файла...';

  @override
  String get decryptingContents => 'Расшифровка содержимого...';

  @override
  String get compressingPack => 'Сжатие пакета...';

  @override
  String get cleaningUp => 'Очистка...';

  @override
  String get showAll => 'Показывать все';

  @override
  String get onlyAvailable => 'Только доступное';

  @override
  String get onlyNotAvailable => 'Только недоступное';

  @override
  String get customColor => 'Свой цвет';

  @override
  String get changeCustomColor => 'Нажмите, чтобы изменить свой цвет';

  @override
  String get createCustomColor => 'Создать свою цветовую схему';

  @override
  String get pickColor => 'Выбрать цвет';

  @override
  String get selectColor => 'Выбрать';

  @override
  String get images => 'Изображения';

  @override
  String get saveToPng => 'Сохранить в PNG';

  @override
  String get saveToGallery => 'Сохранить в галерею';

  @override
  String get compression => 'Сжатие';

  @override
  String get normalCompression => 'Обычное сжатие';

  @override
  String get noCompression => 'Без сжатия';

  @override
  String get copyUUID => 'Скопировать UUID';

  @override
  String get openInMinecraft => 'Открыть в Minecraft';

  @override
  String get creator => 'Автор';

  @override
  String get addToCart => 'Добавить в корзину';

  @override
  String get removeFromCart => 'Убрать из корзины';

  @override
  String get addedToCart => 'Добавлено в корзину';

  @override
  String get removedFromCart => 'Убрано из корзины';

  @override
  String get authRequired => 'Необходима аутентификация';

  @override
  String get authRequiredDesc =>
      'Вам необходимо полностью пройти аутентификацию, чтобы просмотреть вашу корзину. Пожалуйста, авторизуйтесь на странице входа в аккаунт.';

  @override
  String get newUpdate => 'Новое обновление';

  @override
  String get newDlc => 'Новый DLC';

  @override
  String get hidden => 'Скрыто';

  @override
  String get persona => 'Аксессуары';

  @override
  String get skins => 'Скины';

  @override
  String get mashups => 'Сборки';

  @override
  String get worlds => 'Миры';

  @override
  String get textures => 'Текстуры';

  @override
  String get addons => 'Аддоны';

  @override
  String get capes => 'Плащи';

  @override
  String get vibrantVisuals => 'Яркие визуальные эффекты';

  @override
  String get favorites => 'Избранное';

  @override
  String get unfiltered => 'Без фильтра';

  @override
  String get sorting => 'Сортировка';

  @override
  String get type => 'Тип';

  @override
  String get newFilter => 'Новое';

  @override
  String get other => 'Другое';

  @override
  String get newest => 'Сначала новые';

  @override
  String get oldest => 'Сначала старые';

  @override
  String get mostRated => 'С высоким рейтингом';

  @override
  String get leastRated => 'С низким рейтингом';

  @override
  String get menu => 'Меню';

  @override
  String imageSavedToGallery(String filePath) {
    return 'Изображение сохранено в галерею: $filePath';
  }

  @override
  String get vibrantVisualEnhanced => 'Яркие визуальные эффекты (улучш.)';

  @override
  String get uuidCopied => 'UUID скопирован в буфер обмена';

  @override
  String get scrollRight => 'Прокрутить вправо';

  @override
  String get scrollLeft => 'Прокрутить влево';

  @override
  String get previousImage => 'Предыдущее изображение';

  @override
  String get nextImage => 'Следующее изображение';

  @override
  String get favoriteEmpty => 'Ваш список избранного пуст';

  @override
  String get favoriteDescription =>
      'Нажмите на значок сердца на странице деталей любого предмета, чтобы добавить его в избранное и начать формировать свою коллекцию';

  @override
  String get removeFromFavorites => 'Удалить из избранного';

  @override
  String get addToFavorites => 'Добавить в избранное';

  @override
  String get addedToFavorites => 'Добавлено в избранное';

  @override
  String get removedFromFavorites => 'Удалено из избранного';

  @override
  String get noNewKeysFoundToSave => 'Ключи для сохранения не найдены';

  @override
  String get keysSavedSuccessfully =>
      'Ключи успешно сохранены в папку Kyzen';

  @override
  String get entitlementKeys => 'Ключи доступа';

  @override
  String get searchBoughContent => 'Поиск купленного контента Minecraft';

  @override
  String get saveKeys => 'Сохранить ключи';

  @override
  String get refresh => 'Обновить';

  @override
  String get searchKeys => 'Найти ключи';

  @override
  String get loadSkinPersona => 'Загрузить Наборы Скинов/Аксессуары';

  @override
  String get descriptionSkinPersona =>
      'Включить наборы скинов и аксессуары в список';

  @override
  String get loadOnlyNewKeys => 'Загружать только новые ключи';

  @override
  String get descriptionLoadOnlyNewKeys =>
      'Загружать только контент, отсутствующий в базе ключей приложения';

  @override
  String get descriptionExportNewKeys =>
      'Должна ли функция «сохранить ключи» экспортировать только новые ключи';

  @override
  String processedEntitlementKeys(int countFiles, int countKeys) {
    return 'Успешно обработано ($countFiles файлов, $countKeys ключей)';
  }

  @override
  String get noResultsYet => 'Пока нет результатов';

  @override
  String get clickSearchKeysToLoadContent =>
      'Нажмите «Найти ключи», чтобы загрузить ваш контент';

  @override
  String get tryadifferentSearch => 'Попробуйте другой поисковый запрос';

  @override
  String get minecraftNotInstalled =>
      'Действительные пути установки Minecraft не найдены. Убедитесь, что Minecraft Bedrock Edition (UWP или GDK) установлена и запускалась хотя бы один раз.';

  @override
  String get processingError => 'Ошибки обработки';

  @override
  String get dismiss => 'Закрыть';

  @override
  String get failedFiles => 'Необработанные файлы:';

  @override
  String get minecraftFont => 'Шрифт Minecraft';

  @override
  String get usingMinecraftFont => 'Используется шрифт стиля Minecraft';

  @override
  String get usingDefaultFont => 'Используется стандартный шрифт';

  @override
  String get dlcLanguage => 'Язык DLC';

  @override
  String get dlcLangInfo => 'О языке DLC';

  @override
  String get dlcLangInfoText =>
      'Обратите внимание, что некоторые DLC могут не иметь перевода. Это зависит исключительно от маркетплейса, а не от приложения.';

  @override
  String get pageSize => 'Размер страницы';

  @override
  String get pageSizeInfo => 'О размере страницы';

  @override
  String get pageSizeInfoText =>
      'Определяет, сколько элементов загружается одновременно.\n\n • Меньшие значения: лучше для слабого соединения (чаще выполняются запросы)\n • Большие значения: лучше для быстрого соединения (меньше запросов)\n\nВсе результаты остаются доступными независимо от размера страницы. Дополнительные элементы автоматически загружаются при прокрутке списка вниз.';

  @override
  String get selectDlcLanguage => 'Выберите язык DLC';

  @override
  String get downloadPathUpdated => 'Путь загрузки обновлён';

  @override
  String get downloadPathReset => 'Путь загрузки сброшен по умолчанию';

  @override
  String get resetDefaults => 'Сбросить по умолчанию';

  @override
  String get chooseFolder => 'Выбрать папку';

  @override
  String get downloadPath => 'Путь загрузки';

  @override
  String get version => 'Версия';

  @override
  String get purchasing => 'Покупка...';

  @override
  String get failedPurchase => 'Не удалось выполнить покупку';

  @override
  String get allItemsSuccessfullyPurchased => 'Все товары успешно приобретены!';

  @override
  String insufficientFunds(int insufficientFundsItems) {
    return 'Недостаточно средств для $insufficientFundsItems товар(ов)';
  }

  @override
  String get somePurchasesFailed => 'Некоторые покупки не удалось выполнить';

  @override
  String numItemsAreNotPurchasable(int numItems) {
    return '$numItems товар(ов) недоступны для покупки';
  }

  @override
  String get purchaseComplete => 'Покупка завершена';

  @override
  String get confirmPurchase => 'Подтвердить покупку';

  @override
  String confirmPurchaseMessage(String itemsText) {
    return 'Вы уверены, что хотите приобрести $itemsText?';
  }

  @override
  String get totalPrice => 'Итоговая стоимость:';

  @override
  String get purchaseResults => 'Результаты покупки';

  @override
  String successfullyPurchased(int successItems) {
    return 'Успешно приобретено: $successItems товар(ов)';
  }

  @override
  String alreadyOwnded(int alreadyOwnedItems) {
    return 'Уже приобретено: $alreadyOwnedItems товар(ов)';
  }

  @override
  String numItemsNotPurchasable(int notPurchasableItems) {
    return 'Недоступно для покупки: $notPurchasableItems товар(ов)';
  }

  @override
  String numItemsInsufficientFunds(int insufficientFundsItems) {
    return 'Недостаточно средств: $insufficientFundsItems товар(ов)';
  }

  @override
  String numItemsFailed(int failedItemsCount) {
    return 'Неудачные покупки: $failedItemsCount товар(ов)';
  }

  @override
  String get clearCart => 'Очистить корзину';

  @override
  String get clearCartConfirmation =>
      'Вы уверены, что хотите удалить все товары из корзины?';

  @override
  String cartTitleNum(int count) {
    return 'Корзина ($count)';
  }

  @override
  String get cartisEmpty => 'Ваша корзина пуста';

  @override
  String get cartEmptyDescription =>
      'Нажмите на значок корзины на странице деталей любого товара, чтобы добавить его в корзину и приобрести';

  @override
  String get purchasingInProgress => 'Выполняется покупка...';

  @override
  String purchaseAllnum(int count) {
    return 'Купить всё ($count)';
  }

  @override
  String get nowNewdlcFound => 'Новые DLC не найдены';

  @override
  String get nowNewDlcFoundDescription =>
      'Все DLC уже присутствуют в базе данных приложения';

  @override
  String get noDlcFound => 'DLC не найдены';

  @override
  String get noDlcAvailable => 'Контент DLC недоступен';

  @override
  String get openDlcsList => 'Открыть список DLC';

  @override
  String get appUpdates => 'Обновления приложения';

  @override
  String get appUpdatesDescription =>
      'Посмотрите, что нового появилось в последних версиях приложения';

  @override
  String get socials => 'Соцсети';

  @override
  String get selectApp => 'Выбрать приложение';

  @override
  String get noAppsFound => 'Приложения не найдены';

  @override
  String get errorLoadingDlcs => 'Ошибка загрузки DLC';

  @override
  String get dlcs => 'DLC';

  @override
  String errorSavingKeys(String error) {
    return 'Ошибка сохранения ключей: $error';
  }

  @override
  String errorOpeningAuthPage(String error) {
    return 'Ошибка открытия страницы аутентификации: $error';
  }

  @override
  String get gettingEntityToken => 'Получение токена доступа...';

  @override
  String get loadingMinecoinBalance => 'Загрузка баланса Minecoin...';

  @override
  String get completeAuthFirst =>
      'Пожалуйста, сначала завершите аутентификацию';

  @override
  String get sessionExpired => 'Сессия истекла. Пожалуйста, попробуйте снова.';

  @override
  String get accessDenied =>
      'Доступ запрещен. Пожалуйста, пройдите аутентификацию повторно.';

  @override
  String get connectionTimeout =>
      'Тайм-аут соединения. Пожалуйста, проверьте интернет и попробуйте снова.';

  @override
  String get serverError =>
      'Ошибка сервера. Пожалуйста, попробуйте снова через несколько минут.';

  @override
  String get backToSettings => 'Назад в настройки';

  @override
  String errorInitializingCart(String error) {
    return 'Ошибка инициализации корзины: $error';
  }

  @override
  String errorLoadingCartItems(String error) {
    return 'Ошибка загрузки товаров в корзине: $error';
  }

  @override
  String failedLoadMoreItems(String error) {
    return 'Не удалось загрузить больше элементов: $error';
  }

  @override
  String errorSavingLog(String error) {
    return 'Ошибка сохранения лога: $error';
  }

  @override
  String get failedToDeleteFile => 'Не удалось удалить файл';

  @override
  String failedToShareFile(String error) {
    return 'Не удалось поделиться файлом: $error';
  }

  @override
  String get personaWarning =>
      'Предметы Гардероба (Persona) не могут быть импортированы в игру (например, эмоции, косметика и плащи)';

  @override
  String get initializingMcDec => 'Инициализация McDec...';

  @override
  String failedToSaveKeys(String error) {
    return 'Не удалось сохранить ключи: $error';
  }

  @override
  String get itemDetailsTitle => 'Детали предмета';

  @override
  String byCreator(String creator) {
    return 'от $creator';
  }

  @override
  String get couldNotLoadSocials =>
      'Не удалось загрузить ссылки на соцсети, используются стандартные';

  @override
  String get sdCardExternalStorage => 'SD-карта / Внешний накопитель';

  @override
  String get customLocation => 'Пользовательское расположение';

  @override
  String couldNotOpenLink(String error) {
    return 'Не удалось открыть ссылку: $error';
  }

  @override
  String get minecraftPackage => 'Пакет Minecraft';

  @override
  String get freeDroidWarnMessage =>
      'Google объявила, что начиная с 2026/2027 года все приложения на сертифицированных устройствах Android будут требовать от разработчиков предоставления своих личных данных для идентификации напрямую Google. Так как разработчики этого приложения не согласны с этим требованием, приложение перестанет работать на сертифицированных устройствах Android после этого времени.';

  @override
  String get freeDroidWarnDetails => 'Подробнее';

  @override
  String get freeDroidWarnSolution => 'Решение';

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
