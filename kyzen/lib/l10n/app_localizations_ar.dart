// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get home => 'الصفحة الرئيسية';

  @override
  String get downloads => 'التحميلات';

  @override
  String get settings => 'الإعدادات';

  @override
  String get selectLanguage => 'اختر اللغة';

  @override
  String get language => 'اللغة';

  @override
  String get download => 'تحميل';

  @override
  String get hintText => 'بحث...';

  @override
  String get default1 => 'افتراضي';

  @override
  String get creators => 'مصممين';

  @override
  String get checkingKeys => 'جاري تفحص الأكواد';

  @override
  String get apiLogin => 'جاري تسجيل الدخول';

  @override
  String addedNewKeys(int keyCount) {
    return 'تمت إضافة $keyCount أكواد جديدة';
  }

  @override
  String get noResult => 'لم يتم العثور على شيء';

  @override
  String get open => 'فتح';

  @override
  String get clear => 'مسح';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get ok => 'موافق';

  @override
  String queuePosition(int count) {
    return 'في قائمة الانتظار (الترتيب #$count)';
  }

  @override
  String queuePosition2(int count) {
    return 'في قائمة الانتظار #$count)';
  }

  @override
  String imageSaved(String filePath) {
    return 'تم حفظ الصورة في $filePath';
  }

  @override
  String errorDownloadingImage(String error) {
    return 'خطأ في تحميل الصورة: $error';
  }

  @override
  String get changelog => 'سجل التغييرات';

  @override
  String get downloaded => 'تم التحميل';

  @override
  String get retryDownload => 'إعادة التحميل';

  @override
  String get downloadImage => 'تحميل الصورة';

  @override
  String get downloadImageQuestion => 'تحميل هذه الصورة؟';

  @override
  String get cancel => 'إلغاء';

  @override
  String get trailer => 'مشاهدة الإعلان';

  @override
  String trailerError(String error) {
    return 'خطأ في تشغيل الإعلان: $error';
  }

  @override
  String get appearance => 'المظهر';

  @override
  String get darkMode => 'الوضع الداكن';

  @override
  String get darkEnabled => 'الوضع الداكن مفعل';

  @override
  String get lightEnabled => 'الوضع الفاتح مفعل';

  @override
  String get colorScheme => 'مظهر الألوان';

  @override
  String get defaultColor => 'افتراضي';

  @override
  String get defaultPurple => 'افتراضي (بنفسجي)';

  @override
  String get colorSchemeBlue => 'أزرق';

  @override
  String get colorSchemeGreen => 'أخضر';

  @override
  String get colorSchemeOrange => 'برتقالي';

  @override
  String get colorSchemeRed => 'أحمر';

  @override
  String get colorSchemeTeal => 'أخضر مزرق';

  @override
  String get colorSchemePink => 'زهري';

  @override
  String get colorSchemeLime => 'ليموني';

  @override
  String get filters => 'الفلاتر';

  @override
  String get filter => 'الفلتر:';

  @override
  String get showSkins => 'إظهار السكنات';

  @override
  String get keys => 'الأكواد';

  @override
  String get autoUpdate => 'التحديث التلقائي';

  @override
  String get customDb => 'أكواد مخصصة';

  @override
  String get accountLogin => 'تسجيل دخول الحساب';

  @override
  String get extras => 'أخرى';

  @override
  String get cache => 'التخزين المؤقت';

  @override
  String cacheCleared(String size) {
    return 'تم إفراغ $size MB من التخزين المؤقت';
  }

  @override
  String get faq => 'حول';

  @override
  String get faqUppercase => 'حول';

  @override
  String get terminal => 'موجه الأوامر';

  @override
  String get faqQuestion1 => 'الرجاء إضافة الأكواد لهذه وتلك الملفات!';

  @override
  String get faqQuestion2 => 'متى سيتم تحديث الأكواد؟';

  @override
  String get faqQuestion3 => 'ما الفرق بين المشفرة وغير المشفرة';

  @override
  String get faqQuestion4 => 'أين أستطيع أن أجد الملفات المحملة؟';

  @override
  String get faqQuestion5 => 'ما هو keys.tsv؟';

  @override
  String get faqQuestion6 => 'كيف يمكنني أن أستخدم عناصر الشخصيات (persona)؟';

  @override
  String get faqQuestion7 => 'لماذا بعض حزم السكنات تبدو غير صالحة؟';

  @override
  String get faqQuestion8 => 'ما هو الهدف من صفحة \"تسجيل الدخول بالحساب\"؟';

  @override
  String get faqQuestion9 => 'ما الذي تعنيه علامة \"صح\"؟';

  @override
  String get faqAnswer1 =>
      'عملية اقتناء الأكواد ليست سحر: شخص ما لا يزال عليه أن يشتري الملفات ويشارك الأكواد معنا في المقام الأول. من غير الممكن اقتناء تلك الملفات بأي وسيلة أخرى. انتظر بصبر أو اشتري الملفات';

  @override
  String get faqAnswer2 => 'عندما نقرر هذا.';

  @override
  String get faqAnswer3 =>
      'التشفير يعني تحويل الملف إلى كلمات مخربطة تبدو كالقمامة. لا أحد يستطيع قراءتها بدون كود مخصص. ملفات ماين كرافت المشفرة لا يمكن استخدامها. فك التشفير يعني استخدام الكود المخصص لتحويل القمامة إلى محتواها الأصلي. الآن يمكنك استخدام ملفات ماين كرافت هذه.';

  @override
  String get faqAnswer4 => 'تستطيع العثور على الملفات هنا Download/Kyzen';

  @override
  String get faqAnswer5 =>
      'هو ملف يخزن عليه عناوين الملفات مع أكوادها المخصصة. بدون تلك الأكواد الملفات المحملة لا يمكن استخدامها';

  @override
  String get faqAnswer6 =>
      'أنت لا تستطيع،هناك بعض الطرق لفعلها لكن بصعوبة وغير ملائمة.';

  @override
  String get faqAnswer7 =>
      'بعض حزم السكنات (خصوصاً التعاونات) تستخدم مجسمات مخصصة التي لا تسمح ماين كرافت باستخدامها بشكل طبيعي حتى تقوم بشراء حزمة السكنات تلك. يمكنك التحقق إذا حزمة السكنات (Skin Pack) تستخدم مجسم مخصص بالتفحص إذا كان ملف \"geometry.json\" موجود في الحزمة أم لا. تذكر أن هذه المشكلة ليس لها علاقة بهذه الأداة بأي شكل من الأشكال.';

  @override
  String get faqAnswer8 =>
      'صفحة تسجيل الدخول تسمح لك بالتحقق بحسابك الخاص بMicrosoft من أجل حفظ أكواد الباكات التي اشتريتها في ماين كرافت. هذا مفيد عندما Kyzen لا يملك حالياً أي كود لDLC معينة لكنك تملك هذا الDLC في حسابك وعندما يتم تحميل الأكواد بنجاح سوف يكون الDlC متاح للتحميل. ملاحظة إن الأكواد تحفظ بشكل تلقائي في قاعدة بياناتنا والتي لاحقاً سيتم دمجها مع قاعدة الأكواد الأساسية لKyzen حتى يتمكن الجميع من الاستمتاع بهذه DLC لهذا رجاءً استخدم هذه الميزة إذا كنت ترغب في المساهمة.';

  @override
  String get faqAnswer9Checkmark => 'كود فك التشفير لهذه الحزمة متاح.';

  @override
  String get faqAnswer9NoCheckmark =>
      'التطبيق لا يملك اي كود فك تشفير خاص بهذه الحزمة حاليا.';

  @override
  String get faqAnswer9ExtraInfo => 'الأكواد ضرورية لفك تشفير الحزم والإضافات.';

  @override
  String get faqQuestionDownload => 'لماذا زر التحميل غير متاح؟';

  @override
  String get faqAnswerDownload =>
      'كود فك التشفير الخاص بهذه الحزمة غير متاح، انتظر بصبر او قم بشرائه.';

  @override
  String get faqQuestionKey => 'كيف أحصل على كود فك التشفير؟';

  @override
  String get faqAnswerKey =>
      'قم بشراء الحزمة في حسابك ثم اذهب إلى الإعدادات > تسجيل دخول الحساب > اضغط \'بدء التحقق\' > اضغط \'تحميل الأكواد\'، والآن اضغط \'مشاركة\' وشارك ملفات الأكواد إلى محادثة Bluecoin، سيتم إضافة الأكواد إلى قاعدة بيانات التطبيق. إذا لا يمكنك مشاركة ملفات الأكواد إلى المحادثة، لا تقلق، سيتم رفع الأكواد تلقائيا إلى قاعدة البيانات.';

  @override
  String get faqMoreHelp => 'المزيد من المساعدة';

  @override
  String get faqNotAdlc => 'ليس حزمة';

  @override
  String get faqNotAdlcDescription => 'هذا العنصر ليس حزمة.';

  @override
  String get faqServerContent => 'محتويات الخادم';

  @override
  String get faqServerContentDescription =>
      'هذا العنصر هو محتوى حصري لخادم معين ولا يمكن تحميله مباشرة.';

  @override
  String get fileDeleted => 'تم حذف الملف';

  @override
  String get storedFiles => 'الملفات المخزنة';

  @override
  String get refreshFiles => 'إعادة التحقق من الملفات';

  @override
  String get deleteFile => 'حذف الملف';

  @override
  String deleteFileConfirmation(String fileName) {
    return 'هل أنت متأكد أنك تريد حذف $fileName؟';
  }

  @override
  String get cancelUppercase => 'إلغاء';

  @override
  String get deleteUppercase => 'حذف';

  @override
  String get currentDownload => 'التحميل الجاري حاليا';

  @override
  String get noActiveDownloads => 'لا يوجد تحميلات نشطة';

  @override
  String get completedDownloads => 'التحميلات المكتملة';

  @override
  String get clearAll => 'مسح الكل';

  @override
  String get importToMc => 'استخراج إلى ماين كرافت';

  @override
  String get openFileinExplorer => 'فتح في مستكشف الملفات';

  @override
  String get shareFile => 'مشاركة الملف';

  @override
  String get debugTerminal => 'موجه الأوامر المخصص';

  @override
  String get clearLogs => 'مسح السجلات';

  @override
  String get noLogs => 'لا يوجد سجلات...';

  @override
  String get saveLogs => 'حفظ السجلات';

  @override
  String logsSaved(String filePath) {
    return 'تم حفظ السجلات في $filePath';
  }

  @override
  String get selectingFile => 'اختيار الملف...';

  @override
  String get processingFile => 'معالجة الملف...';

  @override
  String get fileProcessed => 'تمت معالجة الملف بنجاح!';

  @override
  String get noFileSelected => 'لم يتم اختيار أي ملف';

  @override
  String customKeysLoaded(int count) {
    return '$count الأكواد المخصصة التي تم استخراجها';
  }

  @override
  String get noCustomKeysLoaded => 'لم يتم استخراج أي كود مخصص';

  @override
  String get importFileFormat => 'استخراج ملف بصيغة UUID=KEY';

  @override
  String creatorItemsWithType(String contentType) {
    return '$contentType عناصر';
  }

  @override
  String creatorItemsWithTypeAndCount(String contentType, int count) {
    return '$contentType عناصر ($count)';
  }

  @override
  String get creatorItemsDefault => 'عناصر المصممين';

  @override
  String get noItemCreator => 'هذا المصمم لا يمتلك محتوى';

  @override
  String get noStatistic => 'لا يوجد إحصائيات متوفرة';

  @override
  String get failedLoadStatistic => 'خطأ في عرض الإحصائيات';

  @override
  String get noResultsFound => 'لم يتم العثور على شيء';

  @override
  String get microsoftAuth => 'التحقق الخاص ب مايكروسوفت';

  @override
  String get exchangingToken => 'جاري تبادل كود التحقق...';

  @override
  String authenticationFailed(String error) {
    return 'فشل التحقق: $error';
  }

  @override
  String get authenticationSuccessful => 'تم التحقق بنجاح!';

  @override
  String failedToExchangeToken(String error) {
    return 'فشل في مبادلة كود التحقق: $error';
  }

  @override
  String get noAuthorizationCodeReceived => 'لم يتم تلقي أي كود تحقق';

  @override
  String get noNewKeysCopy => 'لم يتم العثور على أكواد جديدة للنسخ';

  @override
  String get keysCopyClipboard => 'تم نسخ الأكواد إلى الحافظة!';

  @override
  String get noNewKeysShare => 'لم يتم العثور على أكواد جديدة للمشاركة';

  @override
  String get keysShared => 'تمت مشاركة الأكواد بنجاح!';

  @override
  String get authCheck => 'جاري تفحص التحقق الحالي...';

  @override
  String get alreadyAuth => 'تم التحقق بالفعل!';

  @override
  String get readyAuth => 'جاهز للتحقق';

  @override
  String get authURL => 'التحقق باستخدام رابط خارجي';

  @override
  String get completeAuthButton => 'إكمال التحقق';

  @override
  String get openAuthPageButton => 'فتح صفحة التحقق';

  @override
  String get completeAuth =>
      'أكمل التحقق في متصفحك. سوف يتم إعادة توجيهك إلى التطبيق.';

  @override
  String get copyUrl => 'نسخ الرابط';

  @override
  String get authPageFail => 'لم يتم فتح صفحة التحقق';

  @override
  String get logout => 'جاري تسجيل الخروج...';

  @override
  String get logoutOk => 'تم تسجيل الخروج بنجاح';

  @override
  String get usingCachedSession => 'جاري استخدام جلسة التخزين المؤقت...';

  @override
  String get loadingMinecraftKeys => 'جاري تحميل أكواد ماين كرافت...';

  @override
  String get requestingXboxLiveToken => 'جاري طلب كود Xbox Live...';

  @override
  String get loggingInToPlayFab => 'جاري تسجيل الدخول إلى PlayFab...';

  @override
  String get gettingUserInformation => 'جاري الحصول على معلومات المستخدم...';

  @override
  String get startingMinecraftSession => 'جاري بدء جلسة ماين كرافت...';

  @override
  String get loadingMinecraftInventory => 'جاري تحميل مخزن ماين كرافت';

  @override
  String successfullyLoadedKeys(int keyCount) {
    return 'تم تحميل $keyCount كود بنجاح!';
  }

  @override
  String errorLoadingKeys(String error) {
    return 'خطأ في تحميل الأكواد: $error';
  }

  @override
  String get copyClipboard => 'تم النسخ إلى الحافظة';

  @override
  String get authOk => 'تم التحقق';

  @override
  String get authNotOk => 'لم يتم التحقق';

  @override
  String get urlAuth => 'رابط التحقق';

  @override
  String get loadedKeys => 'الأكواد المحملة';

  @override
  String get exportNewKeys => 'استخراج فقط الأكواد الجديدة';

  @override
  String get loadKeysButton => 'إدخال الأكواد';

  @override
  String get logoutButton => 'تسجيل الخروج';

  @override
  String get startAuthButton => 'بدء التحقق';

  @override
  String get greetings => 'مرحبا';

  @override
  String get copy => 'نسخ';

  @override
  String get save => 'حفظ';

  @override
  String get share => 'مشاركة';

  @override
  String get keysSaved => 'تم حفظ الأكواد بنجاح';

  @override
  String get startingDownload => 'جاري بدء التحميل...';

  @override
  String get downloadsCompleted => 'التحميلات المكتملة';

  @override
  String get completed => 'اكتمل!';

  @override
  String get downloadFailed => 'فشل التحميل';

  @override
  String get downloading => 'جاري التحميل';

  @override
  String get processing => 'جاري المعالجة';

  @override
  String get extractingZipFile => 'جاري استخراج الملف المضغوط...';

  @override
  String get decryptingContents => 'جاري فك تشفير المحتوى...';

  @override
  String get compressingPack => 'جاري ضغط الملف...';

  @override
  String get cleaningUp => 'جاري التنظيف...';

  @override
  String get showAll => 'إظهار الكل';

  @override
  String get onlyAvailable => 'فقط المتاحة';

  @override
  String get onlyNotAvailable => 'فقط غير المتاحة';

  @override
  String get customColor => 'لون مخصص';

  @override
  String get changeCustomColor => 'اضغط لتغيير اللون المخصص';

  @override
  String get createCustomColor => 'اصنع لون المظهر الخاص بك';

  @override
  String get pickColor => 'اختيار لون';

  @override
  String get selectColor => 'اختيار';

  @override
  String get images => 'الصور';

  @override
  String get saveToPng => 'حفظ بصيغة PNG';

  @override
  String get saveToGallery => 'حفظ إلى المعرض';

  @override
  String get compression => 'الضغط';

  @override
  String get normalCompression => 'الضغط العادي';

  @override
  String get noCompression => 'بدون ضغط';

  @override
  String get copyUUID => 'نسخ UUID';

  @override
  String get openInMinecraft => 'فتح في ماين كرافت';

  @override
  String get creator => 'المصمم';

  @override
  String get addToCart => 'إضافة إلى عربة التسوق';

  @override
  String get removeFromCart => 'إزالة من عربة التسوق';

  @override
  String get addedToCart => 'تمت الإضافة إلى عربة التسوق';

  @override
  String get removedFromCart => 'تمت الإزالة من عربة التسوق';

  @override
  String get authRequired => 'يرجى إكمال التحقق من الحساب';

  @override
  String get authRequiredDesc =>
      'أنت بحاجة إلى إنهاء التحقق من الحساب بشكل كامل لرؤية عربة التسوق. الرجاء التحقق من حسابك في صفحة تسجيل الدخول.';

  @override
  String get newUpdate => 'تحديث جديد';

  @override
  String get newDlc => 'حزمة DLC جديدة';

  @override
  String get hidden => 'مخفي';

  @override
  String get persona => 'الشخصيات (Persona)';

  @override
  String get skins => 'السكنات';

  @override
  String get mashups => 'تجميعة (Mashups)';

  @override
  String get worlds => 'العوالم';

  @override
  String get textures => 'المظاهر (Textures)';

  @override
  String get addons => 'الإضافات (Add-Ons)';

  @override
  String get capes => 'رداءات';

  @override
  String get vibrantVisuals => 'تأثيرات بصرية(شادرات)';

  @override
  String get favorites => 'المفضلة';

  @override
  String get unfiltered => 'غير مفلتر';

  @override
  String get sorting => 'ترتيب';

  @override
  String get type => 'النوع';

  @override
  String get newFilter => 'جديد';

  @override
  String get other => 'أخرى';

  @override
  String get newest => 'الأحدث';

  @override
  String get oldest => 'الأقدم';

  @override
  String get mostRated => 'الأعلى تقييماً';

  @override
  String get leastRated => 'الأدنى تقييماً';

  @override
  String get menu => 'القائمة';

  @override
  String imageSavedToGallery(String filePath) {
    return 'تم حفظ الصورة في المعرض:$filePath';
  }

  @override
  String get vibrantVisualEnhanced => 'تأثيرات بصرية محسنة(شادرات)';

  @override
  String get uuidCopied => 'تم نسخ UUID إلى المحفظة';

  @override
  String get scrollRight => 'التصفح لليمين';

  @override
  String get scrollLeft => 'التصفح لليسار';

  @override
  String get previousImage => 'الصورة السابقة';

  @override
  String get nextImage => 'الصورة التالية';

  @override
  String get favoriteEmpty => 'قائمة المفضلة لديك فارغة';

  @override
  String get favoriteDescription =>
      'اضغط على أيقونة القلب في صفحة تفاصيل أي شيء لإضافته إلى قائمتك المفضلة وبناء مجموعتك';

  @override
  String get removeFromFavorites => 'إزالة من المفضلة';

  @override
  String get addToFavorites => 'إضافة إلى المفضلة';

  @override
  String get addedToFavorites => 'تمت الإضافة إلى المفضلة';

  @override
  String get removedFromFavorites => 'تمت الإزالة من المفضلة';

  @override
  String get noNewKeysFoundToSave => 'لم يتم العثور على أكواد لحفظها';

  @override
  String get keysSavedSuccessfully => 'تم حفظ الأكواد بنجاح في مجلد Kyzen.';

  @override
  String get entitlementKeys => 'أكواد الاستحقاق (Entitlement Keys)';

  @override
  String get searchBoughContent => 'البحث عن محتوى ماين كرافت الذي اشتريته.';

  @override
  String get saveKeys => 'حفظ الأكواد';

  @override
  String get refresh => 'إعادة التحميل';

  @override
  String get searchKeys => 'البحث عن الأكواد';

  @override
  String get loadSkinPersona => 'حفظ سكن باك/شخصيات (SkinPack/Persona)';

  @override
  String get descriptionSkinPersona => 'أضف السكن باك والشخصيات على القائمة';

  @override
  String get loadOnlyNewKeys => 'حفظ الأكواد الجديدة فقط';

  @override
  String get descriptionLoadOnlyNewKeys =>
      'حفظ فقط المحتوى الغير معروض في قاعدة بيانات أكواد التطبيق';

  @override
  String get descriptionExportNewKeys =>
      'في حال أنه يجب على \"حفظ الأكواد\" استخراج فقط الأكواد الجديدة';

  @override
  String processedEntitlementKeys(int countFiles, int countKeys) {
    return 'تمت معالجة ($countFiles ملف, $countKeys كود) بنجاح';
  }

  @override
  String get noResultsYet => 'لا نتائج حالياً';

  @override
  String get clickSearchKeysToLoadContent =>
      'اضغط على \"البحث عن الأكواد\" لتحميل وحفظ محتواك';

  @override
  String get tryadifferentSearch => 'جرب مصطلح بحث آخر';

  @override
  String get minecraftNotInstalled =>
      'لم يتم العثور على مسار تثبيت صالح لماين كرافت. الرجاء التأكد أن ماين كرافت نسخة البيدروك (UWP أو GDK) مثبتة لديك وقمت بتشغيليها مرة واحدة على الأقل.';

  @override
  String get processingError => 'معالجة الأخطاء';

  @override
  String get dismiss => 'تجاهل';

  @override
  String get failedFiles => 'الملفات الفاشلة:';

  @override
  String get minecraftFont => 'خط ماين كرافت';

  @override
  String get usingMinecraftFont => 'جارِ استخدام الخط الخاص بماين كرافت';

  @override
  String get usingDefaultFont => 'جارِ استخدام الخط الافتراضي';

  @override
  String get dlcLanguage => 'اللغة الخاصة بالمحتوى ( مابات/مودات )';

  @override
  String get dlcLangInfo => 'معلومات اللغة الخاصة بالمحتوى';

  @override
  String get dlcLangInfoText =>
      'ملاحظة : هنالك بعض المودات أو  المابات لا يوجد ترجمة متاحة لها. هذا يعتمد على المتجر الخاص بلعبة ماين كرافت وليس على التطبيق.';

  @override
  String get pageSize => 'حجم الصفحة';

  @override
  String get pageSizeInfo => 'معلومات حجم الصفحة';

  @override
  String get pageSizeInfoText =>
      'للتحكم بعدد العناصر التي تظهر في الصفحة بنفس الوقت. • في حالة قيمة قليلة: أفضل بالنسبة للانترنت الضعيف (الأكثر طلباً) • في حالة قيمة عالية: أفضل للانترنت القوي والسريع (الأقل طلباً) جميع النتائج تبقى متاحة بغض النظر عن حجم الصفحة. تظهر المزيد من العناصر تلقائياً عندما تصل لآخر القائمة أو الصفحة';

  @override
  String get selectDlcLanguage => 'اختر لغة المحتوى';

  @override
  String get downloadPathUpdated => 'تم تحديث مسار التنزيلات';

  @override
  String get downloadPathReset => 'تم استعادة مسار التنزيلات الافتراضي';

  @override
  String get resetDefaults => 'إعادة إلى الافتراضي';

  @override
  String get chooseFolder => 'اختر المجلد';

  @override
  String get downloadPath => 'مسار التنزيلات';

  @override
  String get version => 'الإصدار';

  @override
  String get purchasing => 'جارِ الشراء';

  @override
  String get failedPurchase => 'فشلت عملية الشراء';

  @override
  String get allItemsSuccessfullyPurchased => 'تم شراء جميع العناصر بنجاح';

  @override
  String insufficientFunds(int insufficientFundsItems) {
    return 'لا يوجد لديك نقود كافية ل $insufficientFundsItems عنصر(عناصر)';
  }

  @override
  String get somePurchasesFailed => 'فشلت بعض عمليات الشراء';

  @override
  String numItemsAreNotPurchasable(int numItems) {
    return '$numItems عنصر(عناصر) غير قابل(قابلة) للشراء';
  }

  @override
  String get purchaseComplete => 'اكتملت عملية الشراء';

  @override
  String get confirmPurchase => 'تأكيد الشراء';

  @override
  String confirmPurchaseMessage(String itemsText) {
    return 'هل أنت متأكد أنك تريد شراء $itemsText ؟';
  }

  @override
  String get totalPrice => 'السعر الإجمالي:';

  @override
  String get purchaseResults => 'نتائج الشراء';

  @override
  String successfullyPurchased(int successItems) {
    return 'تم شراء $successItems عنصر(عناصر) بنجاح';
  }

  @override
  String alreadyOwnded(int alreadyOwnedItems) {
    return 'أنت تملك بالفعل: $alreadyOwnedItems';
  }

  @override
  String numItemsNotPurchasable(int notPurchasableItems) {
    return 'عنصر(عناصر) غير قابلة للشراء: $notPurchasableItems';
  }

  @override
  String numItemsInsufficientFunds(int insufficientFundsItems) {
    return 'نقود غير كافية: $insufficientFundsItems عنصر(عناصر)';
  }

  @override
  String numItemsFailed(int failedItemsCount) {
    return 'فشل شراء: $failedItemsCount عنصر(عناصر)';
  }

  @override
  String get clearCart => 'إفراغ عربة التسوق';

  @override
  String get clearCartConfirmation =>
      'هل أنت متأكد أنك تريد إزالة جميع العناصر من عربة تسوقك؟';

  @override
  String cartTitleNum(int count) {
    return 'عربة التسوق ($count)';
  }

  @override
  String get cartisEmpty => 'عربة تسوقك فارغة';

  @override
  String get cartEmptyDescription =>
      'اضغط على علامة عربة التسوق في صفحة تفاصيل أي عنصر لإضافته إلى عربة تسوقك وشرائه';

  @override
  String get purchasingInProgress => 'جارِ الشراء...';

  @override
  String purchaseAllnum(int count) {
    return 'شراء الكل ($count)';
  }

  @override
  String get nowNewdlcFound => 'لم يتم العثور على محتوى جديد';

  @override
  String get nowNewDlcFoundDescription =>
      'جميع العناصر موجودة في قاعدة بيانات التطبيق بالفعل';

  @override
  String get noDlcFound => 'لم يتم العثور على شيء';

  @override
  String get noDlcAvailable => 'لم يتم العثور على محتوى متاح';

  @override
  String get openDlcsList => 'فتح قائمة العناصر';

  @override
  String get appUpdates => 'تحديثات التطبيق';

  @override
  String get appUpdatesDescription =>
      'لرؤية ما الجديد في النسخ الحديثة من التطبيق';

  @override
  String get socials => 'وسائل التواصل الاجتماعي';

  @override
  String get selectApp => 'يرجى اختيار تطبيق';

  @override
  String get noAppsFound => 'لم يتم العثور على أي تطبيق';

  @override
  String get errorLoadingDlcs => 'حدث خطأ في تحميل المحتوى';

  @override
  String get dlcs => 'الحزم (DLCs)';

  @override
  String errorSavingKeys(String error) {
    return 'حدث خطأ في حفظ الأكواد: $error';
  }

  @override
  String errorOpeningAuthPage(String error) {
    return 'حدث خطأ في فتح صفحة التحقق: $error';
  }

  @override
  String get gettingEntityToken => 'جار الحصول على التوكن...';

  @override
  String get loadingMinecoinBalance => 'جار تحميل رصيد ماين كوين...';

  @override
  String get completeAuthFirst => 'الرجاء إكمال التحقق أولا';

  @override
  String get sessionExpired => 'انتهت الجلسة. الرجاء المحاولة لاحقا.';

  @override
  String get accessDenied => 'تم رفض الوصول. الرجاء إعادة طلب التحقق.';

  @override
  String get connectionTimeout =>
      'انتهت مهلة الاتصال. الرجاء التحقق من اتصالك بالإنترنت والمحاولة لاحقا.';

  @override
  String get serverError =>
      'حدث خطأ في الخادم. الرجاء المحاولة مرة أخرى بعد عدة لحظات.';

  @override
  String get backToSettings => 'العودة إلى الإعدادات';

  @override
  String errorInitializingCart(String error) {
    return 'حدث خطأ في تهيئة عربة التسوق: $error';
  }

  @override
  String errorLoadingCartItems(String error) {
    return 'حدث خطأ في تحميل عناصر عربة التسوق: $error';
  }

  @override
  String failedLoadMoreItems(String error) {
    return 'فشل في تحميل عناصر أكثر: $error';
  }

  @override
  String errorSavingLog(String error) {
    return 'حدث خطأ في حفظ التقرير: $error';
  }

  @override
  String get failedToDeleteFile => 'فشل في حذف الملف';

  @override
  String failedToShareFile(String error) {
    return 'فشل في مشاركة الملف: $error';
  }

  @override
  String get personaWarning =>
      'عناصر الشخصيات لا يمكن استخراجها داخل اللعبة (مثل الرقصات، العناصر الجمالية، والرداءات)';

  @override
  String get initializingMcDec => 'جار تهيئة McDec...';

  @override
  String failedToSaveKeys(String error) {
    return 'فشل في حفظ الأكواد: $error';
  }

  @override
  String get itemDetailsTitle => 'خصائص العنصر';

  @override
  String byCreator(String creator) {
    return 'من قبل $creator';
  }

  @override
  String get couldNotLoadSocials =>
      'لم يتم تحميل روابط التواصل الاجتماعي، سيتم استخدام الافتراضية';

  @override
  String get sdCardExternalStorage => 'بطاقة الذاكرة / وحدة تخزين خارجية';

  @override
  String get customLocation => 'مكان مخصص';

  @override
  String couldNotOpenLink(String error) {
    return 'لم يتم فتح الرابط: $error';
  }

  @override
  String get minecraftPackage => 'حزمة ماين كرافت';

  @override
  String get freeDroidWarnMessage =>
      'أعلنت Google أنه ابتداءً من عام 2026/2027، ستتطلب جميع التطبيقات على الأجهزة المعتمدة من Android من المطورين تقديم معلومات هويتهم الشخصية مباشرةً إلى Google. بما أن مطوري هذا التطبيق لا يوافقون على هذا الشرط، فلن يعمل هذا التطبيق على أجهزة Android المعتمدة بعد ذلك الوقت.';

  @override
  String get freeDroidWarnDetails => 'تفاصيل';

  @override
  String get freeDroidWarnSolution => 'حل';

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
