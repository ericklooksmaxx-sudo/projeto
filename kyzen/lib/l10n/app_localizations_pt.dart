// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get home => 'Início';

  @override
  String get downloads => 'Downloads';

  @override
  String get settings => 'Configurações';

  @override
  String get selectLanguage => 'Selecionar Idioma';

  @override
  String get language => 'Idioma';

  @override
  String get download => 'Download';

  @override
  String get hintText => 'Pesquisar...';

  @override
  String get default1 => 'Padrão';

  @override
  String get creators => 'Criadores';

  @override
  String get checkingKeys => 'Checando chaves';

  @override
  String get apiLogin => 'Login via API';

  @override
  String addedNewKeys(int keyCount) {
    return 'Adicionadas $keyCount novas chaves';
  }

  @override
  String get noResult => 'Nenhum resultado encontrado';

  @override
  String get open => 'Abrir';

  @override
  String get clear => 'Limpar';

  @override
  String get retry => 'Tentar novamente';

  @override
  String get ok => 'OK';

  @override
  String queuePosition(int count) {
    return 'Em fila (Posição #$count)';
  }

  @override
  String queuePosition2(int count) {
    return 'Em fila #$count)';
  }

  @override
  String imageSaved(String filePath) {
    return 'Imagem salva em $filePath';
  }

  @override
  String errorDownloadingImage(String error) {
    return 'Erro ao baixar a imagem: $error';
  }

  @override
  String get changelog => 'Registro de alterações';

  @override
  String get downloaded => 'Baixado';

  @override
  String get retryDownload => 'Tentar novamente o download';

  @override
  String get downloadImage => 'Baixar imagem';

  @override
  String get downloadImageQuestion => 'Fazer o download desta imagem?';

  @override
  String get cancel => 'Cancelar';

  @override
  String get trailer => 'Assista ao trailer';

  @override
  String trailerError(String error) {
    return 'Não foi possível abrir o trailer: $error';
  }

  @override
  String get appearance => 'Aparência';

  @override
  String get darkMode => 'Modo Escuro';

  @override
  String get darkEnabled => 'Modo escuro ativado';

  @override
  String get lightEnabled => 'Modo claro ativado';

  @override
  String get colorScheme => 'Esquema de cores';

  @override
  String get defaultColor => 'Padrão';

  @override
  String get defaultPurple => 'Padrão (Roxo)';

  @override
  String get colorSchemeBlue => 'Azul';

  @override
  String get colorSchemeGreen => 'Verde';

  @override
  String get colorSchemeOrange => 'Laranja';

  @override
  String get colorSchemeRed => 'Vermelho';

  @override
  String get colorSchemeTeal => 'Verde-azulado';

  @override
  String get colorSchemePink => 'Rosa';

  @override
  String get colorSchemeLime => 'Verde-limão';

  @override
  String get filters => 'Filtros';

  @override
  String get filter => 'Filtro:';

  @override
  String get showSkins => 'Mostrar skins';

  @override
  String get keys => 'Chaves';

  @override
  String get autoUpdate => 'Atualizar automaticamente';

  @override
  String get customDb => 'Banco de dados personalizado';

  @override
  String get accountLogin => 'Login da conta';

  @override
  String get extras => 'Extras';

  @override
  String get cache => 'Cache';

  @override
  String cacheCleared(String size) {
    return 'Limpou $size MB de cache';
  }

  @override
  String get faq => 'Perguntas frequentes';

  @override
  String get faqUppercase => 'Perguntas frequentes';

  @override
  String get terminal => 'Terminal';

  @override
  String get faqQuestion1 =>
      'Por favor, adicione as chaves para este e aquele pacote!';

  @override
  String get faqQuestion2 => 'Quando as chaves serão atualizadas?';

  @override
  String get faqQuestion3 =>
      'Qual a diferença entre criptografado e descriptografado?';

  @override
  String get faqQuestion4 => 'Onde posso encontrar os pacotes baixados?';

  @override
  String get faqQuestion5 => 'O que é keys.tsv?';

  @override
  String get faqQuestion6 => 'Como posso usar itens de Persona?';

  @override
  String get faqQuestion7 =>
      'Por que alguns pacotes de skins parecem estar corrompidos?';

  @override
  String get faqQuestion8 =>
      'Qual é a finalidade da página \"Login da Conta\"?';

  @override
  String get faqQuestion9 => 'O que significa o símbolo de visto?';

  @override
  String get faqAnswer1 =>
      'O processo de obtenção das chaves não é mágico: alguém ainda precisa comprar o pacote e compartilhar as chaves conosco. Sem que alguém o comprasse, não haveria chaves de descriptografia. Não é possível obtê-las de outra forma. Aguarde pacientemente ou compre o pacote.';

  @override
  String get faqAnswer2 => 'Assim que decidirmos.';

  @override
  String get faqAnswer3 =>
      'Criptografado: significa transformar o arquivo em palavras embaralhadas que parecem um amontoado de caracteres sem sentido. Ninguém consegue lê-lo sem uma chave especial. Conteúdo criptografado do Minecraft é impossível de jogar.\n\nDescriptografado: significa usar a chave especial para transformar o amontoado de caracteres sem sentido de volta ao conteúdo original. Agora o conteúdo do Minecraft pode ser usado.';

  @override
  String get faqAnswer4 =>
      'Você pode encontrar os pacotes em Download/Kyzen';

  @override
  String get faqAnswer5 =>
      'É um arquivo que armazena os UUIDs dos pacotes com suas respectivas chaves de descriptografia. Sem as chaves de descriptografia, os pacotes baixados não poderiam ser jogados.';

  @override
  String get faqAnswer6 =>
      'Não é possível. Existem alguns métodos, mas dada a complexidade envolvida, não é viável.';

  @override
  String get faqAnswer7 =>
      'Alguns pacotes de skins (especialmente colaborações com franquias) usam geometria personalizada, cujo uso normal o Minecraft não permite, a menos que você compre o pacote. Você pode verificar se um pacote de skins usa geometria personalizada verificando se o arquivo \"geometry.json\" existe no pacote. Lembre-se de que esse problema não está relacionado à ferramenta de forma alguma.';

  @override
  String get faqAnswer8 =>
      'A página de login da conta permite que você se autentique com sua conta Microsoft para carregar diretamente suas chaves do Minecraft do seu inventário. Isso é útil quando o Kyzen não tem uma chave disponível para um DLC específico, mas você o possui em sua conta. Assim que suas chaves forem carregadas, o DLC aparecerá disponível para download. Observe que as chaves são enviadas automaticamente para nosso banco de dados, onde serão posteriormente integradas ao banco de dados principal de chaves do Kyzen para que todos possam aproveitar o novo DLC. Portanto, use este recurso se quiser contribuir.';

  @override
  String get faqAnswer9Checkmark => 'A chave para este DLC já está disponível.';

  @override
  String get faqAnswer9NoCheckmark =>
      'O aplicativo não possui atualmente a chave para este DLC.';

  @override
  String get faqAnswer9ExtraInfo =>
      'São necessárias chaves para desbloquear os DLCs.';

  @override
  String get faqQuestionDownload =>
      'Por que o botão de download está indisponível?';

  @override
  String get faqAnswerDownload =>
      'A chave para desbloquear este DLC não está disponível. Aguarde pacientemente ou compre-o.';

  @override
  String get faqQuestionKey => 'Como faço para obter a chave?';

  @override
  String get faqAnswerKey =>
      'Compre o DLC na sua conta e depois vá em Configurações > Login da conta > Clique em \'Iniciar autenticação\' > clique em \'Carregar chaves\', agora clique em \'Compartilhar\' e compartilhe os arquivos de chave no chat do Bluecoin. As chaves serão adicionadas ao banco de dados do aplicativo. Se você não conseguir compartilhar o arquivo de chave no grupo, não se preocupe, as chaves são carregadas automaticamente para um banco de dados.';

  @override
  String get faqMoreHelp => 'Mais ajuda';

  @override
  String get faqNotAdlc => 'Não é um DLC';

  @override
  String get faqNotAdlcDescription => 'Este item não é um DLC.';

  @override
  String get faqServerContent => 'Conteúdo do servidor';

  @override
  String get faqServerContentDescription =>
      'Este item é exclusivo de um servidor específico e não pode ser baixado diretamente.';

  @override
  String get fileDeleted => 'Arquivo excluído';

  @override
  String get storedFiles => 'Arquivos armazenados';

  @override
  String get refreshFiles => 'Atualizar arquivos';

  @override
  String get deleteFile => 'Excluir arquivo';

  @override
  String deleteFileConfirmation(String fileName) {
    return 'Tem certeza de que deseja excluir $fileName?';
  }

  @override
  String get cancelUppercase => 'CANCELAR';

  @override
  String get deleteUppercase => 'EXCLUIR';

  @override
  String get currentDownload => 'Download atual';

  @override
  String get noActiveDownloads => 'Nenhum download ativo';

  @override
  String get completedDownloads => 'Downloads concluídos';

  @override
  String get clearAll => 'Limpar tudo';

  @override
  String get importToMc => 'Importar para o Minecraft';

  @override
  String get openFileinExplorer => 'Abrir no explorador de arquivos';

  @override
  String get shareFile => 'Compartilhar arquivo';

  @override
  String get debugTerminal => 'Terminal de Depuração';

  @override
  String get clearLogs => 'Limpar registros';

  @override
  String get noLogs => 'Ainda não há registros...';

  @override
  String get saveLogs => 'Salvar registros';

  @override
  String logsSaved(String filePath) {
    return 'Registros salvos em $filePath';
  }

  @override
  String get selectingFile => 'Selecionando arquivo...';

  @override
  String get processingFile => 'Processando arquivo...';

  @override
  String get fileProcessed => 'Arquivo processado com sucesso!';

  @override
  String get noFileSelected => 'Nenhum arquivo selecionado';

  @override
  String customKeysLoaded(int count) {
    return '$count chaves personalizadas carregadas';
  }

  @override
  String get noCustomKeysLoaded => 'Nenhuma chave personalizada carregada';

  @override
  String get importFileFormat => 'Importe um arquivo com o formato UUID=CHAVE';

  @override
  String creatorItemsWithType(String contentType) {
    return 'Itens $contentType';
  }

  @override
  String creatorItemsWithTypeAndCount(String contentType, int count) {
    return '$contentType Itens ($count)';
  }

  @override
  String get creatorItemsDefault => 'Itens do Criador';

  @override
  String get noItemCreator => 'Este criador não tem conteúdo';

  @override
  String get noStatistic => 'Não há estatísticas disponíveis';

  @override
  String get failedLoadStatistic => 'Falha ao carregar as estatísticas';

  @override
  String get noResultsFound => 'Nenhum resultado encontrado';

  @override
  String get microsoftAuth => 'Autenticação da Microsoft';

  @override
  String get exchangingToken => 'Trocar código de autorização por token...';

  @override
  String authenticationFailed(String error) {
    return 'Falha na autenticação: $error';
  }

  @override
  String get authenticationSuccessful => 'Autenticação realizada com sucesso!';

  @override
  String failedToExchangeToken(String error) {
    return 'falha ao trocar o código pelo token: $error';
  }

  @override
  String get noAuthorizationCodeReceived =>
      'Nenhum código de autorização recebido';

  @override
  String get noNewKeysCopy => 'Nenhuma nova chave encontrada para copiar';

  @override
  String get keysCopyClipboard =>
      'Chaves copiadas para a área de transferência!';

  @override
  String get noNewKeysShare =>
      'Nenhuma nova chave encontrada para compartilhar';

  @override
  String get keysShared => 'Chaves compartilhadas com sucesso!';

  @override
  String get authCheck => 'Verificando a autenticação existente...';

  @override
  String get alreadyAuth => 'Já autenticado!';

  @override
  String get readyAuth => 'Pronto para autenticar';

  @override
  String get authURL => 'Autenticar com o URL';

  @override
  String get completeAuthButton => 'Autenticação completa';

  @override
  String get openAuthPageButton => 'Abrir página de autenticação';

  @override
  String get completeAuth =>
      'Conclua a autenticação no seu navegador. Você será redirecionado de volta para o aplicativo.';

  @override
  String get copyUrl => 'Copiar URL';

  @override
  String get authPageFail => 'Não foi possível abrir a página de autenticação';

  @override
  String get logout => 'Saindo da sessão...';

  @override
  String get logoutOk => 'Sessão encerrada com sucesso';

  @override
  String get usingCachedSession => 'Utilizando sessão em cache...';

  @override
  String get loadingMinecraftKeys => 'Carregando chaves do Minecraft...';

  @override
  String get requestingXboxLiveToken => 'Solicitando token do Xbox Live...';

  @override
  String get loggingInToPlayFab => 'A iniciar sessão no PlayFab...';

  @override
  String get gettingUserInformation => 'Obtendo informações do usuário...';

  @override
  String get startingMinecraftSession => 'Iniciando sessão de Minecraft...';

  @override
  String get loadingMinecraftInventory =>
      'Carregando o inventário do Minecraft...';

  @override
  String successfullyLoadedKeys(int keyCount) {
    return 'Chaves $keyCount carregadas com sucesso!';
  }

  @override
  String errorLoadingKeys(String error) {
    return 'Erro ao carregar chaves: $error';
  }

  @override
  String get copyClipboard => 'Copiado para a área de transferência';

  @override
  String get authOk => 'Autenticado';

  @override
  String get authNotOk => 'Não autenticado';

  @override
  String get urlAuth => 'URL de autenticação';

  @override
  String get loadedKeys => 'Chaves carregadas';

  @override
  String get exportNewKeys => 'Exportar somente chaves novas';

  @override
  String get loadKeysButton => 'Carregar chaves';

  @override
  String get logoutButton => 'Sair';

  @override
  String get startAuthButton => 'Iniciar autenticação';

  @override
  String get greetings => 'Oi';

  @override
  String get copy => 'Copiar';

  @override
  String get save => 'Salvar';

  @override
  String get share => 'Compartilhar';

  @override
  String get keysSaved => 'Chaves salvas com sucesso';

  @override
  String get startingDownload => 'Iniciando o download...';

  @override
  String get downloadsCompleted => 'Downloads concluídos';

  @override
  String get completed => 'Concluído!';

  @override
  String get downloadFailed => 'Falha no download';

  @override
  String get downloading => 'Baixando';

  @override
  String get processing => 'Processamento';

  @override
  String get extractingZipFile => 'Extraindo arquivo zip...';

  @override
  String get decryptingContents => 'Descriptografando conteúdo...';

  @override
  String get compressingPack => 'Comprimindo pacote...';

  @override
  String get cleaningUp => 'Limpando...';

  @override
  String get showAll => 'Mostrar tudo';

  @override
  String get onlyAvailable => 'Somente disponível';

  @override
  String get onlyNotAvailable => 'Apenas não disponível';

  @override
  String get customColor => 'Cor personalizada';

  @override
  String get changeCustomColor => 'Toque para alterar sua cor personalizada';

  @override
  String get createCustomColor => 'Crie seu próprio esquema de cores';

  @override
  String get pickColor => 'Escolha a cor';

  @override
  String get selectColor => 'Selecione';

  @override
  String get images => 'Imagens';

  @override
  String get saveToPng => 'Salvar em PNG';

  @override
  String get saveToGallery => 'Salvar na galeria';

  @override
  String get compression => 'Compressão';

  @override
  String get normalCompression => 'Compressão normal';

  @override
  String get noCompression => 'Sem compressão';

  @override
  String get copyUUID => 'Copiar UUID';

  @override
  String get openInMinecraft => 'Abrir no Minecraft';

  @override
  String get creator => 'Criador';

  @override
  String get addToCart => 'Adicionar ao carrinho';

  @override
  String get removeFromCart => 'Remover do carrinho';

  @override
  String get addedToCart => 'Adicionado ao carrinho';

  @override
  String get removedFromCart => 'Removido do carrinho';

  @override
  String get authRequired => 'Autenticação necessária';

  @override
  String get authRequiredDesc =>
      'Você precisa estar totalmente autenticado para visualizar seu carrinho. Por favor, autentique-se na página de login da sua conta.';

  @override
  String get newUpdate => 'Nova atualização';

  @override
  String get newDlc => 'Novo DLC';

  @override
  String get hidden => 'Escondido';

  @override
  String get persona => 'Persona';

  @override
  String get skins => 'Skins';

  @override
  String get mashups => 'Mashups';

  @override
  String get worlds => 'Mundos';

  @override
  String get textures => 'Texturas';

  @override
  String get addons => 'Complementos';

  @override
  String get capes => 'Capas';

  @override
  String get vibrantVisuals => 'Visuais vibrantes';

  @override
  String get favorites => 'Favoritos';

  @override
  String get unfiltered => 'Sem filtro';

  @override
  String get sorting => 'Classificação';

  @override
  String get type => 'Tipo';

  @override
  String get newFilter => 'Novo';

  @override
  String get other => 'Outro';

  @override
  String get newest => 'Mais recente';

  @override
  String get oldest => 'Mais antigo';

  @override
  String get mostRated => 'Mais avaliado';

  @override
  String get leastRated => 'Menos avaliado';

  @override
  String get menu => 'Menu';

  @override
  String imageSavedToGallery(String filePath) {
    return 'Imagem salva na galeria: $filePath';
  }

  @override
  String get vibrantVisualEnhanced => 'Visuais vibrantes aprimorados';

  @override
  String get uuidCopied => 'UUID copiado para a área de transferência';

  @override
  String get scrollRight => 'Deslize para a direita';

  @override
  String get scrollLeft => 'Deslize para a esquerda';

  @override
  String get previousImage => 'Imagem anterior';

  @override
  String get nextImage => 'Próxima imagem';

  @override
  String get favoriteEmpty => 'Sua lista de favoritos está vazia';

  @override
  String get favoriteDescription =>
      'Toque no ícone de coração na página de detalhes de qualquer item para adicioná-lo aos seus favoritos e aumentar sua coleção';

  @override
  String get removeFromFavorites => 'Remover dos favoritos';

  @override
  String get addToFavorites => 'Adicionar aos favoritos';

  @override
  String get addedToFavorites => 'Adicionado aos favoritos';

  @override
  String get removedFromFavorites => 'Removido dos favoritos';

  @override
  String get noNewKeysFoundToSave => 'Nenhuma chave encontrada para salvar';

  @override
  String get keysSavedSuccessfully =>
      'As chaves foram salvas com sucesso na pasta Kyzen.';

  @override
  String get entitlementKeys => 'Chaves de autorização';

  @override
  String get searchBoughContent =>
      'Pesquise o conteúdo que você comprou no Minecraft.';

  @override
  String get saveKeys => 'Salvar chaves';

  @override
  String get refresh => 'Atualizar';

  @override
  String get searchKeys => 'Chaves de pesquisa';

  @override
  String get loadSkinPersona => 'Carregar SkinPack/Persona';

  @override
  String get descriptionSkinPersona =>
      'Inclua o pacote de skins e a persona na lista';

  @override
  String get loadOnlyNewKeys => 'Carregar apenas chaves novas';

  @override
  String get descriptionLoadOnlyNewKeys =>
      'Carregar apenas o conteúdo que não está presente no banco de dados de chaves do aplicativo';

  @override
  String get descriptionExportNewKeys =>
      'Se a opção \"salvar chaves\" deve exportar apenas chaves novas';

  @override
  String processedEntitlementKeys(int countFiles, int countKeys) {
    return 'Processados ​​com sucesso ($countFiles arquivos, $countKeys chaves)';
  }

  @override
  String get noResultsYet => 'Ainda não há resultados';

  @override
  String get clickSearchKeysToLoadContent =>
      'Clique em \"Palavras-chave de pesquisa\" para carregar seu conteúdo';

  @override
  String get tryadifferentSearch => 'Tente um termo de pesquisa diferente';

  @override
  String get minecraftNotInstalled =>
      'Não foram encontrados caminhos de instalação válidos para o Minecraft. Certifique-se de que o Minecraft Bedrock Edition (UWP ou GDK) esteja instalado e tenha sido executado pelo menos uma vez.';

  @override
  String get processingError => 'Erros de processamento';

  @override
  String get dismiss => 'Dispensar';

  @override
  String get failedFiles => 'Arquivos com falha:';

  @override
  String get minecraftFont => 'Fonte do Minecraft';

  @override
  String get usingMinecraftFont => 'Usando fonte estilo Minecraft';

  @override
  String get usingDefaultFont => 'Usando a fonte padrão';

  @override
  String get dlcLanguage => 'Idioma do DLC';

  @override
  String get dlcLangInfo => 'Informações sobre o idioma do DLC';

  @override
  String get dlcLangInfoText =>
      'Observe que alguns DLCs podem não ter tradução disponível. Isso depende exclusivamente da loja de aplicativos e não do aplicativo em si.';

  @override
  String get pageSize => 'Tamanho da página';

  @override
  String get pageSizeInfo => 'Informações sobre o tamanho da página';

  @override
  String get pageSizeInfoText =>
      'Controla quantos itens são carregados de uma só vez. • Valores mais baixos: Melhor para conexões lentas (solicitações mais frequentes) • Valores mais altos: Melhor para conexões rápidas (menos solicitações) Todos os resultados permanecem acessíveis independentemente do tamanho da página. Itens adicionais são carregados automaticamente quando você chega ao final da lista.';

  @override
  String get selectDlcLanguage => 'Selecione o idioma do DLC';

  @override
  String get downloadPathUpdated => 'Caminho de download atualizado';

  @override
  String get downloadPathReset =>
      'O caminho de download foi redefinido para o padrão.';

  @override
  String get resetDefaults => 'Restaurar para as configurações padrão';

  @override
  String get chooseFolder => 'Selecione a pasta';

  @override
  String get downloadPath => 'Caminho de download';

  @override
  String get version => 'Versão';

  @override
  String get purchasing => 'Compras';

  @override
  String get failedPurchase => 'Falha na compra';

  @override
  String get allItemsSuccessfullyPurchased =>
      'Todos os itens foram comprados com sucesso!';

  @override
  String insufficientFunds(int insufficientFundsItems) {
    return 'Fundos insuficientes para $insufficientFundsItems item(ns)';
  }

  @override
  String get somePurchasesFailed => 'Algumas compras falharam';

  @override
  String numItemsAreNotPurchasable(int numItems) {
    return '$numItems item(ns) não estão disponíveis para compra';
  }

  @override
  String get purchaseComplete => 'Compra concluída';

  @override
  String get confirmPurchase => 'Confirmar compra';

  @override
  String confirmPurchaseMessage(String itemsText) {
    return 'Tem certeza de que deseja comprar $itemsText?';
  }

  @override
  String get totalPrice => 'Preço total:';

  @override
  String get purchaseResults => 'Resultados da compra';

  @override
  String successfullyPurchased(int successItems) {
    return 'Compra realizada com sucesso: $successItems item(ns)';
  }

  @override
  String alreadyOwnded(int alreadyOwnedItems) {
    return 'Já possuído: $alreadyOwnedItems item(ns)';
  }

  @override
  String numItemsNotPurchasable(int notPurchasableItems) {
    return 'Não disponível para compra: $notPurchasableItems item(ns)';
  }

  @override
  String numItemsInsufficientFunds(int insufficientFundsItems) {
    return 'Fundos insuficientes: $insufficientFundsItems item(ns)';
  }

  @override
  String numItemsFailed(int failedItemsCount) {
    return 'Compras falhadas: $failedItemsCount item(ns)';
  }

  @override
  String get clearCart => 'Limpar carrinho';

  @override
  String get clearCartConfirmation =>
      'Tem certeza de que deseja remover todos os itens do seu carrinho?';

  @override
  String cartTitleNum(int count) {
    return 'Carrinho ($count)';
  }

  @override
  String get cartisEmpty => 'Seu carrinho está vazio';

  @override
  String get cartEmptyDescription =>
      'Toque no ícone do carrinho na página de detalhes de qualquer item para adicioná-lo ao seu carrinho e comprá-lo.';

  @override
  String get purchasingInProgress => 'Comprando...';

  @override
  String purchaseAllnum(int count) {
    return 'Comprar tudo ($count)';
  }

  @override
  String get nowNewdlcFound => 'Nenhum novo DLC encontrado';

  @override
  String get nowNewDlcFoundDescription =>
      'Todos os DLCs já estão presentes no banco de dados do aplicativo.';

  @override
  String get noDlcFound => 'Nenhum DLC encontrado';

  @override
  String get noDlcAvailable => 'Nenhum conteúdo DLC disponível';

  @override
  String get openDlcsList => 'Abrir DLCs';

  @override
  String get appUpdates => 'Atualizações do aplicativo';

  @override
  String get appUpdatesDescription =>
      'Veja as novidades das versões mais recentes do aplicativo.';

  @override
  String get socials => 'Redes sociais';

  @override
  String get selectApp => 'Selecione o aplicativo';

  @override
  String get noAppsFound => 'Nenhum aplicativo encontrado';

  @override
  String get errorLoadingDlcs => 'Erro ao carregar os DLCs';

  @override
  String get dlcs => 'DLCs';

  @override
  String errorSavingKeys(String error) {
    return 'Erro ao salvar as chaves: $error';
  }

  @override
  String errorOpeningAuthPage(String error) {
    return 'Erro ao abrir a página de autenticação: $error';
  }

  @override
  String get gettingEntityToken => 'Obtendo token de entidade...';

  @override
  String get loadingMinecoinBalance => 'Carregando saldo de Minecoin...';

  @override
  String get completeAuthFirst => 'Por favor, conclua a autenticação primeiro';

  @override
  String get sessionExpired => 'Sessão expirada. Tente novamente.';

  @override
  String get accessDenied =>
      'Acesso negado. Por favor, autentique-se novamente.';

  @override
  String get connectionTimeout =>
      'Tempo limite de conexão excedido. Verifique sua conexão com a internet e tente novamente.';

  @override
  String get serverError =>
      'Erro no servidor. Tente novamente em alguns instantes.';

  @override
  String get backToSettings => 'Voltar às configurações';

  @override
  String errorInitializingCart(String error) {
    return 'Erro ao inicializar o carrinho: $error';
  }

  @override
  String errorLoadingCartItems(String error) {
    return 'Erro ao carregar os itens do carrinho: $error';
  }

  @override
  String failedLoadMoreItems(String error) {
    return 'Falha ao carregar mais itens: $error';
  }

  @override
  String errorSavingLog(String error) {
    return 'Erro ao salvar o registro de falhas: $error';
  }

  @override
  String get failedToDeleteFile => 'Falha ao excluir o arquivo';

  @override
  String failedToShareFile(String error) {
    return 'Falha ao compartilhar o arquivo: $error';
  }

  @override
  String get personaWarning =>
      'Itens de Persona não podem ser importados para o jogo (como emotes, itens cosméticos e capas).';

  @override
  String get initializingMcDec => 'Inicializando o McDec...';

  @override
  String failedToSaveKeys(String error) {
    return 'Falha ao salvar as chaves: $error';
  }

  @override
  String get itemDetailsTitle => 'Detalhes do item';

  @override
  String byCreator(String creator) {
    return 'Por $creator';
  }

  @override
  String get couldNotLoadSocials =>
      'Não foi possível carregar os links de redes sociais. Usando as configurações padrão.';

  @override
  String get sdCardExternalStorage => 'Cartão SD / Armazenamento externo';

  @override
  String get customLocation => 'Localização personalizada';

  @override
  String couldNotOpenLink(String error) {
    return 'Não foi possível abrir o link: $error';
  }

  @override
  String get minecraftPackage => 'Pacote do Minecraft';

  @override
  String get freeDroidWarnMessage =>
      'O Google anunciou que, a partir de 2026/2027, todos os aplicativos em dispositivos Android certificados exigirão que os desenvolvedores forneçam seus dados pessoais de identidade diretamente ao Google. Como os desenvolvedores deste aplicativo não concordam com esse requisito, o aplicativo deixará de funcionar em dispositivos Android certificados após essa data.';

  @override
  String get freeDroidWarnDetails => 'Detalhes';

  @override
  String get freeDroidWarnSolution => 'Solução';

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
