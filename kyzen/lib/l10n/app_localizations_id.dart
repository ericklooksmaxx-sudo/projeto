// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get home => 'Beranda';

  @override
  String get downloads => 'Unduhan';

  @override
  String get settings => 'Pengaturan';

  @override
  String get selectLanguage => 'Pilih Bahasa';

  @override
  String get language => 'Bahasa';

  @override
  String get download => 'Unduh';

  @override
  String get hintText => 'Cari...';

  @override
  String get default1 => 'Default';

  @override
  String get creators => 'Kreator';

  @override
  String get checkingKeys => 'Memeriksa keys';

  @override
  String get apiLogin => 'Masuk ke API';

  @override
  String addedNewKeys(int keyCount) {
    return 'Telah ditambahkan $keyCount keys baru';
  }

  @override
  String get noResult => 'Tidak ada hasil ditemukan';

  @override
  String get open => 'Buka';

  @override
  String get clear => 'Bersihkan';

  @override
  String get retry => 'Coba Lagi';

  @override
  String get ok => 'OK';

  @override
  String queuePosition(int count) {
    return 'Antrean (Posisi #$count)';
  }

  @override
  String queuePosition2(int count) {
    return 'Antrean #$count)';
  }

  @override
  String imageSaved(String filePath) {
    return 'Gambar tersimpan ke $filePath';
  }

  @override
  String errorDownloadingImage(String error) {
    return 'Terjadi kesalahan saat mengunduh gambar: $error';
  }

  @override
  String get changelog => 'Log Perubahan';

  @override
  String get downloaded => 'Sudah Diunduh';

  @override
  String get retryDownload => 'Ulangi Unduhan';

  @override
  String get downloadImage => 'Unduh Gambar';

  @override
  String get downloadImageQuestion => 'Unduh gambar ini?';

  @override
  String get cancel => 'Batal';

  @override
  String get trailer => 'Tonton Trailer';

  @override
  String trailerError(String error) {
    return 'Tidak dapat membuka trailer: $error';
  }

  @override
  String get appearance => 'Tampilan';

  @override
  String get darkMode => 'Mode Gelap';

  @override
  String get darkEnabled => 'Mode gelap aktif';

  @override
  String get lightEnabled => 'Mode terang aktif';

  @override
  String get colorScheme => 'Skema Warna';

  @override
  String get defaultColor => 'Default';

  @override
  String get defaultPurple => 'Default (Ungu)';

  @override
  String get colorSchemeBlue => 'Biru';

  @override
  String get colorSchemeGreen => 'Hijau';

  @override
  String get colorSchemeOrange => 'Oranye';

  @override
  String get colorSchemeRed => 'Merah';

  @override
  String get colorSchemeTeal => 'Biru Kehijauan';

  @override
  String get colorSchemePink => 'Merah Muda';

  @override
  String get colorSchemeLime => 'Hijau Lemon';

  @override
  String get filters => 'Filter';

  @override
  String get filter => 'Filter:';

  @override
  String get showSkins => 'Tampilkan skin';

  @override
  String get keys => 'Keys';

  @override
  String get autoUpdate => 'Pembaruan otomatis';

  @override
  String get customDb => 'DB Kustom';

  @override
  String get accountLogin => 'Login Akun';

  @override
  String get extras => 'Tambahan';

  @override
  String get cache => 'Cache';

  @override
  String cacheCleared(String size) {
    return 'Telah dibersihkan $size MB cache';
  }

  @override
  String get faq => 'Tanya Jawab';

  @override
  String get faqUppercase => 'TANYA JAWAB';

  @override
  String get terminal => 'Terminal';

  @override
  String get faqQuestion1 => 'Tolong tambahkan keys untuk paket ini dan itu.';

  @override
  String get faqQuestion2 => 'Kapan keys akan diperbarui?';

  @override
  String get faqQuestion3 => 'Apa perbedaan antara Terenkripsi dan Didekripsi?';

  @override
  String get faqQuestion4 => 'Di mana saya menemukan paket yang sudah diunduh?';

  @override
  String get faqQuestion5 => 'Apa itu keys.tsv?';

  @override
  String get faqQuestion6 => 'Bagaimana cara menggunakan item Persona?';

  @override
  String get faqQuestion7 => 'Mengapa beberapa paket skin terlihat rusak?';

  @override
  String get faqQuestion8 => 'Apa tujuan dari halaman \"Login Akun\"?';

  @override
  String get faqQuestion9 => 'Apa arti tanda centang itu?';

  @override
  String get faqAnswer1 =>
      'Proses mendapatkan keys bukanlah sulap: seseorang tetap harus membeli paketnya dan membagikan keys nya kepada kami. Tanpa ada yang membelinya, tidak akan ada keys dekripsi. Tidak ada cara lain untuk mendapatkannya. Bersabarlah atau belilah.';

  @override
  String get faqAnswer2 => 'Kapan pun kami memutuskan.';

  @override
  String get faqAnswer3 =>
      'Terenkripsi berarti mengubah file menjadi kata acak yang tidak bisa dibaca. Tidak ada yang bisa membacanya tanpa keys khusus. Konten Minecraft yang terenkripsi tidak dapat dimainkan.\n\nDidekripsi berarti menggunakan keys khusus untuk mengubah kata acak kembali ke konten aslinya. Sekarang konten Minecraft dapat digunakan.';

  @override
  String get faqAnswer4 => 'Kamu dapat menemukan paketnya di Unduhan/Kyzen';

  @override
  String get faqAnswer5 =>
      'Ini adalah file yang menyimpan UUID paket beserta keys dekripsinya masing-masing. Tanpa keys dekripsi, paket yang diunduh tidak akan dapat dimainkan.';

  @override
  String get faqAnswer6 =>
      'Kamu tidak bisa. Memang ada beberapa metode, tetapi mengingat kompleksitasnya, hal itu tidak memungkinkan.';

  @override
  String get faqAnswer7 =>
      'Beberapa paket skin (terutama kolaborasi franchise) menggunakan geometri kustom yang tidak diizinkan Minecraft untuk digunakan secara normal kecuali jika kamu membeli paket skin tersebut. Kamu dapat memeriksa apakah suatu paket skin menggunakan geometri kustom dengan memeriksa apakah file \"geometry.json\" ada di dalam paket tersebut. Perlu diingat bahwa masalah ini tidak ada hubungannya dengan alat ini.';

  @override
  String get faqAnswer8 =>
      'Halaman login akun mengizinkan kamu untuk mengautentikasi akun Microsoftmu untuk memuat langsung keys Minecraft dari inventaris kamu.\nIni sangat berguna ketika Kyzen saat ini belum memiliki keys untuk DLC tertentu tetapi kamu memilikinya di akun kamu, setelah keys kamu dimuat, DLC tersebut akan muncul dan tersedia untuk diunduh.\nPerlu diingat bahwa keys secara otomatis diunggah ke database kami, di mana nantinya akan digabungkan dengan database keys utama Kyzen sehingga semua orang dapat menikmati DLC baru tersebut, jadi gunakan fitur ini jika kamu ingin berkontribusi.';

  @override
  String get faqAnswer9Checkmark => 'Keys untuk DLC ini tersedia.';

  @override
  String get faqAnswer9NoCheckmark =>
      'Saat ini aplikasi belum memiliki keys untuk DLC ini.';

  @override
  String get faqAnswer9ExtraInfo => 'Keys dibutuhkan untuk membuka DLC.';

  @override
  String get faqQuestionDownload => 'Kenapa tombol unduh tidak tersedia?';

  @override
  String get faqAnswerDownload =>
      'Keys untuk membuka DLC ini tidak tersedia, tunggu dengan sabar atau belilah.';

  @override
  String get faqQuestionKey => 'Bagaimana cara mendapatkan keys?';

  @override
  String get faqAnswerKey =>
      'Beli DLC di akunmu kemudian masuk ke Pengaturan > Login Akun > Klik \'Mulai Autentikasi\' > klik \'Muat Keys\', lalu klik \'Bagikan\' dan bagikan file keys ke Bluecoin chat, keys akan ditambahkan ke database aplikasi. Jika kamu tidak bisa membagikan file keys ke grup, jangan khawatir, keys akan otomatis terunggah ke database.';

  @override
  String get faqMoreHelp => 'Bantuan Lainnya';

  @override
  String get faqNotAdlc => 'Bukan DLC';

  @override
  String get faqNotAdlcDescription => 'Item ini bukan DLC.';

  @override
  String get faqServerContent => 'Konten Server';

  @override
  String get faqServerContentDescription =>
      'Item ini eksklusif untuk server tertentu dan tidak dapat diunduh secara langsung.';

  @override
  String get fileDeleted => 'File dihapus';

  @override
  String get storedFiles => 'File Tersimpan';

  @override
  String get refreshFiles => 'Segarkan file';

  @override
  String get deleteFile => 'Hapus File';

  @override
  String deleteFileConfirmation(String fileName) {
    return 'Apakah kamu yakin ingin menghapus $fileName?';
  }

  @override
  String get cancelUppercase => 'BATAL';

  @override
  String get deleteUppercase => 'HAPUS';

  @override
  String get currentDownload => 'Unduhan Saat Ini';

  @override
  String get noActiveDownloads => 'Tidak ada unduhan aktif';

  @override
  String get completedDownloads => 'Unduhan Selesai';

  @override
  String get clearAll => 'Bersihkan Semua';

  @override
  String get importToMc => 'Impor ke Minecraft';

  @override
  String get openFileinExplorer => 'Buka di file explorer';

  @override
  String get shareFile => 'Bagikan file';

  @override
  String get debugTerminal => 'Terminal Debug';

  @override
  String get clearLogs => 'Hapus log';

  @override
  String get noLogs => 'Belum ada log...';

  @override
  String get saveLogs => 'Simpan log';

  @override
  String logsSaved(String filePath) {
    return 'Log tersimpan di $filePath';
  }

  @override
  String get selectingFile => 'Memilih file...';

  @override
  String get processingFile => 'Memproses file...';

  @override
  String get fileProcessed => 'File berhasil diproses!';

  @override
  String get noFileSelected => 'Tidak ada file yang dipilih';

  @override
  String customKeysLoaded(int count) {
    return '$count keys kustom dimuat';
  }

  @override
  String get noCustomKeysLoaded => 'Tidak ada keys kustom yang dimuat';

  @override
  String get importFileFormat => 'Impor file dengan format UUID=KEY';

  @override
  String creatorItemsWithType(String contentType) {
    return '$contentType Item';
  }

  @override
  String creatorItemsWithTypeAndCount(String contentType, int count) {
    return '$contentType Item ($count)';
  }

  @override
  String get creatorItemsDefault => 'Item Kreator';

  @override
  String get noItemCreator => 'Kreator ini tidak memiliki konten';

  @override
  String get noStatistic => 'Tidak ada statistik yang tersedia';

  @override
  String get failedLoadStatistic => 'Gagal memuat statistik';

  @override
  String get noResultsFound => 'Tidak ada hasil ditemukan';

  @override
  String get microsoftAuth => 'Autentikasi Microsoft';

  @override
  String get exchangingToken => 'Menukarkan kode otorisasi dengan token...';

  @override
  String authenticationFailed(String error) {
    return 'Autentikasi gagal: $error';
  }

  @override
  String get authenticationSuccessful => 'Autentikasi Berhasil!';

  @override
  String failedToExchangeToken(String error) {
    return 'Gagal menukarkan kode dengan token: $error';
  }

  @override
  String get noAuthorizationCodeReceived =>
      'Tidak ada kode otorisasi yang diterima';

  @override
  String get noNewKeysCopy => 'Tidak ada keys baru untuk disalin';

  @override
  String get keysCopyClipboard => 'Keys disalin ke clipboard!';

  @override
  String get noNewKeysShare => 'Tidak ada keys baru untuk dibagikan';

  @override
  String get keysShared => 'Keys berhasil dibagikan!';

  @override
  String get authCheck => 'Memeriksa autentikasi yang ada...';

  @override
  String get alreadyAuth => 'Sudah terautentikasi!';

  @override
  String get readyAuth => 'Siap untuk autentikasi';

  @override
  String get authURL => 'Autentikasi dengan URL';

  @override
  String get completeAuthButton => 'Selesaikan Autentikasi';

  @override
  String get openAuthPageButton => 'Buka Halaman Autentikasi';

  @override
  String get completeAuth =>
      'Selesaikan autentikasi di browser kamu. Kamu akan dialihkan kembali ke aplikasi.';

  @override
  String get copyUrl => 'Salin URL';

  @override
  String get authPageFail => 'Tidak dapat membuka halaman autentikasi';

  @override
  String get logout => 'Keluar...';

  @override
  String get logoutOk => 'Berhasil keluar';

  @override
  String get usingCachedSession => 'Menggunakan sesi cache...';

  @override
  String get loadingMinecraftKeys => 'Memuat keys Minecraft...';

  @override
  String get requestingXboxLiveToken => 'Meminta token Xbox Live...';

  @override
  String get loggingInToPlayFab => 'Masuk ke PlayFab...';

  @override
  String get gettingUserInformation => 'Mendapatkan informasi pengguna...';

  @override
  String get startingMinecraftSession => 'Memulai sesi Minecraft...';

  @override
  String get loadingMinecraftInventory => 'Memuat inventori Minecraft...';

  @override
  String successfullyLoadedKeys(int keyCount) {
    return 'Berhasil memuat $keyCount keys!';
  }

  @override
  String errorLoadingKeys(String error) {
    return 'Gagal memuat keys: $error';
  }

  @override
  String get copyClipboard => 'Disalin ke clipboard';

  @override
  String get authOk => 'Terautentikasi';

  @override
  String get authNotOk => 'Tidak Terautentikasi';

  @override
  String get urlAuth => 'URL Autentikasi';

  @override
  String get loadedKeys => 'Keys yang Dimuat';

  @override
  String get exportNewKeys => 'Ekspor hanya keys baru';

  @override
  String get loadKeysButton => 'Muat Keys';

  @override
  String get logoutButton => 'Keluar';

  @override
  String get startAuthButton => 'Mulai Autentikasi';

  @override
  String get greetings => 'Hai ';

  @override
  String get copy => 'Salin';

  @override
  String get save => 'Simpan';

  @override
  String get share => 'Bagikan';

  @override
  String get keysSaved => 'Keys berhasil disimpan';

  @override
  String get startingDownload => 'Memulai unduhan...';

  @override
  String get downloadsCompleted => 'Unduhan selesai';

  @override
  String get completed => 'Selesai!';

  @override
  String get downloadFailed => 'Unduhan gagal';

  @override
  String get downloading => 'Mengunduh';

  @override
  String get processing => 'Memproses';

  @override
  String get extractingZipFile => 'Mengekstrak file zip...';

  @override
  String get decryptingContents => 'Mendekripsi konten...';

  @override
  String get compressingPack => 'Mengompres paket...';

  @override
  String get cleaningUp => 'Membersihkan...';

  @override
  String get showAll => 'Tampilkan semua';

  @override
  String get onlyAvailable => 'Hanya yang tersedia';

  @override
  String get onlyNotAvailable => 'Hanya yang tidak tersedia';

  @override
  String get customColor => 'Warna Kustom';

  @override
  String get changeCustomColor => 'Ketuk untuk mengubah warna kustom Anda';

  @override
  String get createCustomColor => 'Buat skema warna Anda sendiri';

  @override
  String get pickColor => 'Pilih Warna';

  @override
  String get selectColor => 'Pilih';

  @override
  String get images => 'Gambar';

  @override
  String get saveToPng => 'Simpan ke PNG';

  @override
  String get saveToGallery => 'Simpan ke Galeri';

  @override
  String get compression => 'Kompresi';

  @override
  String get normalCompression => 'Kompresi Normal';

  @override
  String get noCompression => 'Tanpa Kompresi';

  @override
  String get copyUUID => 'Salin UUID';

  @override
  String get openInMinecraft => 'Buka di Minecraft';

  @override
  String get creator => 'Kreator';

  @override
  String get addToCart => 'Tambahkan ke Keranjang';

  @override
  String get removeFromCart => 'Hapus dari Keranjang';

  @override
  String get addedToCart => 'Ditambahkan ke keranjang';

  @override
  String get removedFromCart => 'Dihapus dari keranjang';

  @override
  String get authRequired => 'Autentikasi diperlukan';

  @override
  String get authRequiredDesc =>
      'Kamu harus terautentikasi sepenuhnya untuk melihat keranjang kamu. Silakan autentikasi dari halaman Login Akun.';

  @override
  String get newUpdate => 'Pembaruan Baru';

  @override
  String get newDlc => 'DLC Baru';

  @override
  String get hidden => 'Tersembunyi';

  @override
  String get persona => 'Persona';

  @override
  String get skins => 'Skin';

  @override
  String get mashups => 'Mashup';

  @override
  String get worlds => 'Dunia';

  @override
  String get textures => 'Tekstur';

  @override
  String get addons => 'Add-On';

  @override
  String get capes => 'Cape';

  @override
  String get vibrantVisuals => 'Vibrant Visuals';

  @override
  String get favorites => 'Favorit';

  @override
  String get unfiltered => 'Tanpa Filter';

  @override
  String get sorting => 'Urutkan';

  @override
  String get type => 'Tipe';

  @override
  String get newFilter => 'Baru';

  @override
  String get other => 'Lainnya';

  @override
  String get newest => 'Terbaru';

  @override
  String get oldest => 'Terlama';

  @override
  String get mostRated => 'Paling Banyak Dinilai';

  @override
  String get leastRated => 'Paling Sedikit Dinilai';

  @override
  String get menu => 'Menu';

  @override
  String imageSavedToGallery(String filePath) {
    return 'Gambar disimpan ke galeri: $filePath';
  }

  @override
  String get vibrantVisualEnhanced => 'Vibrant Visuals Enhanced';

  @override
  String get uuidCopied => 'UUID disalin ke clipboard';

  @override
  String get scrollRight => 'Geser ke kanan';

  @override
  String get scrollLeft => 'Geser ke kiri';

  @override
  String get previousImage => 'Gambar sebelumnya';

  @override
  String get nextImage => 'Gambar berikutnya';

  @override
  String get favoriteEmpty => 'Daftar favorit kamu kosong';

  @override
  String get favoriteDescription =>
      'Ketuk ikon hati di halaman detail item mana pun untuk menambahkannya ke favorit dan bangun koleksi kamu';

  @override
  String get removeFromFavorites => 'Hapus dari favorit';

  @override
  String get addToFavorites => 'Tambahkan ke favorit';

  @override
  String get addedToFavorites => 'Ditambahkan ke favorit';

  @override
  String get removedFromFavorites => 'Dihapus dari favorit';

  @override
  String get noNewKeysFoundToSave =>
      'Tidak ada keys baru ditemukan untuk disimpan';

  @override
  String get keysSavedSuccessfully =>
      'Keys berhasil disimpan ke dalam folder Kyzen.';

  @override
  String get entitlementKeys => 'Entitlement Keys';

  @override
  String get searchBoughContent =>
      'Cari konten Minecraft yang telah kamu beli.';

  @override
  String get saveKeys => 'Simpan Keys';

  @override
  String get refresh => 'Segarkan';

  @override
  String get searchKeys => 'Cari Keys';

  @override
  String get loadSkinPersona => 'Muat SkinPack/Persona';

  @override
  String get descriptionSkinPersona =>
      'Sertakan skinpack dan persona dalam daftar';

  @override
  String get loadOnlyNewKeys => 'Muat hanya keys baru';

  @override
  String get descriptionLoadOnlyNewKeys =>
      'Muat hanya konten yang tidak ada pada database keys aplikasi';

  @override
  String get descriptionExportNewKeys =>
      'Apakah \"simpan keys\" seharusnya hanya mengekspor keys baru';

  @override
  String processedEntitlementKeys(int countFiles, int countKeys) {
    return 'Berhasil Diproses ($countFiles file, $countKeys keys)';
  }

  @override
  String get noResultsYet => 'Belum ada hasil';

  @override
  String get clickSearchKeysToLoadContent =>
      'Klik \"Cari Keys\" untuk memuat konten kamu';

  @override
  String get tryadifferentSearch => 'Coba kata kunci pencarian yang berbeda';

  @override
  String get minecraftNotInstalled =>
      'Tidak ditemukan jalur instalasi Minecraft yang valid. Pastikan Minecraft Bedrock Edition (UWP atau GDK) telah terinstal dan telah dijalankan setidaknya sekali.';

  @override
  String get processingError => 'Kesalahan Pemrosesan';

  @override
  String get dismiss => 'Tutup';

  @override
  String get failedFiles => 'File Gagal:';

  @override
  String get minecraftFont => 'Font Minecraft';

  @override
  String get usingMinecraftFont => 'Menggunakan gaya font Minecraft';

  @override
  String get usingDefaultFont => 'Menggunakan font default';

  @override
  String get dlcLanguage => 'Bahasa DLC';

  @override
  String get dlcLangInfo => 'Info Bahasa DLC';

  @override
  String get dlcLangInfoText =>
      'Perlu diketahui bahwa beberapa DLC mungkin tidak memiliki terjemahan yang tersedia. Ini sepenuhnya tergantung pada marketplace dan bukan oleh aplikasi.';

  @override
  String get pageSize => 'Ukuran Halaman';

  @override
  String get pageSizeInfo => 'Info Ukuran Halaman';

  @override
  String get pageSizeInfoText =>
      'Mengontrol berapa banyak item yang dimuat sekaligus.\n\n • Nilai lebih rendah: Lebih baik untuk koneksi lemah (lebih sering meminta)\n • Nilai lebih tinggi: Lebih baik untuk koneksi cepat (lebih sedikit meminta)\n\nSemua hasil tetap dapat diakses berapa pun ukuran halamannya. Item tambahan akan dimuat secara otomatis saat Anda mencapai bagian bawah daftar.';

  @override
  String get selectDlcLanguage => 'Pilih Bahasa DLC';

  @override
  String get downloadPathUpdated => 'Jalur unduhan diperbarui';

  @override
  String get downloadPathReset => 'Jalur unduhan diatur ulang ke default';

  @override
  String get resetDefaults => 'Atur Ulang ke Default';

  @override
  String get chooseFolder => 'Pilih folder';

  @override
  String get downloadPath => 'Jalur Unduhan';

  @override
  String get version => 'Versi';

  @override
  String get purchasing => 'Membeli...';

  @override
  String get failedPurchase => 'Gagal membeli';

  @override
  String get allItemsSuccessfullyPurchased => 'Semua item berhasil dibeli!';

  @override
  String insufficientFunds(int insufficientFundsItems) {
    return 'Dana tidak mencukupi untuk $insufficientFundsItems item';
  }

  @override
  String get somePurchasesFailed => 'Beberapa pembelian gagal';

  @override
  String numItemsAreNotPurchasable(int numItems) {
    return '$numItems item tidak dapat dibeli';
  }

  @override
  String get purchaseComplete => 'Pembelian selesai';

  @override
  String get confirmPurchase => 'Konfirmasi Pembelian';

  @override
  String confirmPurchaseMessage(String itemsText) {
    return 'Apakah Anda yakin ingin membeli $itemsText?';
  }

  @override
  String get totalPrice => 'Total Harga:';

  @override
  String get purchaseResults => 'Hasil Pembelian';

  @override
  String successfullyPurchased(int successItems) {
    return 'Berhasil dibeli: $successItems item';
  }

  @override
  String alreadyOwnded(int alreadyOwnedItems) {
    return 'Sudah dimiliki: $alreadyOwnedItems item';
  }

  @override
  String numItemsNotPurchasable(int notPurchasableItems) {
    return 'Tidak dapat dibeli: $notPurchasableItems item';
  }

  @override
  String numItemsInsufficientFunds(int insufficientFundsItems) {
    return 'Dana tidak mencukupi: $insufficientFundsItems item';
  }

  @override
  String numItemsFailed(int failedItemsCount) {
    return 'Pembelian gagal: $failedItemsCount item';
  }

  @override
  String get clearCart => 'Kosongkan Keranjang';

  @override
  String get clearCartConfirmation =>
      'Apakah Anda yakin ingin menghapus semua item dari keranjang?';

  @override
  String cartTitleNum(int count) {
    return 'Keranjang ($count)';
  }

  @override
  String get cartisEmpty => 'Keranjang kamu kosong';

  @override
  String get cartEmptyDescription =>
      'Ketuk ikon keranjang di halaman detail item mana pun untuk menambahkannya ke keranjang dan membelinya';

  @override
  String get purchasingInProgress => 'Sedang membeli...';

  @override
  String purchaseAllnum(int count) {
    return 'Beli Semua ($count)';
  }

  @override
  String get nowNewdlcFound => 'Tidak Ada DLC Baru Ditemukan';

  @override
  String get nowNewDlcFoundDescription =>
      'Semua DLC sudah ada dalam database aplikasi';

  @override
  String get noDlcFound => 'Tidak Ada DLC Ditemukan';

  @override
  String get noDlcAvailable => 'Tidak ada konten DLC yang tersedia';

  @override
  String get openDlcsList => 'Buka DLC';

  @override
  String get appUpdates => 'Pembaruan Aplikasi';

  @override
  String get appUpdatesDescription =>
      'Lihat apa yang baru dalam versi terbaru aplikasi';

  @override
  String get socials => 'Media Sosial';

  @override
  String get selectApp => 'Pilih Aplikasi';

  @override
  String get noAppsFound => 'Tidak ada aplikasi ditemukan';

  @override
  String get errorLoadingDlcs => 'Kesalahan saat memuat DLC';

  @override
  String get dlcs => 'DLC';

  @override
  String errorSavingKeys(String error) {
    return 'Kesalahan saat menyimpan keys: $error';
  }

  @override
  String errorOpeningAuthPage(String error) {
    return 'Kesalahan saat membuka halaman autentikasi: $error';
  }

  @override
  String get gettingEntityToken => 'Mendapatkan token entity...';

  @override
  String get loadingMinecoinBalance => 'Memuat saldo Minecoin...';

  @override
  String get completeAuthFirst =>
      'Harap selesaikan autentikasi terlebih dahulu';

  @override
  String get sessionExpired => 'Sesi kedaluwarsa. Silakan coba lagi.';

  @override
  String get accessDenied => 'Akses ditolak. Silakan autentikasi ulang.';

  @override
  String get connectionTimeout =>
      'Koneksi timeout. Periksa internet Anda dan coba lagi.';

  @override
  String get serverError =>
      'Kesalahan server. Silakan coba lagi beberapa saat.';

  @override
  String get backToSettings => 'Kembali ke Pengaturan';

  @override
  String errorInitializingCart(String error) {
    return 'Kesalahan saat menginisialisasi keranjang: $error';
  }

  @override
  String errorLoadingCartItems(String error) {
    return 'Kesalahan saat memuat item keranjang: $error';
  }

  @override
  String failedLoadMoreItems(String error) {
    return 'Gagal memuat lebih banyak item: $error';
  }

  @override
  String errorSavingLog(String error) {
    return 'Kesalahan saat menyimpan log: $error';
  }

  @override
  String get failedToDeleteFile => 'Gagal menghapus file';

  @override
  String failedToShareFile(String error) {
    return 'Gagal membagikan file: $error';
  }

  @override
  String get personaWarning =>
      'Item Persona tidak dapat diimpor ke dalam game (seperti emotes, kosmetik, dan cape)';

  @override
  String get initializingMcDec => 'Menginisialisasi McDec...';

  @override
  String failedToSaveKeys(String error) {
    return 'Gagal menyimpan keys: $error';
  }

  @override
  String get itemDetailsTitle => 'Detail Item';

  @override
  String byCreator(String creator) {
    return 'oleh $creator';
  }

  @override
  String get couldNotLoadSocials =>
      'Tidak dapat memuat tautan media sosial, menggunakan default';

  @override
  String get sdCardExternalStorage => 'Kartu SD / Penyimpanan Eksternal';

  @override
  String get customLocation => 'Lokasi Kustom';

  @override
  String couldNotOpenLink(String error) {
    return 'Tidak dapat membuka tautan: $error';
  }

  @override
  String get minecraftPackage => 'Paket Minecraft';

  @override
  String get freeDroidWarnMessage =>
      'Google telah mengumumkan bahwa mulai tahun 2026/2027, semua aplikasi pada perangkat Android bersertifikat akan mewajibkan pengembang untuk menyerahkan data identitas pribadi mereka langsung ke Google. Karena pengembang aplikasi ini tidak setuju dengan persyaratan tersebut, aplikasi ini tidak akan berfungsi lagi pada perangkat Android bersertifikat setelah waktu itu.';

  @override
  String get freeDroidWarnDetails => 'Detail';

  @override
  String get freeDroidWarnSolution => 'Solusi';

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
