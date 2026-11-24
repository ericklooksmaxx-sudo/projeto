// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get home => 'หน้าแรก';

  @override
  String get downloads => 'ดาวน์โหลด';

  @override
  String get settings => 'ตั้งค่า';

  @override
  String get selectLanguage => 'เลือกภาษา';

  @override
  String get language => 'ภาษา';

  @override
  String get download => 'โหลดเลย';

  @override
  String get hintText => 'ค้นหา...';

  @override
  String get default1 => 'เริ่มต้น';

  @override
  String get creators => 'ครีเอเตอร์';

  @override
  String get checkingKeys => 'กำลังเช็คคีย์...';

  @override
  String get apiLogin => 'เข้าสู่ระบบ API';

  @override
  String addedNewKeys(int keyCount) {
    return 'เพิ่มคีย์ใหม่ $keyCount คีย์แล้วนะ';
  }

  @override
  String get noResult => 'ไม่เจอนะจ๊ะ';

  @override
  String get open => 'เปิด';

  @override
  String get clear => 'ล้าง';

  @override
  String get retry => 'ลองใหม่';

  @override
  String get ok => 'ตกลง';

  @override
  String queuePosition(int count) {
    return 'รอคิวอยู่นะ (ตำแหน่ง #$count)';
  }

  @override
  String queuePosition2(int count) {
    return 'รอคิว #$count)';
  }

  @override
  String imageSaved(String filePath) {
    return 'เซฟรูปไว้ที่ $filePath แล้วจ้า';
  }

  @override
  String errorDownloadingImage(String error) {
    return 'โหลดรูปไม่สำเร็จ: $error';
  }

  @override
  String get changelog => 'อัปเดตอะไรบ้าง';

  @override
  String get downloaded => 'โหลดแล้ว';

  @override
  String get retryDownload => 'โหลดใหม่ดิ';

  @override
  String get downloadImage => 'บันทึกรูป';

  @override
  String get downloadImageQuestion => 'เอาภาพนี้ป่ะ?';

  @override
  String get cancel => 'ยกเลิก';

  @override
  String get trailer => 'ดูตัวอย่าง';

  @override
  String trailerError(String error) {
    return 'เปิดตัวอย่างไม่ได้วะ: $error';
  }

  @override
  String get appearance => 'ธีม';

  @override
  String get darkMode => 'โหมดมืด';

  @override
  String get darkEnabled => 'เปิดโหมดมืดแล้ว';

  @override
  String get lightEnabled => 'เปิดโหมดสว่างแล้ว';

  @override
  String get colorScheme => 'โทนสี';

  @override
  String get defaultColor => 'ค่าตั้งต้น';

  @override
  String get defaultPurple => 'ตั้งต้น (ม่วง)';

  @override
  String get colorSchemeBlue => 'ฟ้า';

  @override
  String get colorSchemeGreen => 'เขียว';

  @override
  String get colorSchemeOrange => 'ส้ม';

  @override
  String get colorSchemeRed => 'แดง';

  @override
  String get colorSchemeTeal => 'ทีล';

  @override
  String get colorSchemePink => 'ชมพู';

  @override
  String get colorSchemeLime => 'ไลม์';

  @override
  String get filters => 'ฟิลเตอร์';

  @override
  String get filter => 'กรอง:';

  @override
  String get showSkins => 'โชว์สกิน';

  @override
  String get keys => 'คีย์';

  @override
  String get autoUpdate => 'อัปเดตอัตโนมัติ';

  @override
  String get customDb => 'DB แบบกำหนดเอง';

  @override
  String get accountLogin => 'ล็อกอินบัญชี';

  @override
  String get extras => 'เสริม';

  @override
  String get cache => 'แคช';

  @override
  String cacheCleared(String size) {
    return 'เคลียร์แคช $size MB แล้ว';
  }

  @override
  String get faq => 'คำถามบ่อย';

  @override
  String get faqUppercase => 'FAQ';

  @override
  String get terminal => 'เทอร์มินัล';

  @override
  String get faqQuestion1 => 'ช่วยเพิ่มคีย์ให้ pack นี้หน่อยดิ!';

  @override
  String get faqQuestion2 => 'เมื่อไหร่จะอัปเดตคีย์อะ?';

  @override
  String get faqQuestion3 => 'Encrypted กับ Decrypted ต่างกันยังไง?';

  @override
  String get faqQuestion4 => 'หาไฟล์ pack ที่โหลดมาได้ที่ไหน?';

  @override
  String get faqQuestion5 => 'keys.tsv คืออะไร?';

  @override
  String get faqQuestion6 => 'ใช้ไอเทม Persona ยังไง?';

  @override
  String get faqQuestion7 => 'ทำไมสกินบางอันพัง?';

  @override
  String get faqQuestion8 => 'หน้า \"Account Login\" มีไว้ทำไม?';

  @override
  String get faqQuestion9 => 'เครื่องหมายติ๊กถูกหมายความว่าไง?';

  @override
  String get faqAnswer1 =>
      'การได้คีย์มาไม่ได้วิเศษอะไรขนาดนั้นนะ คือต้องมีคนซื้อ pack แล้วแชร์คีย์มาให้ก่อน ถ้าไม่มีใครซื้อก็ไม่มีคีย์ให้ถอดรหัสตั้งแต่แรก ไม่มีทางอื่นได้คีย์มาหรอก รอหน่อยหรือไม่ก็ซื้อเองเลยจ้า';

  @override
  String get faqAnswer2 => 'ไว้เราสะดวกเมื่อไหร่ก็อัปเดตเมื่อนั้นแหละ';

  @override
  String get faqAnswer3 =>
      'Encrypted = ไฟล์ถูกทำให้เป็นตัวอักษรไร้สาระอ่านไม่ออก ไม่มีใครเปิดอ่านได้ถ้าไม่มีคีย์พิเศษ คอนเทนต์ Minecraft ที่เข้ารหัสแล้วเล่นไม่ได้นะ\\n\\nDecrypted = ใช้คีย์พิเศษแปลง gibberish กลับเป็นเนื้อหาเดิม เล่นได้ตามปกติ';

  @override
  String get faqAnswer4 => 'หาไฟล์ได้ที่ ดาวน์โหลด/Kyzen จ้า';

  @override
  String get faqAnswer5 =>
      'เป็นไฟล์เก็บ UUID ของ pack พร้อมคีย์ถอดรหัสประจำ pack นั้นๆ ถ้าไม่มีคีย์ถอดรหัส pack ที่โหลดมาก็เล่นไม่ได้เลย';

  @override
  String get faqAnswer6 =>
      'ใช้ไม่ได้จ้า มีวิธีอยู่บ้างแต่มันซับซ้อนเกินกว่าจะทำได้จริง';

  @override
  String get faqAnswer7 =>
      'สกินบางอัน (โดยเฉพาะคอลแล็บแฟรนไชส์) ใช้ custom geometry ที่ Minecraft ไม่อนุญาตให้ใช้ปกติเว้นแต่ซื้อสกินนั้น ลองเช็คว่ามีไฟล์ geometry.json ใน pack ไหม ปัญหานี้ไม่เกี่ยวกับแอปนะ';

  @override
  String get faqAnswer8 =>
      'หน้า account login ให้คุณล็อกอินด้วยบัญชี Microsoft เพื่อโหลดคีย์ Minecraft จาก inventory ของคุณโดยตรง\\nมีประโยชน์เวลาที่ Kyzen ยังไม่มีคีย์สำหรับ DLC ไหน แต่คุณมีในบัญชีของคุณ เมื่อโหลดคีย์แล้ว DLC นั้นจะขึ้นว่าโหลดได้\\nคีย์จะถูกอัปโหลดไปยังฐานข้อมูลเราอัตโนมัติเพื่อรวมกับฐานข้อมูลหลักของ Kyzen ให้ทุกคนโหลด DLC ใหม่ๆ ได้ ช่วยกันใช้ฟีเจอร์นี้ด้วยนะถ้าอยาก contribute';

  @override
  String get faqAnswer9Checkmark => 'มีคีย์สำหรับ DLC นี้แล้ว';

  @override
  String get faqAnswer9NoCheckmark => 'แอปยังไม่มีคีย์สำหรับ DLC นี้';

  @override
  String get faqAnswer9ExtraInfo => 'ต้องมีคีย์ถึงจะปลดล็อก DLC ได้นะ';

  @override
  String get faqQuestionDownload => 'ทำไมกดปุ่มดาวน์โหลดไม่ได้?';

  @override
  String get faqAnswerDownload =>
      'คีย์ปลดล็อก DLC นี้ยังไม่ว่าง รอหน่อยหรือซื้อเลยจ้า';

  @override
  String get faqQuestionKey => 'หาคีย์ยังไง?';

  @override
  String get faqAnswerKey =>
      'ซื้อ DLC ในบัญชีคุณก่อน แล้วไป settings > Account login > กด \'Start authentication\' > กด \'Load keys\' แล้วกด \'Share\' แชร์ไฟล์คีย์ไปที่ Bluecoin chat คีย์จะถูกเพิ่มเข้าไปในฐานข้อมูลแอป ถ้าแชร์ไม่ได้ก็ไม่ต้องห่วง คีย์มันอัปโหลดอัตโนมัติอยู่แล้ว';

  @override
  String get faqMoreHelp => 'ช่วยเหลือเพิ่มเติม';

  @override
  String get faqNotAdlc => 'ไม่ใช่ DLC';

  @override
  String get faqNotAdlcDescription => 'อันนี้ไม่ใช่ DLC นะจ๊ะ';

  @override
  String get faqServerContent => 'คอนเทนต์เซิฟเวอร์';

  @override
  String get faqServerContentDescription =>
      'ไอเทมนี้เป็น exclusive ของเซิฟเวอร์นั้นๆ ไม่สามารถโหลดโดยตรงได้';

  @override
  String get fileDeleted => 'ลบไฟล์แล้ว';

  @override
  String get storedFiles => 'ไฟล์ที่เก็บไว้';

  @override
  String get refreshFiles => 'รีเฟรชไฟล์';

  @override
  String get deleteFile => 'ลบไฟล์';

  @override
  String deleteFileConfirmation(String fileName) {
    return 'แน่ใจนะว่าจะลบ $fileName?';
  }

  @override
  String get cancelUppercase => 'ยกเลิก';

  @override
  String get deleteUppercase => 'ลบ';

  @override
  String get currentDownload => 'กำลังโหลด';

  @override
  String get noActiveDownloads => 'ไม่มีการโหลดตอนนี้';

  @override
  String get completedDownloads => 'โหลดเสร็จแล้ว';

  @override
  String get clearAll => 'ล้างทั้งหมด';

  @override
  String get importToMc => 'นำเข้า Minecraft';

  @override
  String get openFileinExplorer => 'เปิดใน file explorer';

  @override
  String get shareFile => 'แชร์ไฟล์';

  @override
  String get debugTerminal => 'ดีบักเทอร์มินัล';

  @override
  String get clearLogs => 'ล้างล็อก';

  @override
  String get noLogs => 'ยังไม่มีล็อก...';

  @override
  String get saveLogs => 'เซฟล็อก';

  @override
  String logsSaved(String filePath) {
    return 'เซฟล็อกไว้ที่ $filePath แล้ว';
  }

  @override
  String get selectingFile => 'กำลังเลือกไฟล์...';

  @override
  String get processingFile => 'กำลังประมวลผล...';

  @override
  String get fileProcessed => 'ประมวลผลไฟล์สำเร็จ!';

  @override
  String get noFileSelected => 'ยังไม่เลือกไฟล์';

  @override
  String customKeysLoaded(int count) {
    return 'โหลด custom keys $count คีย์แล้ว';
  }

  @override
  String get noCustomKeysLoaded => 'ไม่มีการโหลด custom keys';

  @override
  String get importFileFormat => 'นำเข้าไฟล์รูปแบบ UUID=KEY';

  @override
  String creatorItemsWithType(String contentType) {
    return 'ไอเทม $contentType';
  }

  @override
  String creatorItemsWithTypeAndCount(String contentType, int count) {
    return 'ไอเทม $contentType ($count)';
  }

  @override
  String get creatorItemsDefault => 'ไอเทมครีเอเตอร์';

  @override
  String get noItemCreator => 'ครีเอเตอร์นี้ยังไม่มีคอนเทนต์';

  @override
  String get noStatistic => 'ไม่มีสถิติให้ดู';

  @override
  String get failedLoadStatistic => 'โหลดสถิติไม่สำเร็จ';

  @override
  String get noResultsFound => 'ไม่เจอผลลัพธ์';

  @override
  String get microsoftAuth => 'ยืนยันตัวตน Microsoft';

  @override
  String get exchangingToken => 'กำลังแลก authorization code เป็น token...';

  @override
  String authenticationFailed(String error) {
    return 'ยืนยันตัวตนไม่สำเร็จ: $error';
  }

  @override
  String get authenticationSuccessful => 'ยืนยันตัวตนสำเร็จ!';

  @override
  String failedToExchangeToken(String error) {
    return 'แลก code เป็น token ไม่ได้: $error';
  }

  @override
  String get noAuthorizationCodeReceived => 'ไม่ได้รับ authorization code';

  @override
  String get noNewKeysCopy => 'ไม่พบคีย์ใหม่ให้คัดลอก';

  @override
  String get keysCopyClipboard => 'คัดลอกคีย์ไปคลิปบอร์ดแล้ว!';

  @override
  String get noNewKeysShare => 'ไม่พบคีย์ใหม่ให้แชร์';

  @override
  String get keysShared => 'แชร์คีย์สำเร็จ!';

  @override
  String get authCheck => 'กำลังตรวจสอบการยืนยันตัวตนที่มีอยู่...';

  @override
  String get alreadyAuth => 'ยืนยันตัวตนแล้ว!';

  @override
  String get readyAuth => 'พร้อมยืนยันตัวตน';

  @override
  String get authURL => 'ยืนยันตัวตนด้วย URL';

  @override
  String get completeAuthButton => 'ยืนยันตัวตนเสร็จสิ้น';

  @override
  String get openAuthPageButton => 'เปิดหน้า Auth';

  @override
  String get completeAuth =>
      'ยืนยันตัวตนในเบราว์เซอร์ของคุณ แล้วคุณจะถูกพากลับมาที่แอป';

  @override
  String get copyUrl => 'คัดลอก URL';

  @override
  String get authPageFail => 'เปิดหน้า authentication ไม่ได้';

  @override
  String get logout => 'กำลังออกจากระบบ...';

  @override
  String get logoutOk => 'ออกจากระบบสำเร็จ';

  @override
  String get usingCachedSession => 'ใช้เซสชันที่แคชไว้...';

  @override
  String get loadingMinecraftKeys => 'กำลังโหลดคีย์ Minecraft...';

  @override
  String get requestingXboxLiveToken => 'กำลังขอ Xbox Live token...';

  @override
  String get loggingInToPlayFab => 'กำลังล็อกอิน PlayFab...';

  @override
  String get gettingUserInformation => 'กำลังดึงข้อมูลผู้ใช้...';

  @override
  String get startingMinecraftSession => 'กำลังเริ่มเซสชัน Minecraft...';

  @override
  String get loadingMinecraftInventory => 'กำลังโหลด inventory Minecraft...';

  @override
  String successfullyLoadedKeys(int keyCount) {
    return 'โหลด $keyCount คีย์สำเร็จ!';
  }

  @override
  String errorLoadingKeys(String error) {
    return 'โหลดคีย์ผิดพลาด: $error';
  }

  @override
  String get copyClipboard => 'คัดลอกไปคลิปบอร์ดแล้ว';

  @override
  String get authOk => 'ยืนยันตัวตนแล้ว';

  @override
  String get authNotOk => 'ยังไม่ยืนยันตัวตน';

  @override
  String get urlAuth => 'URL ยืนยันตัวตน';

  @override
  String get loadedKeys => 'คีย์ที่โหลดแล้ว';

  @override
  String get exportNewKeys => 'ส่งออกเฉพาะคีย์ใหม่';

  @override
  String get loadKeysButton => 'โหลดคีย์';

  @override
  String get logoutButton => 'ออกจากระบบ';

  @override
  String get startAuthButton => 'เริ่มการยืนยันตัวตน';

  @override
  String get greetings => 'สวัสดี ';

  @override
  String get copy => 'คัดลอก';

  @override
  String get save => 'เซฟ';

  @override
  String get share => 'แชร์';

  @override
  String get keysSaved => 'เซฟคีย์สำเร็จ';

  @override
  String get startingDownload => 'กำลังเริ่มดาวน์โหลด...';

  @override
  String get downloadsCompleted => 'ดาวน์โหลดเสร็จหมดแล้ว';

  @override
  String get completed => 'เสร็จ!';

  @override
  String get downloadFailed => 'โหลดไม่สำเร็จ';

  @override
  String get downloading => 'กำลังโหลด';

  @override
  String get processing => 'กำลังประมวลผล';

  @override
  String get extractingZipFile => 'กำลังแตกไฟล์ zip...';

  @override
  String get decryptingContents => 'กำลังถอดรหัส...';

  @override
  String get compressingPack => 'กำลังบีบอัด pack...';

  @override
  String get cleaningUp => 'กำลังทำความสะอาด...';

  @override
  String get showAll => 'แสดงทั้งหมด';

  @override
  String get onlyAvailable => 'มีเท่านั้น';

  @override
  String get onlyNotAvailable => 'ที่ไม่มี';

  @override
  String get customColor => 'สีกำหนดเอง';

  @override
  String get changeCustomColor => 'แตะเพื่อเปลี่ยนสี';

  @override
  String get createCustomColor => 'สร้างโทนสีของคุณเอง';

  @override
  String get pickColor => 'เลือกสี';

  @override
  String get selectColor => 'เลือก';

  @override
  String get images => 'รูปภาพ';

  @override
  String get saveToPng => 'เซฟเป็น PNG';

  @override
  String get saveToGallery => 'เซฟลงแกลอรี';

  @override
  String get compression => 'การบีบอัด';

  @override
  String get normalCompression => 'บีบอัดปกติ';

  @override
  String get noCompression => 'ไม่บีบอัด';

  @override
  String get copyUUID => 'คัดลอก UUID';

  @override
  String get openInMinecraft => 'เปิดใน Minecraft';

  @override
  String get creator => 'ครีเอเตอร์';

  @override
  String get addToCart => 'เพิ่มลงตะกร้า';

  @override
  String get removeFromCart => 'เอาออกจากตะกร้า';

  @override
  String get addedToCart => 'เพิ่มลงตะกร้าแล้ว';

  @override
  String get removedFromCart => 'เอาออกจากตะกร้าแล้ว';

  @override
  String get authRequired => 'ต้องยืนยันตัวตนก่อน';

  @override
  String get authRequiredDesc =>
      'นายต้องยืนยันตัวตนก่อนถึงจะดูตะกร้าได้ ไปที่หน้า Account login แล้วยืนยันตัวตนก่อนนะ';

  @override
  String get newUpdate => 'อัปเดตล่าสุด';

  @override
  String get newDlc => 'DLC ใหม่';

  @override
  String get hidden => 'ซ่อน';

  @override
  String get persona => 'Persona';

  @override
  String get skins => 'สกิน';

  @override
  String get mashups => 'Mashups';

  @override
  String get worlds => 'โลก';

  @override
  String get textures => 'พื้นผิว';

  @override
  String get addons => 'Add-Ons';

  @override
  String get capes => 'เคป';

  @override
  String get vibrantVisuals => 'Vibrant Visuals';

  @override
  String get favorites => 'รายการโปรด';

  @override
  String get unfiltered => 'ไม่กรอง';

  @override
  String get sorting => 'เรียงลำดับ';

  @override
  String get type => 'ประเภท';

  @override
  String get newFilter => 'ใหม่';

  @override
  String get other => 'อื่นๆ';

  @override
  String get newest => 'ล่าสุด';

  @override
  String get oldest => 'เก่าสุด';

  @override
  String get mostRated => 'เรตติ้งมากสุด';

  @override
  String get leastRated => 'เรตติ้งน้อยสุด';

  @override
  String get menu => 'เมนู';

  @override
  String imageSavedToGallery(String filePath) {
    return 'เซฟรูปไว้ในแกลอรี: $filePath';
  }

  @override
  String get vibrantVisualEnhanced => 'Vibrant Visuals Enhanced';

  @override
  String get uuidCopied => 'คัดลอก UUID ไปคลิปบอร์ดแล้ว';

  @override
  String get scrollRight => 'เลื่อนขวา';

  @override
  String get scrollLeft => 'เลื่อนซ้าย';

  @override
  String get previousImage => 'รูปก่อนหน้า';

  @override
  String get nextImage => 'รูปถัดไป';

  @override
  String get favoriteEmpty => 'ยังไม่มีรายการโปรดเลย';

  @override
  String get favoriteDescription =>
      'กดไอคอนหัวใจที่หน้ารายละเอียดสินค้าเพื่อเพิ่มเข้าสู่รายการโปรดนะ';

  @override
  String get removeFromFavorites => 'ลบออกจากรายการโปรด';

  @override
  String get addToFavorites => 'เพิ่มในรายการโปรด';

  @override
  String get addedToFavorites => 'เพิ่มในรายการโปรดแล้ว';

  @override
  String get removedFromFavorites => 'เอาออกจากรายการโปรดแล้ว';

  @override
  String get noNewKeysFoundToSave => 'ไม่พบคีย์ใหม่ให้เซฟ';

  @override
  String get keysSavedSuccessfully => 'เซฟคีย์ลงในโฟลเดอร์ Kyzen เรียบร้อย';

  @override
  String get entitlementKeys => 'Entitlement Keys';

  @override
  String get searchBoughContent => 'ค้นหาคอนเทนต์ที่คุณซื้อใน Minecraft';

  @override
  String get saveKeys => 'เซฟคีย์';

  @override
  String get refresh => 'รีเฟรช';

  @override
  String get searchKeys => 'ค้นหาคีย์';

  @override
  String get loadSkinPersona => 'โหลด SkinPack/Persona';

  @override
  String get descriptionSkinPersona => 'รวม skinpack และ persona ในลิสต์ด้วย';

  @override
  String get loadOnlyNewKeys => 'โหลดเฉพาะคีย์ใหม่';

  @override
  String get descriptionLoadOnlyNewKeys =>
      'โหลดเฉพาะคอนเทนต์ที่ยังไม่มีในฐานข้อมูลคีย์ของแอป';

  @override
  String get descriptionExportNewKeys =>
      'ว่าจะให้ \"เซฟคีย์\" ส่งออกเฉพาะคีย์ใหม่หรือเปล่า';

  @override
  String processedEntitlementKeys(int countFiles, int countKeys) {
    return 'ประมวลผลสำเร็จ ($countFiles ไฟล์, $countKeys คีย์)';
  }

  @override
  String get noResultsYet => 'ยังไม่มีผลลัพธ์';

  @override
  String get clickSearchKeysToLoadContent =>
      'กด \"ค้นหาคีย์\" เพื่อโหลดคอนเทนต์ของคุณ';

  @override
  String get tryadifferentSearch => 'ลองค้นหาคำอื่นดู';

  @override
  String get minecraftNotInstalled =>
      'ไม่พบพาธติดตั้ง Minecraft ที่ถูกต้อง กรุณาให้แน่ใจว่าได้ติดตั้ง Minecraft Bedrock Edition (UWP หรือ GDK) และเปิดมันอย่างน้อยสักครั้ง';

  @override
  String get processingError => 'ข้อผิดพลาดตอนประมวลผล';

  @override
  String get dismiss => 'ปิด';

  @override
  String get failedFiles => 'ไฟล์ที่ล้มเหลว:';

  @override
  String get minecraftFont => 'ฟอนต์ Minecraft';

  @override
  String get usingMinecraftFont => 'กำลังใช้ฟอนต์สไตล์ Minecraft';

  @override
  String get usingDefaultFont => 'กำลังใช้ฟอนต์ปกติ';

  @override
  String get dlcLanguage => 'ภาษา DLC';

  @override
  String get dlcLangInfo => 'ข้อมูลภาษา DLC';

  @override
  String get dlcLangInfoText =>
      'หมายเหตุ: DLC บางอันอาจไม่มีแปลภาษา อันนี้ขึ้นอยู่กับ marketplace ไม่ใช่แอปนะ';

  @override
  String get pageSize => 'จำนวนต่อหน้า';

  @override
  String get pageSizeInfo => 'ข้อมูลจำนวนต่อหน้า';

  @override
  String get pageSizeInfoText =>
      'กำหนดว่าจะโหลดกี่รายการในแต่ละครั้ง\\n\\n • ค่าน้อย: เหมาะกับเน็ตช้า (เรียกขอข้อมูลบ่อยขึ้น)\\n • ค่าเยอะ: เหมาะกับเน็ตแรง (เรียกขอข้อมูลน้อยลง)\\n\\nผลลัพธ์ทั้งหมดยังคงเข้าถึงได้ไม่ว่าจะตั้งค่าเท่าไหร่ รายการเพิ่มเติมจะโหลดอัตโนมัติเมื่อเลื่อนมาถึงด้านล่าง';

  @override
  String get selectDlcLanguage => 'เลือกภาษา DLC';

  @override
  String get downloadPathUpdated => 'อัปเดตพาธโหลดแล้ว';

  @override
  String get downloadPathReset => 'รีเซ็ตพาธโหลดกลับเป็นค่าเริ่มต้น';

  @override
  String get resetDefaults => 'รีเซ็ตเป็นค่าตั้งต้น';

  @override
  String get chooseFolder => 'เลือกโฟลเดอร์';

  @override
  String get downloadPath => 'พาธดาวน์โหลด';

  @override
  String get version => 'เวอร์ชัน';

  @override
  String get purchasing => 'กำลังซื้อ';

  @override
  String get failedPurchase => 'ซื้อไม่สำเร็จ';

  @override
  String get allItemsSuccessfullyPurchased => 'ซื้อทั้งหมดสำเร็จแล้ว!';

  @override
  String insufficientFunds(int insufficientFundsItems) {
    return 'ตังไม่พอสำหรับ $insufficientFundsItems รายการ';
  }

  @override
  String get somePurchasesFailed => 'บางรายการซื้อไม่สำเร็จ';

  @override
  String numItemsAreNotPurchasable(int numItems) {
    return '$numItems รายการไม่สามารถซื้อได้';
  }

  @override
  String get purchaseComplete => 'ซื้อเสร็จแล้ว';

  @override
  String get confirmPurchase => 'ยืนยันการซื้อ';

  @override
  String confirmPurchaseMessage(String itemsText) {
    return 'แน่ใจนะว่าจะซื้อ $itemsText?';
  }

  @override
  String get totalPrice => 'ราคารวม:';

  @override
  String get purchaseResults => 'ผลการซื้อ';

  @override
  String successfullyPurchased(int successItems) {
    return 'ซื้อสำเร็จ: $successItems รายการ';
  }

  @override
  String alreadyOwnded(int alreadyOwnedItems) {
    return 'มีอยู่แล้ว: $alreadyOwnedItems รายการ';
  }

  @override
  String numItemsNotPurchasable(int notPurchasableItems) {
    return 'ซื้อไม่ได้: $notPurchasableItems รายการ';
  }

  @override
  String numItemsInsufficientFunds(int insufficientFundsItems) {
    return 'ตังไม่พอ: $insufficientFundsItems รายการ';
  }

  @override
  String numItemsFailed(int failedItemsCount) {
    return 'ซื้อล้มเหลว: $failedItemsCount รายการ';
  }

  @override
  String get clearCart => 'ล้างตะกร้า';

  @override
  String get clearCartConfirmation => 'เอาของทั้งหมดออกจากตะกร้าจริงๆ ปะ?';

  @override
  String cartTitleNum(int count) {
    return 'ตะกร้า ($count)';
  }

  @override
  String get cartisEmpty => 'ตะกร้าว่างอยู่นะ';

  @override
  String get cartEmptyDescription =>
      'กดไอคอนตะกร้าที่หน้ารายละเอียดสินค้าเพื่อเพิ่มแล้วซื้อได้เลย';

  @override
  String get purchasingInProgress => 'กำลังซื้อ...';

  @override
  String purchaseAllnum(int count) {
    return 'ซื้อทั้งหมด ($count)';
  }

  @override
  String get nowNewdlcFound => 'ไม่พบ DLC ใหม่';

  @override
  String get nowNewDlcFoundDescription => 'DLC ทั้งหมดมีอยู่ในฐานข้อมูลแอปแล้ว';

  @override
  String get noDlcFound => 'ไม่พบ DLC';

  @override
  String get noDlcAvailable => 'ไม่มี DLC ให้ใช้';

  @override
  String get openDlcsList => 'เปิดรายการ DLC';

  @override
  String get appUpdates => 'อัปเดตแอป';

  @override
  String get appUpdatesDescription => 'ดูว่ามีอะไรใหม่ในเวอร์ชันล่าสุดบ้าง';

  @override
  String get socials => 'โซเชียล';

  @override
  String get selectApp => 'เลือกแอป';

  @override
  String get noAppsFound => 'ไม่พบแอป';

  @override
  String get errorLoadingDlcs => 'โหลด DLC ผิดพลาด';

  @override
  String get dlcs => 'DLCs';

  @override
  String errorSavingKeys(String error) {
    return 'เซฟคีย์ผิดพลาด: $error';
  }

  @override
  String errorOpeningAuthPage(String error) {
    return 'เปิดหน้า authentication ผิดพลาด: $error';
  }

  @override
  String get gettingEntityToken => 'กำลังรับ entity token...';

  @override
  String get loadingMinecoinBalance => 'กำลังโหลดยอด Minecoin...';

  @override
  String get completeAuthFirst => 'กรุณายืนยันตัวตนก่อน';

  @override
  String get sessionExpired => 'เซสชันหมดอายุแล้ว กรุณาลองใหม่';

  @override
  String get accessDenied => 'ไม่อนุญาต กรุณายืนยันตัวตนอีกครั้ง';

  @override
  String get connectionTimeout => 'การเชื่อมต่อหมดเวลา เช็คเน็ตแล้วลองใหม่นะ';

  @override
  String get serverError => 'เซิฟเวอร์มีปัญหา กรุณาลองใหม่สักครู่';

  @override
  String get backToSettings => 'กลับไปตั้งค่า';

  @override
  String errorInitializingCart(String error) {
    return 'เริ่มต้นตะกร้าผิดพลาด: $error';
  }

  @override
  String errorLoadingCartItems(String error) {
    return 'โหลดรายการในตะกร้าผิดพลาด: $error';
  }

  @override
  String failedLoadMoreItems(String error) {
    return 'โหลดรายการเพิ่มไม่สำเร็จ: $error';
  }

  @override
  String errorSavingLog(String error) {
    return 'เซฟล็อกผิดพลาด: $error';
  }

  @override
  String get failedToDeleteFile => 'ลบไฟล์ไม่สำเร็จ';

  @override
  String failedToShareFile(String error) {
    return 'แชร์ไฟล์ไม่สำเร็จ: $error';
  }

  @override
  String get personaWarning =>
      'ไอเทม Persona ไม่สามารถนำเข้าในเกมได้ (เช่น อีโมท เครื่องสำอาง เคป)';

  @override
  String get initializingMcDec => 'กำลังเริ่มต้น McDec...';

  @override
  String failedToSaveKeys(String error) {
    return 'เซฟคีย์ไม่สำเร็จ: $error';
  }

  @override
  String get itemDetailsTitle => 'รายละเอียดไอเทม';

  @override
  String byCreator(String creator) {
    return 'โดย $creator';
  }

  @override
  String get couldNotLoadSocials =>
      'โหลดลิงก์โซเชียลไม่สำเร็จ ใช้ค่าเริ่มต้นแทน';

  @override
  String get sdCardExternalStorage => 'SD Card / ที่เก็บภายนอก';

  @override
  String get customLocation => 'ตำแหน่งที่กำหนดเอง';

  @override
  String couldNotOpenLink(String error) {
    return 'เปิดลิงก์ไม่ได้: $error';
  }

  @override
  String get minecraftPackage => 'แพ็กเกจ Minecraft';

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
