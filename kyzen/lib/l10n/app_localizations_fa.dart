// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get home => 'خانه';

  @override
  String get downloads => 'دانلود‌ها';

  @override
  String get settings => 'تنظیمات';

  @override
  String get selectLanguage => 'انتخاب زبان';

  @override
  String get language => 'زبان';

  @override
  String get download => 'دانلودها';

  @override
  String get hintText => 'جستجو';

  @override
  String get default1 => 'پیش فرض';

  @override
  String get creators => 'سازندگان';

  @override
  String get checkingKeys => 'بررسی کلیدها';

  @override
  String get apiLogin => 'ورود به ای پی آی';

  @override
  String addedNewKeys(int keyCount) {
    return '$keyCount کلید جدید اضافه شد';
  }

  @override
  String get noResult => 'هیچ نتیجه ای یافت نشد';

  @override
  String get open => 'باز کردن';

  @override
  String get clear => 'پاک کردن';

  @override
  String get retry => 'تلاش مجدد';

  @override
  String get ok => 'OK';

  @override
  String queuePosition(int count) {
    return 'در صف (شماره #$count)';
  }

  @override
  String queuePosition2(int count) {
    return 'در صف #$count';
  }

  @override
  String imageSaved(String filePath) {
    return 'تصویر در $filePath ذخیره شد';
  }

  @override
  String errorDownloadingImage(String error) {
    return 'مشکلی درحال دانلود تصویر پیش آمد:$error';
  }

  @override
  String get changelog => 'تغییرات انجام شده';

  @override
  String get downloaded => 'دانلود شد‌‌ها';

  @override
  String get retryDownload => 'تلاش مجدد برای دانلود';

  @override
  String get downloadImage => 'دانلود تصویر';

  @override
  String get downloadImageQuestion => 'میخوای این تصویر رو دانلود کنی؟';

  @override
  String get cancel => 'لغو';

  @override
  String get trailer => 'تماشای تریلر';

  @override
  String trailerError(String error) {
    return 'نمیتوان تریلر را باز کرد: $error';
  }

  @override
  String get appearance => 'ظاهر';

  @override
  String get darkMode => 'حالت شب';

  @override
  String get darkEnabled => 'حالت شب فعال شد';

  @override
  String get lightEnabled => 'حالت روز';

  @override
  String get colorScheme => 'طرح رنگ';

  @override
  String get defaultColor => 'پیش فرض';

  @override
  String get defaultPurple => 'پیش فرض(بنفش)';

  @override
  String get colorSchemeBlue => 'آبی';

  @override
  String get colorSchemeGreen => 'سبز';

  @override
  String get colorSchemeOrange => 'نارنجی';

  @override
  String get colorSchemeRed => 'قرمز';

  @override
  String get colorSchemeTeal => 'فیروزه‌ای';

  @override
  String get colorSchemePink => 'صورتی';

  @override
  String get colorSchemeLime => 'سبز لیمویی';

  @override
  String get filters => 'فیلترها';

  @override
  String get filter => 'فیلتر:';

  @override
  String get showSkins => 'نشان دادن اسکین ها';

  @override
  String get keys => 'کلیدها';

  @override
  String get autoUpdate => 'بروزرسانی خودکار';

  @override
  String get customDb => 'دیتابیس سفارشی';

  @override
  String get accountLogin => 'وارد شدن به حساب کاربری';

  @override
  String get extras => 'موارد اضافی';

  @override
  String get cache => 'حافظه پنهان';

  @override
  String cacheCleared(String size) {
    return '$size مگ از حافظه پنهان خالی شد';
  }

  @override
  String get faq => 'سوال های پرسیده شده';

  @override
  String get faqUppercase => 'سوال های پرسیده شده';

  @override
  String get terminal => 'ترمینال';

  @override
  String get faqQuestion1 => 'لطفا کلیدهای این پک هارو اضافه کنید!';

  @override
  String get faqQuestion2 => 'کی قراره کلیدها بروزرسانی بشوند ؟';

  @override
  String get faqQuestion3 => 'فرق رمزگذاری شده و رمزگشایی شده چیه ؟';

  @override
  String get faqQuestion4 => 'کجا میتونم پک‌های دانلود شده ام رو پیدا کنم؟';

  @override
  String get faqQuestion5 => 'keys.tsv چیه؟';

  @override
  String get faqQuestion6 => 'چطور می‌تونم از آیتم‌های شخصیت استفاده کنم؟';

  @override
  String get faqQuestion7 => 'چرا بعضی بسته‌های اسکین خراب به نظر می‌رسند؟';

  @override
  String get faqQuestion8 => 'هدف صفحه \"ورود به حساب کاربری\" چیست؟';

  @override
  String get faqQuestion9 => 'What does the checkmark mean?';

  @override
  String get faqAnswer1 =>
      'فرایند گرفتن کلید جادو جنبل نیست، باید یک نفر پک رو بخره و کلیدهارو با ما به اشتراک بزاره، اگر کسی پک رو بخره هیچ کلید رمزگشایی شده ای وجود نخواهد داشت، هیچ راه دیگه ای هم برای به دست آوردن کلید ها وجود نداره پس لطفاً صبور باشید یا پک رو بخرید';

  @override
  String get faqAnswer2 => 'موقعی که تصمیم بگیریم';

  @override
  String get faqAnswer3 =>
      'رمزگذاری شده یعنی فایل به کلمات درهم تبدیل شده که شبیه به هذیونه، هیچکس نمیتونه بخونش بدون یک کلید خاص ، محتوای رمزگذاری شده ماینکرفت غیرقابل استفاده هست ، رمزگشایی شده یعنی تبدیل اون کلمات درهم به محتوای دست نخورده ، حالا میتونید با محتوای رمزگشایی شده از این محتواها استفاده کنید';

  @override
  String get faqAnswer4 =>
      'شما میتونید پک هارا اینجا پیدا کنید\nدانلود/تولکوین';

  @override
  String get faqAnswer5 =>
      'یک فایلی هست که «یو یو آی دی» پک ها به همراه کلید رمزگشایی آنها ذخیره میشه، بدون کلیدهای رمزگشایی شده پک‌های دانلود شده غیرقابل استفاده خواهند بود';

  @override
  String get faqAnswer6 =>
      'تو نمی‌تونی. روش‌هایی وجود دارن، اما با توجه به پیچیدگی انجام کار، عملی نیست.';

  @override
  String get faqAnswer7 =>
      'بعضی بسته‌های اسکین (به‌خصوص همکاری‌های فرنچایز) از هندسه سفارشی استفاده می‌کنن که ماینکرفت اجازه استفاده عادی از اون رو نمی‌ده مگر اینکه بسته اسکین رو بخری.  \nمی‌تونی بررسی کنی که آیا یک بسته اسکین از هندسه سفارشی استفاده می‌کنه یا نه، با نگاه کردن به وجود فایل geometry.json داخل بسته.  \nیادت باشه این مشکل هیچ ارتباطی با ابزار نداره.';

  @override
  String get faqAnswer8 =>
      'صفحه ورود به حساب کاربری به شما اجازه می‌دهد با حساب مایکروسافت خود احراز هویت کنید تا کلیدهای ماینکرفت‌تان مستقیماً از موجودی‌تان بارگذاری شوند. این قابلیت زمانی مفید است که Kyzen در حال حاضر برای یک DLC خاص کلیدی نداشته باشد اما شما آن را در حساب خود داشته باشید؛ وقتی کلیدها بارگذاری شوند، آن DLC برای دانلود در دسترس قرار می‌گیرد. توجه داشته باشید که کلیدها به‌طور خودکار در پایگاه داده ما آپلود می‌شوند و بعداً با پایگاه داده اصلی کلیدهای Kyzen ادغام خواهند شد تا همه بتوانند از DLC جدید لذت ببرند، پس لطفاً اگر می‌خواهید مشارکت کنید از این ویژگی استفاده کنید.';

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
  String get fileDeleted => 'فایل حذف شد';

  @override
  String get storedFiles => 'فایل های ذخیره شده';

  @override
  String get refreshFiles => 'رفرش/تازه کردن فایل ها';

  @override
  String get deleteFile => 'حذف فایل';

  @override
  String deleteFileConfirmation(String fileName) {
    return 'مطمعنی که میخوای $fileName رو حذف کنی؟';
  }

  @override
  String get cancelUppercase => 'لغو';

  @override
  String get deleteUppercase => 'حذف';

  @override
  String get currentDownload => 'دانلود فعلی';

  @override
  String get noActiveDownloads => 'هیچ دانلود فعالی وجود ندارد';

  @override
  String get completedDownloads => 'دانلود های تکمیل شده';

  @override
  String get clearAll => 'پاک کردن همه';

  @override
  String get importToMc => 'وارد کردن به ماینکرفت';

  @override
  String get openFileinExplorer => 'باز کردن در فایل اکسپلورر';

  @override
  String get shareFile => 'به اشتراک گذاشتن فایل';

  @override
  String get debugTerminal => 'مشکل زدایی ترمینال';

  @override
  String get clearLogs => 'پاک کردن لاگها';

  @override
  String get noLogs => 'هنوز هیچ لاگی ثبت نشده...';

  @override
  String get saveLogs => 'Save logs';

  @override
  String logsSaved(String filePath) {
    return 'Logs saved to $filePath';
  }

  @override
  String get selectingFile => 'انتخاب کردن فایل...';

  @override
  String get processingFile => 'پردازش فایل...';

  @override
  String get fileProcessed => 'فایل با موفقیت پردازش شد';

  @override
  String get noFileSelected => 'هیچ فایلی انتخاب نشده';

  @override
  String customKeysLoaded(int count) {
    return '$count کلید سفارشی بارگذاری شد';
  }

  @override
  String get noCustomKeysLoaded => 'هیچ کلید سفارشی‌ای بارگذاری نشد';

  @override
  String get importFileFormat => 'یک فایل با فرمت UUID=KEY وارد کنید';

  @override
  String creatorItemsWithType(String contentType) {
    return '$contentType موارد';
  }

  @override
  String creatorItemsWithTypeAndCount(String contentType, int count) {
    return '$contentType موارد ($count)';
  }

  @override
  String get creatorItemsDefault => 'موارد سازنده';

  @override
  String get noItemCreator => 'این سازنده هیچ محتوایی ندارد';

  @override
  String get noStatistic => 'هیچ آماری در دسترس نیست';

  @override
  String get failedLoadStatistic => 'بارگذاری آمار ناموفق بود';

  @override
  String get noResultsFound => 'هیچ نتیجه ای یافت نشد';

  @override
  String get microsoftAuth => 'احراز هویت مایکروسافت';

  @override
  String get exchangingToken => 'معادله کردن کد احراز هویت برای توکن';

  @override
  String authenticationFailed(String error) {
    return 'احراز هویت ناموفق بود: $error';
  }

  @override
  String get authenticationSuccessful => 'احراز هویت موفق آمیز بود!';

  @override
  String failedToExchangeToken(String error) {
    return 'معادله کد برای توکن با مشکلی مواجه شد : $error';
  }

  @override
  String get noAuthorizationCodeReceived => 'هیچ کد احراز هویتی دریافت نشد';

  @override
  String get noNewKeysCopy => 'هیچ کلید جدیدی برای کپی پیدا نشد';

  @override
  String get keysCopyClipboard => 'کلیدها کپی شدند به کلیپ بورد';

  @override
  String get noNewKeysShare => 'هیچ کلید جدیدی برای به اشتراک گذاری پیدا نشد';

  @override
  String get keysShared => 'کلیدها با موفقیت به اشتراک گذاشته شدند';

  @override
  String get authCheck => 'درحال بررسی احراز هویت موجود';

  @override
  String get alreadyAuth => 'از قبل احراز هویت شده آید!';

  @override
  String get readyAuth => 'آماده برای احراز هویت';

  @override
  String get authURL => 'احراز هویت با لینک';

  @override
  String get completeAuthButton => 'Complete Authentication';

  @override
  String get openAuthPageButton => 'Open Auth Page';

  @override
  String get completeAuth =>
      'احراز هویت را درون مرورگر خود کامل کنید، بعد از آن به برنامه بازگردانده میشوید';

  @override
  String get copyUrl => 'Copy URL';

  @override
  String get authPageFail => 'نمیتوان صفحه احراز هویت را باز کرد';

  @override
  String get logout => 'درحال خارج شدن از حساب';

  @override
  String get logoutOk => 'از حساب با موفقیت خارج شدید';

  @override
  String get usingCachedSession => 'استفاده از جلسه ذخیره شده...';

  @override
  String get loadingMinecraftKeys => 'بارگیری کلیدهای ماینکرفت...';

  @override
  String get requestingXboxLiveToken =>
      'درخواست کردن برای توکن ایکس باکس لایو...';

  @override
  String get loggingInToPlayFab => 'درحال وارد شدن به پلی‌فب...';

  @override
  String get gettingUserInformation => 'درحال گرفتن اطلاعات کاربر';

  @override
  String get startingMinecraftSession => 'درحال شروع کردن جلسه ماینکرفت';

  @override
  String get loadingMinecraftInventory => 'درحال پردازش ایونتوری ماینکرفت';

  @override
  String successfullyLoadedKeys(int keyCount) {
    return '$keyCount کلید با موفقیت پردازش شد';
  }

  @override
  String errorLoadingKeys(String error) {
    return 'مشکلی درحال پردازش کلیدها پیش آمد: $error';
  }

  @override
  String get copyClipboard => 'کپی شد به کلیپ بورد';

  @override
  String get authOk => 'احراز هویت شده';

  @override
  String get authNotOk => 'احراز هویت نشده';

  @override
  String get urlAuth => 'لینک احراز هویت';

  @override
  String get loadedKeys => 'کلیدهای بارگذاری شده';

  @override
  String get exportNewKeys => 'خروجی گرفتن از کلید های جدید';

  @override
  String get loadKeysButton => 'بارگذاری کلیدها';

  @override
  String get logoutButton => 'خارج شدن از حساب';

  @override
  String get startAuthButton => 'شروع احراز هویت';

  @override
  String get greetings => 'سلام رفیق ';

  @override
  String get copy => 'کپی';

  @override
  String get save => 'ذخیره';

  @override
  String get share => 'اشتراک گذاری';

  @override
  String get keysSaved => 'کلیدها با موفقیت ذخیره شدند';

  @override
  String get startingDownload => 'درحال شروع دانلود';

  @override
  String get downloadsCompleted => 'دانلود تکمیل شد';

  @override
  String get completed => 'تکمیل شد';

  @override
  String get downloadFailed => 'دانلود ناموفق بود';

  @override
  String get downloading => 'درحال دانلود';

  @override
  String get processing => 'درحال پردازش';

  @override
  String get extractingZipFile => 'استخراج فایل زیپ';

  @override
  String get decryptingContents => 'رمزگشایی محتوا‌ها';

  @override
  String get compressingPack => 'فشرده سازی پک';

  @override
  String get cleaningUp => 'درحال پاک کردن...';

  @override
  String get showAll => 'نشان دادن همه';

  @override
  String get onlyAvailable => 'فقط آنهایی که موجودند';

  @override
  String get onlyNotAvailable => 'فقط آنهایی که موجود نیستند';

  @override
  String get customColor => 'رنگ سفارشی';

  @override
  String get changeCustomColor => 'برای تغییر رنگ سفارشی خود ضربه بزن.';

  @override
  String get createCustomColor => 'طرح رنگی خودت را بساز.';

  @override
  String get pickColor => 'انتخاب رنگ';

  @override
  String get selectColor => 'انتخاب';

  @override
  String get images => 'تصاویر';

  @override
  String get saveToPng => 'ذخیره به شکل PNG';

  @override
  String get saveToGallery => 'ذخیره در گالری';

  @override
  String get compression => 'فشرده سازی';

  @override
  String get normalCompression => 'فشرده سازی نرمال';

  @override
  String get noCompression => 'بدون فشرده سازی';

  @override
  String get copyUUID => 'کپی UUID';

  @override
  String get openInMinecraft => 'باز کردن در ماینکرافت';

  @override
  String get creator => 'سازنده';

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
  String get newUpdate => 'آپدیت جدیپ';

  @override
  String get newDlc => 'DLC جدید';

  @override
  String get hidden => 'مخفی ها';

  @override
  String get persona => 'شخصیت';

  @override
  String get skins => 'اسکین‌ها';

  @override
  String get mashups => 'مش آپ';

  @override
  String get worlds => 'جهان ها';

  @override
  String get textures => 'تکسچرها';

  @override
  String get addons => 'ادان ها';

  @override
  String get capes => 'Capes';

  @override
  String get vibrantVisuals => 'ویبرانت ویژوال';

  @override
  String get favorites => 'مورد علاقه‌ها';

  @override
  String get unfiltered => 'بدون فیلتر';

  @override
  String get sorting => 'مرتب سازی';

  @override
  String get type => 'نوع';

  @override
  String get newFilter => 'جدید';

  @override
  String get other => 'دیگر';

  @override
  String get newest => 'جدیدترین';

  @override
  String get oldest => 'قدیمی ترین';

  @override
  String get mostRated => 'بیشترین امتیاز';

  @override
  String get leastRated => 'کمترین امتیاز';

  @override
  String get menu => 'منو';

  @override
  String imageSavedToGallery(String filePath) {
    return 'تصویر در گالری ذخیره شد : $filePath';
  }

  @override
  String get vibrantVisualEnhanced => 'ارتقای ویبرانت ویژوال';

  @override
  String get uuidCopied => 'UUID در کلیپ بورد کپی شد';

  @override
  String get scrollRight => 'اسکرول به راست';

  @override
  String get scrollLeft => 'اسکرول به چپ';

  @override
  String get previousImage => 'تصویر قبلی';

  @override
  String get nextImage => 'تصویر بعدی';

  @override
  String get favoriteEmpty => 'لیست مورد علاقه‌ها خالی است';

  @override
  String get favoriteDescription =>
      'روی آیکون قلب در صفحه جزئیات هر آیتم ضربه بزن تا به علاقه‌مندی‌ها اضافه شود و مجموعه‌ات ساخته شود.';

  @override
  String get removeFromFavorites => 'حذف از علاقمندی ها';

  @override
  String get addToFavorites => 'افزودن به علاقمندی ها';

  @override
  String get addedToFavorites => 'به علاقمندی ها اضافه شد';

  @override
  String get removedFromFavorites => 'از علاقمندی ها حذف شد';

  @override
  String get noNewKeysFoundToSave => 'کلیدی برای ذخیره پیدا نشد';

  @override
  String get keysSavedSuccessfully =>
      'کلید ها با موفقیت در پوشه Kyzen ذخیره شدند';

  @override
  String get entitlementKeys => 'کلیدهای مالکیت';

  @override
  String get searchBoughContent => 'جستجوی محتوای خریداری‌شده‌ی ماینکرافت';

  @override
  String get saveKeys => 'ذخیره کلید ها';

  @override
  String get refresh => 'تازه سازی';

  @override
  String get searchKeys => 'جستجوی کلید ها';

  @override
  String get loadSkinPersona => 'بارگذاری اسکین پک، آیتم شخصیت';

  @override
  String get descriptionSkinPersona =>
      'اسکین‌پک و آیتم شخصیت را در فهرست قرار بده.';

  @override
  String get loadOnlyNewKeys => 'فقط بارگذاری کلیدهای جدید';

  @override
  String get descriptionLoadOnlyNewKeys =>
      'بارگذاری فقط محتوایی که در پایگاه داده کلیدهای اپلیکیشن وجود ندارد.';

  @override
  String get descriptionExportNewKeys =>
      'این‌که «ذخیره کلیدها» فقط کلیدهای جدید را صادر کند یا نه.';

  @override
  String processedEntitlementKeys(int countFiles, int countKeys) {
    return 'با موفقیت پردازش شد ($countFiles فایل، $countKeys کلید)';
  }

  @override
  String get noResultsYet => 'هنوز هیچ نتیجه‌ای یافت نشده';

  @override
  String get clickSearchKeysToLoadContent =>
      'روی «جستجوی کلیدها» کلیک کن تا محتوایت بارگذاری شود.';

  @override
  String get tryadifferentSearch => 'عبارت جستجوی دیگری را امتحان کن.';

  @override
  String get minecraftNotInstalled =>
      'هیچ مسیر نصب معتبر ماینکرافت پیدا نشد. لطفاً مطمئن شوید که Minecraft Bedrock Edition (نسخه UWP یا GDK) نصب شده و حداقل یک بار اجرا شده باشد.';

  @override
  String get processingError => 'خطاهای پردازش';

  @override
  String get dismiss => 'رد کردن';

  @override
  String get failedFiles => 'فایل‌های ناموفق:';

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
