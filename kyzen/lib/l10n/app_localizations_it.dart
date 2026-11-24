// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get home => 'Casa';

  @override
  String get downloads => 'Downloads';

  @override
  String get settings => 'Impostazioni';

  @override
  String get selectLanguage => 'Seleziona Lingua';

  @override
  String get language => 'Lingua';

  @override
  String get download => 'Scarica';

  @override
  String get hintText => 'Cerca...';

  @override
  String get default1 => 'Predefinito';

  @override
  String get creators => 'Creatori';

  @override
  String get checkingKeys => 'Controllo chiavi';

  @override
  String get apiLogin => 'Accesso API';

  @override
  String addedNewKeys(int keyCount) {
    return 'Aggiunte $keyCount nuove chiavi';
  }

  @override
  String get noResult => 'Nessun risultato trovato';

  @override
  String get open => 'Apri';

  @override
  String get clear => 'Pulisci';

  @override
  String get retry => 'Riprova';

  @override
  String get ok => 'OK';

  @override
  String queuePosition(int count) {
    return 'In coda (Posizione #$count)';
  }

  @override
  String queuePosition2(int count) {
    return 'In coda #$count)';
  }

  @override
  String imageSaved(String filePath) {
    return 'Immagine salvata in $filePath';
  }

  @override
  String errorDownloadingImage(String error) {
    return 'Errore nel scaricare l\'immagine: $error';
  }

  @override
  String get changelog => 'Registro modifiche';

  @override
  String get downloaded => 'Scaricato';

  @override
  String get retryDownload => 'Riprova download';

  @override
  String get downloadImage => 'Scarica Immagine';

  @override
  String get downloadImageQuestion => 'Scaricare questa immagine?';

  @override
  String get cancel => 'Annulla';

  @override
  String get trailer => 'Guarda trailer';

  @override
  String trailerError(String error) {
    return 'Impossibile aprire il trailer: $error';
  }

  @override
  String get appearance => 'Aspetto';

  @override
  String get darkMode => 'Modalità Scura';

  @override
  String get darkEnabled => 'Tema scuro abilitato';

  @override
  String get lightEnabled => 'Tema chiaro abilitato';

  @override
  String get colorScheme => 'Schema Colore';

  @override
  String get defaultColor => 'Predefinito';

  @override
  String get defaultPurple => 'Predefinito (Viola)';

  @override
  String get colorSchemeBlue => 'Blu';

  @override
  String get colorSchemeGreen => 'Verde';

  @override
  String get colorSchemeOrange => 'Arancione';

  @override
  String get colorSchemeRed => 'Rosso';

  @override
  String get colorSchemeTeal => 'Verde acqua';

  @override
  String get colorSchemePink => 'Rosa';

  @override
  String get colorSchemeLime => 'Lime';

  @override
  String get filters => 'Filtri';

  @override
  String get filter => 'Filtro:';

  @override
  String get showSkins => 'Mostra skin';

  @override
  String get keys => 'Chiavi';

  @override
  String get autoUpdate => 'Auto-aggiornamento';

  @override
  String get customDb => 'Db Personalizzato';

  @override
  String get accountLogin => 'Login account';

  @override
  String get extras => 'Aggiuntivi';

  @override
  String get cache => 'Cache';

  @override
  String cacheCleared(String size) {
    return 'Cancellati $size MB di cache';
  }

  @override
  String get faq => 'Faq';

  @override
  String get faqUppercase => 'FAQ';

  @override
  String get terminal => 'Terminale';

  @override
  String get faqQuestion1 => 'Aggiungi le chiavi per questo e quel pacchetto!';

  @override
  String get faqQuestion2 => 'Quando le chiavi saranno aggiornate?';

  @override
  String get faqQuestion3 =>
      'Qual è la differenza tra crittografato e decifrato?';

  @override
  String get faqQuestion4 => 'Dove posso trovare i pacchetti scaricati?';

  @override
  String get faqQuestion5 => 'Che cos\'è keys.tsv?';

  @override
  String get faqQuestion6 =>
      'Come si possono usare gli oggetti cosmetici (Persona)?';

  @override
  String get faqQuestion7 => 'Perché alcuni skin pack sembrano corrotti?';

  @override
  String get faqQuestion8 =>
      'Qual è la funzione della pagina \"Accesso account\"?';

  @override
  String get faqQuestion9 => 'What does the checkmark mean?';

  @override
  String get faqAnswer1 =>
      'Il processo di ottenere le chiavi non è magico: una persona deve ancora comprare il pacco e condividere le chiavi con noi. Senza che qualcuno compri non ci sarebbero chiavi di decrittazione. Non è possibile ottenerli in nessun altro modo. Attendere pazientemente o comprarlo.';

  @override
  String get faqAnswer2 => 'Una volta che decidiamo.';

  @override
  String get faqAnswer3 =>
      'Crittografare significa trasformare il file in parole confuse che sembrano incomprensibili. Nessuno può leggerlo senza una chiave speciale. I contenuti di Minecraft crittografati non sono riproducibili.\n\nDecrittografare significa utilizzare la chiave speciale per trasformare il testo incomprensibile nel contenuto originale. Ora i contenuti di Minecraft possono essere utilizzati.';

  @override
  String get faqAnswer4 =>
      'Puoi trovare i dlc in questa cartella Download/Kyzen';

  @override
  String get faqAnswer5 =>
      'È un file che memorizza gli UUID dei pacchetti con le rispettive chiavi di decrittazione. Senza le chiavi di decrittazione, i pacchetti scaricati non sarebbero riproducibili.';

  @override
  String get faqAnswer6 =>
      'Non puoi. Esistono alcuni metodi però a causa della complessità non è fattibile.';

  @override
  String get faqAnswer7 =>
      'Alcuni skin pack (in particolare le collaborazioni con i franchise) utilizzano geometrie personalizzate che Minecraft non consente di utilizzare normalmente a meno che non si acquisti il ​​pacchetto skin. È possibile verificare se un pacchetto skin utilizza geometrie personalizzate controllando se il file \"geometry.json\" è presente nella cartella del dlc. Tieni presente che questo problema non è in alcun modo correlato a Kyzen.';

  @override
  String get faqAnswer8 =>
      'La pagina di accesso all\'account ti consente di autenticarti con il tuo account Microsoft per caricare le chiavi presenti nell\'inventario di Minecraft. Questa funzionalità è utile quando Kyzen non ha attualmente una chiave disponibile per un DLC specifico, ma ce l\'hai nel tuo account: una volta caricate le chiavi, il DLC apparirà disponibile per il download. Tieni presente che le chiavi vengono caricate automaticamente nel nostro database, dove verranno successivamente unite al database principale delle chiavi di Kyzen, in modo che tutti possano usufruire del nuovo DLC. Utilizza questa funzionalità se vuoi contribuire, grazie.';

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
  String get fileDeleted => 'File eliminato';

  @override
  String get storedFiles => 'File Archiviati';

  @override
  String get refreshFiles => 'Aggiorna file';

  @override
  String get deleteFile => 'Elimina File';

  @override
  String deleteFileConfirmation(String fileName) {
    return 'Sei sicuro di voler eliminare $fileName?';
  }

  @override
  String get cancelUppercase => 'ANNULLA';

  @override
  String get deleteUppercase => 'ELIMINA';

  @override
  String get currentDownload => 'Download corrente';

  @override
  String get noActiveDownloads => 'Nessun download attivo';

  @override
  String get completedDownloads => 'Download completi';

  @override
  String get clearAll => 'Cancella Tutto';

  @override
  String get importToMc => 'Importa in Minecraft';

  @override
  String get openFileinExplorer => 'Apri nel file manager';

  @override
  String get shareFile => 'Condividi file';

  @override
  String get debugTerminal => 'Terminale Debug';

  @override
  String get clearLogs => 'Cancella log';

  @override
  String get noLogs => 'Ancora nessun log...';

  @override
  String get saveLogs => 'Salva logs';

  @override
  String logsSaved(String filePath) {
    return 'Logs salvati in $filePath';
  }

  @override
  String get selectingFile => 'Selezione file...';

  @override
  String get processingFile => 'Elaborazione file...';

  @override
  String get fileProcessed => 'File elaborato con successo!';

  @override
  String get noFileSelected => 'Nessun file selezionato';

  @override
  String customKeysLoaded(int count) {
    return 'Caricate $count chiavi personalizzate';
  }

  @override
  String get noCustomKeysLoaded => 'Nessuna chiave personalizzata caricata';

  @override
  String get importFileFormat => 'Importa un file con formato UUID=KEY';

  @override
  String creatorItemsWithType(String contentType) {
    return '$contentType Items';
  }

  @override
  String creatorItemsWithTypeAndCount(String contentType, int count) {
    return '$contentType Items ($count)';
  }

  @override
  String get creatorItemsDefault => 'Creatore items';

  @override
  String get noItemCreator => 'Questo creatore non ha contenuti';

  @override
  String get noStatistic => 'Nessuna statistica disponibile';

  @override
  String get failedLoadStatistic => 'Impossibile caricare le statistiche';

  @override
  String get noResultsFound => 'Nessun risultato trovato';

  @override
  String get microsoftAuth => 'Autenticazione Microsoft';

  @override
  String get exchangingToken => 'Scambio codice di autorizzazione...';

  @override
  String authenticationFailed(String error) {
    return 'Autenticazione non riuscita: $error';
  }

  @override
  String get authenticationSuccessful => 'Autenticazione riuscita!';

  @override
  String failedToExchangeToken(String error) {
    return 'Impossibile scambiare il codice con il token: $error';
  }

  @override
  String get noAuthorizationCodeReceived =>
      'Nessun codice di autorizzazione ricevuto';

  @override
  String get noNewKeysCopy => 'Nessuna nuova chiave trovata da copiare';

  @override
  String get keysCopyClipboard => 'Chiavi copiati negli appunti!';

  @override
  String get noNewKeysShare => 'Nessuna nuova chiave trovata da condividere';

  @override
  String get keysShared => 'Chiavi condivise con successo!';

  @override
  String get authCheck => 'Controllo autenticazione esistente...';

  @override
  String get alreadyAuth => 'Già autenticato!';

  @override
  String get readyAuth => 'Pronto per l\'autenticazione';

  @override
  String get authURL => 'Autenticazione con l\'URL';

  @override
  String get completeAuthButton => 'Completa l\'autenticazione';

  @override
  String get openAuthPageButton => 'Apri la pagina di autenticazione';

  @override
  String get completeAuth =>
      'Completa l\'autenticazione nel tuo browser. Sarai reindirizzato all\'app.';

  @override
  String get copyUrl => 'Copia URL';

  @override
  String get authPageFail => 'Impossibile aprire la pagina di autenticazione';

  @override
  String get logout => 'Disconnessione...';

  @override
  String get logoutOk => 'Disconnesso con successo';

  @override
  String get usingCachedSession => 'Usando la sessione nella cache...';

  @override
  String get loadingMinecraftKeys => 'Caricamento chiavi Minecraft...';

  @override
  String get requestingXboxLiveToken => 'Richiesta token Xbox Live...';

  @override
  String get loggingInToPlayFab => 'Accesso a PlayFab...';

  @override
  String get gettingUserInformation => 'Ottenendo informazioni utente...';

  @override
  String get startingMinecraftSession => 'Avvio sessione di Minecraft...';

  @override
  String get loadingMinecraftInventory =>
      'Caricamento inventario di Minecraft...';

  @override
  String successfullyLoadedKeys(int keyCount) {
    return 'Chiavi $keyCount caricate con successo!';
  }

  @override
  String errorLoadingKeys(String error) {
    return 'Errore nel caricare le chiavi: $error';
  }

  @override
  String get copyClipboard => 'Copiato negli appunti';

  @override
  String get authOk => 'Autenticato';

  @override
  String get authNotOk => 'Non Autenticato';

  @override
  String get urlAuth => 'Autenticazione URL';

  @override
  String get loadedKeys => 'Chiavi caricate';

  @override
  String get exportNewKeys => 'Esporta solo nuove chiavi';

  @override
  String get loadKeysButton => 'Carica chiavi';

  @override
  String get logoutButton => 'Esci';

  @override
  String get startAuthButton => 'Avvia Autenticazione';

  @override
  String get greetings => 'Ciao ';

  @override
  String get copy => 'Copia';

  @override
  String get save => 'Salva';

  @override
  String get share => 'Condividi';

  @override
  String get keysSaved => 'Chiavi salvate';

  @override
  String get startingDownload => 'Avvio download...';

  @override
  String get downloadsCompleted => 'Download completati';

  @override
  String get completed => 'Completato!';

  @override
  String get downloadFailed => 'Download non riuscito';

  @override
  String get downloading => 'Downloading';

  @override
  String get processing => 'Elaborazione';

  @override
  String get extractingZipFile => 'Estrazione file zip...';

  @override
  String get decryptingContents => 'Decifratura dei contenuti...';

  @override
  String get compressingPack => 'Compressione pacchetto...';

  @override
  String get cleaningUp => 'Pulizia in corso...';

  @override
  String get showAll => 'Mostra tutto';

  @override
  String get onlyAvailable => 'Solo disponibile';

  @override
  String get onlyNotAvailable => 'Solo non disponibile';

  @override
  String get customColor => 'Colore personalizzato';

  @override
  String get changeCustomColor => 'Tocca per cambiare il colore personalizzato';

  @override
  String get createCustomColor => 'Crea la tua combinazione di colori';

  @override
  String get pickColor => 'Scegli colore';

  @override
  String get selectColor => 'Seleziona';

  @override
  String get images => 'Immagini';

  @override
  String get saveToPng => 'Salva in PNG';

  @override
  String get saveToGallery => 'Salva nella Galleria';

  @override
  String get compression => 'Compressione';

  @override
  String get normalCompression => 'Compressione normale';

  @override
  String get noCompression => 'Nessuna compressione';

  @override
  String get copyUUID => 'Copia UUID';

  @override
  String get openInMinecraft => 'Apri in Minecraft';

  @override
  String get creator => 'Creatore';

  @override
  String get addToCart => 'Aggiungi al carrello';

  @override
  String get removeFromCart => 'Rimuovi dal carrello';

  @override
  String get addedToCart => 'Aggiunto al carrello';

  @override
  String get removedFromCart => 'Rimosso dal carrello';

  @override
  String get authRequired => 'Autenticazione richiesta';

  @override
  String get authRequiredDesc =>
      'Per visualizzare il tuo carrello devi eseguire l\'accesso al tuo account.';

  @override
  String get newUpdate => 'Nuovi aggiornamenti';

  @override
  String get newDlc => 'Nuovi dlc';

  @override
  String get hidden => 'Nascosti';

  @override
  String get persona => 'Persona';

  @override
  String get skins => 'Skins';

  @override
  String get mashups => 'Mashups';

  @override
  String get worlds => 'Mondi';

  @override
  String get textures => 'Textures';

  @override
  String get addons => 'Add-Ons';

  @override
  String get capes => 'Capes';

  @override
  String get vibrantVisuals => 'Grafica vivace';

  @override
  String get favorites => 'Favoriti';

  @override
  String get unfiltered => 'Non-filtrato';

  @override
  String get sorting => 'Ordine';

  @override
  String get type => 'Tipo';

  @override
  String get newFilter => 'Nuovo';

  @override
  String get other => 'Altro';

  @override
  String get newest => 'Più recente';

  @override
  String get oldest => 'Più vecchio';

  @override
  String get mostRated => 'Più votati';

  @override
  String get leastRated => 'Meno votati';

  @override
  String get menu => 'Menu';

  @override
  String imageSavedToGallery(String filePath) {
    return 'Immagine salvata nella galleria: $filePath';
  }

  @override
  String get vibrantVisualEnhanced => 'Grafica Vivace Migliorata';

  @override
  String get uuidCopied => 'UUID copiato negli appunti';

  @override
  String get scrollRight => 'Scorri a destra';

  @override
  String get scrollLeft => 'Scorri a sinistra';

  @override
  String get previousImage => 'Immagine precedente';

  @override
  String get nextImage => 'Immagine successiva';

  @override
  String get favoriteEmpty => 'La tua lista dei preferiti è vuota';

  @override
  String get favoriteDescription =>
      'Tocca l\'icona del cuore sulla pagina dei dettagli di qualsiasi dlc per aggiungerlo ai preferiti e creare la tua collezione';

  @override
  String get removeFromFavorites => 'Rimuovi dai preferiti';

  @override
  String get addToFavorites => 'Aggiungi ai preferiti';

  @override
  String get addedToFavorites => 'Aggiunto ai preferiti';

  @override
  String get removedFromFavorites => 'Rimosso dai preferiti';

  @override
  String get noNewKeysFoundToSave => 'Nessuna chiave trovata da salvare';

  @override
  String get keysSavedSuccessfully => 'Chiavi salvate nella cartella Kyzen.';

  @override
  String get entitlementKeys => 'Chiavi entitlement';

  @override
  String get searchBoughContent =>
      'Cerca i contenuti Minecraft che hai acquistato.';

  @override
  String get saveKeys => 'Salva chiavi';

  @override
  String get refresh => 'Aggiorna';

  @override
  String get searchKeys => 'Cerca chiavi';

  @override
  String get loadSkinPersona => 'Carica SkinPack/Persona';

  @override
  String get descriptionSkinPersona =>
      'Includi skinpack e persona nell\'elenco';

  @override
  String get loadOnlyNewKeys => 'Carica solo nuove chiavi';

  @override
  String get descriptionLoadOnlyNewKeys =>
      'Carica solo contenuti non presenti nel database dell\'app';

  @override
  String get descriptionExportNewKeys =>
      'Se \"salva chiavi\" dovrebbe esportare solo le nuove chiavi';

  @override
  String processedEntitlementKeys(int countFiles, int countKeys) {
    return 'Elaborazione completata correttamente ($countFiles file, $countKeys chiavi)';
  }

  @override
  String get noResultsYet => 'Ancora nessun risultato';

  @override
  String get clickSearchKeysToLoadContent =>
      'Fai clic su \"Cerca chiavi\" per caricare i contenuti';

  @override
  String get tryadifferentSearch => 'Prova un termine di ricerca diverso';

  @override
  String get minecraftNotInstalled =>
      'Non sono stati trovati percorsi di installazione di Minecraft validi. Assicurati che Minecraft Bedrock Edition (UWP o GDK) sia installato e avviato almeno una volta.';

  @override
  String get processingError => 'Errori di elaborazione';

  @override
  String get dismiss => 'Rimuovi';

  @override
  String get failedFiles => 'File non riusciti:';

  @override
  String get minecraftFont => 'Minecraft Font';

  @override
  String get usingMinecraftFont => 'Utilizzo del font in stile Minecraft';

  @override
  String get usingDefaultFont => 'Utilizzando il font predefinito';

  @override
  String get dlcLanguage => 'Lingua DLC';

  @override
  String get dlcLangInfo => 'Informazioni sulla lingua dei DLC';

  @override
  String get dlcLangInfoText =>
      'Tieni presente che per alcuni DLC potrebbe non essere disponibile una traduzione. Questo dipende esclusivamente dal marketplace e non dall\'app.';

  @override
  String get pageSize => 'Dimensioni pagina';

  @override
  String get pageSizeInfo => 'Informazioni dimensioni pagina';

  @override
  String get pageSizeInfoText =>
      'Controlla quanti elementi vengono caricati.\n\n • Valori più bassi: migliori per connessioni deboli (richieste più frequenti)\n • Valori più alti: migliori per connessioni veloci (meno richieste)\n\n Tutti i risultati rimangono accessibili indipendentemente dalle dimensioni della pagina. Gli elementi aggiuntivi vengono caricati automaticamente quando si raggiunge la fine dell\'elenco.';

  @override
  String get selectDlcLanguage => 'Seleziona la lingua per i DLC';

  @override
  String get downloadPathUpdated => 'Percorso di download aggiornato';

  @override
  String get downloadPathReset => 'Percorso di download ripristinato';

  @override
  String get resetDefaults => 'Ripristina a predefinito';

  @override
  String get chooseFolder => 'Scegli cartella';

  @override
  String get downloadPath => 'Percorso download';

  @override
  String get version => 'Versione';

  @override
  String get purchasing => 'Acquistando';

  @override
  String get failedPurchase => 'Impossibile acquistare';

  @override
  String get allItemsSuccessfullyPurchased =>
      'Tutti gli articoli sono stati acquistati con successo!';

  @override
  String insufficientFunds(int insufficientFundsItems) {
    return 'Fondi insufficienti per $insufficientFundsItems articolo/i';
  }

  @override
  String get somePurchasesFailed => 'Alcuni acquisti non sono riusciti';

  @override
  String numItemsAreNotPurchasable(int numItems) {
    return '$numItems articoli non sono acquistabili';
  }

  @override
  String get purchaseComplete => 'Acquisto completato';

  @override
  String get confirmPurchase => 'Conferma acquisto';

  @override
  String confirmPurchaseMessage(String itemsText) {
    return 'Sei sicuro di voler acquistare $itemsText?';
  }

  @override
  String get totalPrice => 'Prezzo totale:';

  @override
  String get purchaseResults => 'Risultati dell\'acquisto';

  @override
  String successfullyPurchased(int successItems) {
    return 'Acquistato con successo: $successItems articolo/i';
  }

  @override
  String alreadyOwnded(int alreadyOwnedItems) {
    return 'Già posseduto: $alreadyOwnedItems articolo/i';
  }

  @override
  String numItemsNotPurchasable(int notPurchasableItems) {
    return 'Non acquistabile: $notPurchasableItems articolo/i';
  }

  @override
  String numItemsInsufficientFunds(int insufficientFundsItems) {
    return 'Fondi insufficienti: $insufficientFundsItems elemento/i';
  }

  @override
  String numItemsFailed(int failedItemsCount) {
    return 'Acquisti non riusciti: $failedItemsCount articolo/i';
  }

  @override
  String get clearCart => 'Resetta carrello';

  @override
  String get clearCartConfirmation =>
      'Sei sicuro di voler rimuovere tutti gli articoli dal carrello?';

  @override
  String cartTitleNum(int count) {
    return 'Carrello ($count)';
  }

  @override
  String get cartisEmpty => 'Il tuo carrello è vuoto';

  @override
  String get cartEmptyDescription =>
      'Tocca l\'icona del carrello nella pagina dei dettagli di qualsiasi articolo per aggiungerlo al carrello e acquistarlo';

  @override
  String get purchasingInProgress => 'Acquistando...';

  @override
  String purchaseAllnum(int count) {
    return 'Acquista tutto ($count)';
  }

  @override
  String get nowNewdlcFound => 'Nessun nuovo DLC trovato';

  @override
  String get nowNewDlcFoundDescription =>
      'Tutti i DLC sono già presenti nel database dell\'app';

  @override
  String get noDlcFound => 'Nessun DLC trovato';

  @override
  String get noDlcAvailable => 'Nessun contenuto DLC disponibile';

  @override
  String get openDlcsList => 'Apri DLC';

  @override
  String get appUpdates => 'Aggiornamenti dell\'app';

  @override
  String get appUpdatesDescription =>
      'Scopri le novità delle versioni recenti dell\'app';

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
      'Google ha annunciato che, a partire dal 2026/2027, tutte le app sui dispositivi Android certificati richiederanno agli sviluppatori di fornire i propri dati personali di identità direttamente a Google. Poiché gli sviluppatori di questa app non accettano tale requisito, l’app smetterà di funzionare sui dispositivi Android certificati dopo quella data.';

  @override
  String get freeDroidWarnDetails => 'Dettagli';

  @override
  String get freeDroidWarnSolution => 'Soluzione';

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
