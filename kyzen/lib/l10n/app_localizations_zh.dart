// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get home => '首页';

  @override
  String get downloads => '下载';

  @override
  String get settings => '设置';

  @override
  String get selectLanguage => '选择语言';

  @override
  String get language => '语言';

  @override
  String get download => '下载';

  @override
  String get hintText => '搜索...';

  @override
  String get default1 => '默认';

  @override
  String get creators => '创作者';

  @override
  String get checkingKeys => '检查密钥中';

  @override
  String get apiLogin => 'API 登录';

  @override
  String addedNewKeys(int keyCount) {
    return '已添加 $keyCount 个新密钥';
  }

  @override
  String get noResult => '未找到结果';

  @override
  String get open => '打开';

  @override
  String get clear => '清除';

  @override
  String get retry => '重试';

  @override
  String get ok => 'OK';

  @override
  String queuePosition(int count) {
    return '排队中 (位置 #$count)';
  }

  @override
  String queuePosition2(int count) {
    return '排队中 #$count';
  }

  @override
  String imageSaved(String filePath) {
    return '图片已保存至 $filePath';
  }

  @override
  String errorDownloadingImage(String error) {
    return '图片下载失败: $error';
  }

  @override
  String get changelog => '更新日志';

  @override
  String get downloaded => '已下载';

  @override
  String get retryDownload => '重新下载';

  @override
  String get downloadImage => '下载图片';

  @override
  String get downloadImageQuestion => '下载此图片?';

  @override
  String get cancel => '取消';

  @override
  String get trailer => '观看预告片';

  @override
  String trailerError(String error) {
    return '无法播放预告片: $error';
  }

  @override
  String get appearance => '外观';

  @override
  String get darkMode => '深色模式';

  @override
  String get darkEnabled => '深色主题已启用';

  @override
  String get lightEnabled => '浅色主题已启用';

  @override
  String get colorScheme => '配色方案';

  @override
  String get defaultColor => '默认';

  @override
  String get defaultPurple => '默认 (紫色)';

  @override
  String get colorSchemeBlue => '蓝色';

  @override
  String get colorSchemeGreen => '绿色';

  @override
  String get colorSchemeOrange => '橙色';

  @override
  String get colorSchemeRed => '红色';

  @override
  String get colorSchemeTeal => '青绿色';

  @override
  String get colorSchemePink => '粉色';

  @override
  String get colorSchemeLime => '黄绿色';

  @override
  String get filters => '筛选器';

  @override
  String get filter => '筛选器:';

  @override
  String get showSkins => '显示皮肤';

  @override
  String get keys => '密钥';

  @override
  String get autoUpdate => '自动更新';

  @override
  String get customDb => '自定义数据库';

  @override
  String get accountLogin => '账户登录';

  @override
  String get extras => '扩展功能';

  @override
  String get cache => '缓存';

  @override
  String cacheCleared(String size) {
    return '已清除 $size MB 缓存';
  }

  @override
  String get faq => '常见问题解答';

  @override
  String get faqUppercase => '常见问题解答';

  @override
  String get terminal => '终端';

  @override
  String get faqQuestion1 => '请添加这个包的密钥！';

  @override
  String get faqQuestion2 => '密钥什么时候更新?';

  @override
  String get faqQuestion3 => '加密和未加密有什么区别?';

  @override
  String get faqQuestion4 => '哪里能找到下载的包?';

  @override
  String get faqQuestion5 => '什么是 keys.tsv?';

  @override
  String get faqQuestion6 => '我如何使用角色装扮物品？';

  @override
  String get faqQuestion7 => '为什么有些导入到游戏的皮肤包出现损坏？';

  @override
  String get faqQuestion8 => '“账户登录”页面是做什么的？';

  @override
  String get faqQuestion9 => '勾选标记是什么意思？';

  @override
  String get faqAnswer1 =>
      '获取密钥并非魔法：仍需有人购买市场包并分享密钥。没有人购买就不会有解密密钥，这是唯一获取方式。请耐心等待或自行购买。';

  @override
  String get faqAnswer2 => '当我们决定更新时。';

  @override
  String get faqAnswer3 =>
      '加密是将文件转为乱码的过程，没有密钥无法读取。加密的 Minecraft 内容无法使用。\n\n未加密是使用密钥还原内容的过程，此时 Minecraft 内容可正常使用。';

  @override
  String get faqAnswer4 => '已下载的市场包位于 Download/Kyzen 目录';

  @override
  String get faqAnswer5 => '这是存储市场包的 UUID 及对应解密密钥的文件。无解密密钥时下载的市场包将无法使用。';

  @override
  String get faqAnswer6 => '做不到。虽然有一些方法，但考虑到其复杂性，并不可行。';

  @override
  String get faqAnswer7 =>
      '一些皮肤包(尤其是联动合作项目)使用自定义模型，Minecraft不允许正常使用，除非你购买该皮肤包。你可以通过检查皮肤包中是否存在文件“geometry.json ”来判断这个皮肤包是否使用自定义模型。请记住，这个问题与Kyzen没有任何关系。';

  @override
  String get faqAnswer8 =>
      '“账户登录”页面允许您使用Microsoft帐户进行身份验证，以便直接从您的库存中加载Minecraft密钥。当Kyzen目前没有特定市场包的可用密钥，但您的帐户中有该密钥时，这非常有用，一旦您的密钥被加载，该市场包将显示为可用以允许下载。请注意，这些密钥会自动上传到我们的数据库，之后它们会与Kyzen的主密钥数据库合并，这样每个人都可以享受新的市场包，所以如果你想贡献一份力量，请使用这个功能。';

  @override
  String get faqAnswer9Checkmark => '此市场包的密钥已可用';

  @override
  String get faqAnswer9NoCheckmark => '该APP应用当前没有此市场包的密钥';

  @override
  String get faqAnswer9ExtraInfo => '需要密钥才能解锁市场包';

  @override
  String get faqQuestionDownload => '为什么下载按钮不可用？';

  @override
  String get faqAnswerDownload => '解锁此市场包的密钥不可用，请耐心等待或直接购买它。';

  @override
  String get faqQuestionKey => '我怎么才能拿到密钥？';

  @override
  String get faqAnswerKey =>
      '在你的账户上购买该市场包，然后前往 设置 > 账户登录 > 点击‘开始认证’ > 点击‘加载密钥’，现在点击‘分享’并将密钥文件分享到 Bluecoin 聊天群，这些密钥将被添加到应用数据库中。如果你无法将密钥文件分享到群里，不用担心，密钥会自动上传到数据库。';

  @override
  String get faqMoreHelp => '更多帮助';

  @override
  String get faqNotAdlc => '非市场包内容';

  @override
  String get faqNotAdlcDescription => '此物品不是市场包';

  @override
  String get faqServerContent => '服务器内容';

  @override
  String get faqServerContentDescription => '此物品仅限特定服务器使用，无法直接下载。';

  @override
  String get fileDeleted => '文件已删除';

  @override
  String get storedFiles => '已存文件';

  @override
  String get refreshFiles => '刷新文件';

  @override
  String get deleteFile => '删除文件';

  @override
  String deleteFileConfirmation(String fileName) {
    return '确定删除 $fileName?';
  }

  @override
  String get cancelUppercase => '取消';

  @override
  String get deleteUppercase => '删除';

  @override
  String get currentDownload => '当前下载';

  @override
  String get noActiveDownloads => '没有正在进行的下载';

  @override
  String get completedDownloads => '已完成下载';

  @override
  String get clearAll => '全部清除';

  @override
  String get importToMc => '导入到 Minecraft';

  @override
  String get openFileinExplorer => '在文件资源管理器中打开';

  @override
  String get shareFile => '分享文件';

  @override
  String get debugTerminal => '调试终端';

  @override
  String get clearLogs => '清除日志';

  @override
  String get noLogs => '暂无日志...';

  @override
  String get saveLogs => '保存日志';

  @override
  String logsSaved(String filePath) {
    return '日志已保存到 $filePath';
  }

  @override
  String get selectingFile => '选择文件中...';

  @override
  String get processingFile => '处理文件中...';

  @override
  String get fileProcessed => '文件处理成功！';

  @override
  String get noFileSelected => '未选择文件';

  @override
  String customKeysLoaded(int count) {
    return '已加载 $count 个自定义密钥';
  }

  @override
  String get noCustomKeysLoaded => '未加载自定义密钥';

  @override
  String get importFileFormat => '导入 UUID=KEY 格式文件';

  @override
  String creatorItemsWithType(String contentType) {
    return '$contentType 项目';
  }

  @override
  String creatorItemsWithTypeAndCount(String contentType, int count) {
    return '$contentType 项目 ($count)';
  }

  @override
  String get creatorItemsDefault => '创作者项目';

  @override
  String get noItemCreator => '该创作者暂无内容';

  @override
  String get noStatistic => '暂无统计数据';

  @override
  String get failedLoadStatistic => '统计信息加载失败';

  @override
  String get noResultsFound => '未找到结果';

  @override
  String get microsoftAuth => 'Microsoft 身份验证';

  @override
  String get exchangingToken => '兑换授权令牌中...';

  @override
  String authenticationFailed(String error) {
    return '身份验证失败: $error';
  }

  @override
  String get authenticationSuccessful => '身份验证成功！';

  @override
  String failedToExchangeToken(String error) {
    return '令牌兑换失败: $error';
  }

  @override
  String get noAuthorizationCodeReceived => '未收到授权码';

  @override
  String get noNewKeysCopy => '无新密钥可复制';

  @override
  String get keysCopyClipboard => '密钥已复制到剪贴板！';

  @override
  String get noNewKeysShare => '无新密钥可分享';

  @override
  String get keysShared => '密钥分享成功！';

  @override
  String get authCheck => '正在检查现有身份验证...';

  @override
  String get alreadyAuth => '已通过身份验证！';

  @override
  String get readyAuth => '准备进行身份验证';

  @override
  String get authURL => '使用 URL 进行身份验证';

  @override
  String get completeAuthButton => '完整身份验证';

  @override
  String get openAuthPageButton => '打开授权页面';

  @override
  String get completeAuth => '请在浏览器完成身份验证，完成后您将被重定向回应用程序。';

  @override
  String get copyUrl => '复制链接';

  @override
  String get authPageFail => '无法打开身份验证页面';

  @override
  String get logout => '退出登录中...';

  @override
  String get logoutOk => '已成功登出';

  @override
  String get usingCachedSession => '使用缓存会话中...';

  @override
  String get loadingMinecraftKeys => '加载 Minecraft 密钥中...';

  @override
  String get requestingXboxLiveToken => '请求 Xbox Live 令牌中...';

  @override
  String get loggingInToPlayFab => '登录 PlayFab 中...';

  @override
  String get gettingUserInformation => '获取用户信息中...';

  @override
  String get startingMinecraftSession => '启动 Minecraft 会话中...';

  @override
  String get loadingMinecraftInventory => '加载 Minecraft 库存中...';

  @override
  String successfullyLoadedKeys(int keyCount) {
    return '成功加载 $keyCount 个密钥！';
  }

  @override
  String errorLoadingKeys(String error) {
    return '密钥加载失败: $error';
  }

  @override
  String get copyClipboard => '已复制到剪贴板';

  @override
  String get authOk => '已验证';

  @override
  String get authNotOk => '未经验证';

  @override
  String get urlAuth => '身份验证URL链接';

  @override
  String get loadedKeys => '已加载密钥';

  @override
  String get exportNewKeys => '仅导出新密钥';

  @override
  String get loadKeysButton => '加载密钥';

  @override
  String get logoutButton => '退出登录';

  @override
  String get startAuthButton => '开始身份验证';

  @override
  String get greetings => '你好';

  @override
  String get copy => '复制';

  @override
  String get save => '保存';

  @override
  String get share => '分享';

  @override
  String get keysSaved => '密钥已成功保存';

  @override
  String get startingDownload => '开始下载...';

  @override
  String get downloadsCompleted => '下载已完成';

  @override
  String get completed => '已完成！';

  @override
  String get downloadFailed => '下载失败';

  @override
  String get downloading => '下载中';

  @override
  String get processing => '处理中';

  @override
  String get extractingZipFile => '解压 ZIP 文件中...';

  @override
  String get decryptingContents => '解密内容中...';

  @override
  String get compressingPack => '压缩资源包中...';

  @override
  String get cleaningUp => '清理中...';

  @override
  String get showAll => '显示全部';

  @override
  String get onlyAvailable => '仅显示可用';

  @override
  String get onlyNotAvailable => '仅显示不可用';

  @override
  String get customColor => '自定义颜色';

  @override
  String get changeCustomColor => '点击更改自定义颜色';

  @override
  String get createCustomColor => '创建您自己的配色方案';

  @override
  String get pickColor => '选择颜色';

  @override
  String get selectColor => '选择';

  @override
  String get images => '图片';

  @override
  String get saveToPng => '保存为PNG格式';

  @override
  String get saveToGallery => '保存到相册';

  @override
  String get compression => '压缩';

  @override
  String get normalCompression => '正常压缩';

  @override
  String get noCompression => '无压缩';

  @override
  String get copyUUID => '复制 UUID';

  @override
  String get openInMinecraft => '在 Minecraft 中打开';

  @override
  String get creator => '创作者';

  @override
  String get addToCart => '添加到购物车';

  @override
  String get removeFromCart => '从购物车移除';

  @override
  String get addedToCart => '加入购物车';

  @override
  String get removedFromCart => '已从购物车中移除';

  @override
  String get authRequired => '需要身份验证';

  @override
  String get authRequiredDesc => '您需要完成身份验证才能查看购物车。请从账户登录页面进行身份验证。';

  @override
  String get newUpdate => '新更新';

  @override
  String get newDlc => '新市场包';

  @override
  String get hidden => '隐藏';

  @override
  String get persona => '角色装扮';

  @override
  String get skins => '皮肤';

  @override
  String get mashups => '混搭包';

  @override
  String get worlds => '世界';

  @override
  String get textures => '材质包';

  @override
  String get addons => '附加包';

  @override
  String get capes => '披风';

  @override
  String get vibrantVisuals => '灵动视效';

  @override
  String get favorites => '收藏夹';

  @override
  String get unfiltered => '未过滤';

  @override
  String get sorting => '排序';

  @override
  String get type => '类型';

  @override
  String get newFilter => '新内容';

  @override
  String get other => '其他';

  @override
  String get newest => '时间由近及远';

  @override
  String get oldest => '时间由远及近';

  @override
  String get mostRated => '评级从高到低';

  @override
  String get leastRated => '评级从低到高';

  @override
  String get menu => '菜单';

  @override
  String imageSavedToGallery(String filePath) {
    return '图片已保存到图库: $filePath';
  }

  @override
  String get vibrantVisualEnhanced => '灵动视效';

  @override
  String get uuidCopied => 'UUID已复制到剪贴板';

  @override
  String get scrollRight => '向右滚动';

  @override
  String get scrollLeft => '向左滚动';

  @override
  String get previousImage => '上一张图片';

  @override
  String get nextImage => '下一张图片';

  @override
  String get favoriteEmpty => '您的收藏夹列表是空的';

  @override
  String get favoriteDescription => '点击任意商品详情页上的心形图标，即可将其添加到收藏夹，打造您的专属收藏。';

  @override
  String get removeFromFavorites => '从收藏夹中删除';

  @override
  String get addToFavorites => '添加到收藏夹';

  @override
  String get addedToFavorites => '已添加到收藏夹';

  @override
  String get removedFromFavorites => '已从收藏夹中删除';

  @override
  String get noNewKeysFoundToSave => '没有找到要保存的密钥';

  @override
  String get keysSavedSuccessfully => '密钥已成功保存到 Kyzen 文件夹。';

  @override
  String get entitlementKeys => '授权密钥';

  @override
  String get searchBoughContent => '搜索您在Minecraft中购买的内容。';

  @override
  String get saveKeys => '保存密钥';

  @override
  String get refresh => '刷新';

  @override
  String get searchKeys => '搜索密钥';

  @override
  String get loadSkinPersona => '加载皮肤包/角色装扮';

  @override
  String get descriptionSkinPersona => '将皮肤包和角色装扮也添加到列表中';

  @override
  String get loadOnlyNewKeys => '仅加载新密钥';

  @override
  String get descriptionLoadOnlyNewKeys => '仅加载应用密钥数据库中不存在的内容';

  @override
  String get descriptionExportNewKeys => '“保存密钥”是否应该只导出新密钥';

  @override
  String processedEntitlementKeys(int countFiles, int countKeys) {
    return '已成功处理($countFiles个文件，$countKeys个密钥)';
  }

  @override
  String get noResultsYet => '暂无结果';

  @override
  String get clickSearchKeysToLoadContent => '点击“搜索密钥”加载您的内容';

  @override
  String get tryadifferentSearch => '尝试不同的搜索词';

  @override
  String get minecraftNotInstalled =>
      '找不到有效的Minecraft安装路径。请确保Minecraft基岩版(UWP或GDK)已安装，并已启动至少一次。';

  @override
  String get processingError => '处理错误';

  @override
  String get dismiss => '关闭';

  @override
  String get failedFiles => '失败的文件:';

  @override
  String get minecraftFont => 'Minecraft字体';

  @override
  String get usingMinecraftFont => '使用Minecraft风格的字体';

  @override
  String get usingDefaultFont => '使用默认字体';

  @override
  String get dlcLanguage => '市场包语言';

  @override
  String get dlcLangInfo => '市场包语言信息';

  @override
  String get dlcLangInfoText =>
      '请注意，部分市场包可能没有提供翻译版本。这完全取决于Minecraft市场，而非Kyzen应用本身。';

  @override
  String get pageSize => '页面大小';

  @override
  String get pageSizeInfo => '页面大小信息';

  @override
  String get pageSizeInfoText =>
      '控制一次加载的项目数量。\n• 值越低：越适合网络连接较弱的情况（请求频率越高）\n• 值越高：越适合网络连接较快的情况（请求频率越低）\n无论页面大小如何，所有结果始终可用。当您滚动到列表底部时，会自动加载其他项目。';

  @override
  String get selectDlcLanguage => '选择市场包语言';

  @override
  String get downloadPathUpdated => '下载路径已更新';

  @override
  String get downloadPathReset => '下载路径已重置为默认';

  @override
  String get resetDefaults => '重置为默认';

  @override
  String get chooseFolder => '选择文件夹';

  @override
  String get downloadPath => '下载路径';

  @override
  String get version => '版本';

  @override
  String get purchasing => '购买';

  @override
  String get failedPurchase => '购买失败';

  @override
  String get allItemsSuccessfullyPurchased => '所有商品购买成功';

  @override
  String insufficientFunds(int insufficientFundsItems) {
    return '资金不足，无法购买 $insufficientFundsItems 件商品';
  }

  @override
  String get somePurchasesFailed => '部分购买失败';

  @override
  String numItemsAreNotPurchasable(int numItems) {
    return '$numItems 件商品不可购买';
  }

  @override
  String get purchaseComplete => '购买已完成';

  @override
  String get confirmPurchase => '确认购买';

  @override
  String confirmPurchaseMessage(String itemsText) {
    return '您确定要购买$itemsText吗？';
  }

  @override
  String get totalPrice => '总价：';

  @override
  String get purchaseResults => '购买结果';

  @override
  String successfullyPurchased(int successItems) {
    return '已成功购买：$successItems 件商品';
  }

  @override
  String alreadyOwnded(int alreadyOwnedItems) {
    return '已拥有：$alreadyOwnedItems 件商品';
  }

  @override
  String numItemsNotPurchasable(int notPurchasableItems) {
    return '不可购买：$notPurchasableItems 件商品';
  }

  @override
  String numItemsInsufficientFunds(int insufficientFundsItems) {
    return '资金不足：$insufficientFundsItems 项';
  }

  @override
  String numItemsFailed(int failedItemsCount) {
    return '购买失败：$failedItemsCount 件商品';
  }

  @override
  String get clearCart => '清空购物车';

  @override
  String get clearCartConfirmation => '您确定要从购物车中移除所有商品吗？';

  @override
  String cartTitleNum(int count) {
    return '购物车（$count）';
  }

  @override
  String get cartisEmpty => '您的购物车是空的。';

  @override
  String get cartEmptyDescription => '点击任意商品详情页上的购物车图标，即可将其添加到购物车并购买。';

  @override
  String get purchasingInProgress => '购买...';

  @override
  String purchaseAllnum(int count) {
    return '购买全部（$count）';
  }

  @override
  String get nowNewdlcFound => '未发现新的市场包';

  @override
  String get nowNewDlcFoundDescription => '所有市场包都已存在于应用程序数据库中。';

  @override
  String get noDlcFound => '未找到市场包';

  @override
  String get noDlcAvailable => '暂无市场包内容';

  @override
  String get openDlcsList => '打开市场包';

  @override
  String get appUpdates => '应用更新';

  @override
  String get appUpdatesDescription => '看看应用最新版本新增了哪些功能。';

  @override
  String get socials => '社交媒体';

  @override
  String get selectApp => '选择APP应用';

  @override
  String get noAppsFound => '未找到APP应用';

  @override
  String get errorLoadingDlcs => '加载市场包时错误';

  @override
  String get dlcs => '市场包';

  @override
  String errorSavingKeys(String error) {
    return '保存密钥时出错: $error';
  }

  @override
  String errorOpeningAuthPage(String error) {
    return '打开认证页面时出错: $error';
  }

  @override
  String get gettingEntityToken => '获取实体令牌中......';

  @override
  String get loadingMinecoinBalance => '正在加载Minecoin余额......';

  @override
  String get completeAuthFirst => '请先完成身份验证';

  @override
  String get sessionExpired => '会话已过期，请重试。';

  @override
  String get accessDenied => '访问被拒绝，请重新认证。';

  @override
  String get connectionTimeout => '连接超时，请检查您的网络并重试。';

  @override
  String get serverError => '服务器错误，请稍后再试。';

  @override
  String get backToSettings => '返回设置';

  @override
  String errorInitializingCart(String error) {
    return '购物车初始化失败: $error';
  }

  @override
  String errorLoadingCartItems(String error) {
    return '加载购物车商品时出错: $error';
  }

  @override
  String failedLoadMoreItems(String error) {
    return '加载更多物品时失败: $error';
  }

  @override
  String errorSavingLog(String error) {
    return '保存日志时出错: $error';
  }

  @override
  String get failedToDeleteFile => '删除文件失败';

  @override
  String failedToShareFile(String error) {
    return '分享文件失败: $error';
  }

  @override
  String get personaWarning => '角色创建器装扮内容无法导入到游戏中（例如表情、外观和披风）';

  @override
  String get initializingMcDec => '正在初始化解密器......';

  @override
  String failedToSaveKeys(String error) {
    return '保存密钥失败: $error';
  }

  @override
  String get itemDetailsTitle => '商品详情';

  @override
  String byCreator(String creator) {
    return '由 $creator 制作';
  }

  @override
  String get couldNotLoadSocials => '无法加载社交链接，正在使用默认设置';

  @override
  String get sdCardExternalStorage => 'SD卡或外部存储';

  @override
  String get customLocation => '自定义位置';

  @override
  String couldNotOpenLink(String error) {
    return '无法打开链接: $error';
  }

  @override
  String get minecraftPackage => 'Minecraft包装';

  @override
  String get freeDroidWarnMessage =>
      'Google（谷歌）宣布，自 2026/2027 年起，所有在经过 Google 认证的 Android 设备上运行的应用，其开发者都必须直接向 Google 提交个人身份信息。由于本应用的开发者不同意此项要求，届时本应用将无法在经过 Google 认证的 Android 设备上继续运行。';

  @override
  String get freeDroidWarnDetails => '详情';

  @override
  String get freeDroidWarnSolution => '解决方案';

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
