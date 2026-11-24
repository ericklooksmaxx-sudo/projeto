// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get home => 'Inicio';

  @override
  String get downloads => 'Descargas';

  @override
  String get settings => 'Ajustes';

  @override
  String get selectLanguage => 'Seleccionar Idioma';

  @override
  String get language => 'Idioma';

  @override
  String get download => 'Descargar';

  @override
  String get hintText => 'Buscar...';

  @override
  String get default1 => 'Por defecto';

  @override
  String get creators => 'Creadores';

  @override
  String get checkingKeys => 'Revisando llaves';

  @override
  String get apiLogin => 'Iniciando sesión en la API';

  @override
  String addedNewKeys(int keyCount) {
    return 'Se añadieron $keyCount llaves nuevas';
  }

  @override
  String get noResult => 'No se encontraron resultados';

  @override
  String get open => 'Abrir';

  @override
  String get clear => 'Limpiar';

  @override
  String get retry => 'Reintentar';

  @override
  String get ok => 'OK';

  @override
  String queuePosition(int count) {
    return 'En espera (Posición #$count)';
  }

  @override
  String queuePosition2(int count) {
    return 'En espera #$count';
  }

  @override
  String imageSaved(String filePath) {
    return 'Imagen guardada en $filePath';
  }

  @override
  String errorDownloadingImage(String error) {
    return 'Error descargando la imagen: $error';
  }

  @override
  String get changelog => 'Lista de cambios';

  @override
  String get downloaded => 'Descargado';

  @override
  String get retryDownload => 'Reintentar Descarga';

  @override
  String get downloadImage => 'Descargar imagen';

  @override
  String get downloadImageQuestion => '¿Descargar esta imagen?';

  @override
  String get cancel => 'Cancelar';

  @override
  String get trailer => 'Ver Trailer';

  @override
  String trailerError(String error) {
    return 'No se pudo abrir el trailer: $error';
  }

  @override
  String get appearance => 'Apariencia';

  @override
  String get darkMode => 'Modo Oscuro';

  @override
  String get darkEnabled => 'Tema oscuro activado';

  @override
  String get lightEnabled => 'Tema claro activado';

  @override
  String get colorScheme => 'Esquema de color';

  @override
  String get defaultColor => 'Por defecto';

  @override
  String get defaultPurple => 'Por defecto (morado)';

  @override
  String get colorSchemeBlue => 'Azul';

  @override
  String get colorSchemeGreen => 'Verde';

  @override
  String get colorSchemeOrange => 'Naranja';

  @override
  String get colorSchemeRed => 'Rojo';

  @override
  String get colorSchemeTeal => 'Cerceta';

  @override
  String get colorSchemePink => 'Rosa';

  @override
  String get colorSchemeLime => 'Lima';

  @override
  String get filters => 'Filtros';

  @override
  String get filter => 'Filtrar:';

  @override
  String get showSkins => 'Mostrar skins';

  @override
  String get keys => 'Llaves';

  @override
  String get autoUpdate => 'Actualización automática';

  @override
  String get customDb => 'BD personalizada';

  @override
  String get accountLogin => 'Iniciar sesión';

  @override
  String get extras => 'Extras';

  @override
  String get cache => 'Caché';

  @override
  String cacheCleared(String size) {
    return 'Se limpiaron $size MB de caché';
  }

  @override
  String get faq => 'Preguntas frecuentes';

  @override
  String get faqUppercase => 'PREGUNTAS FRECUENTES';

  @override
  String get terminal => 'Consola';

  @override
  String get faqQuestion1 => '¡Por favor añade las llaves para los paquetes!';

  @override
  String get faqQuestion2 => '¿Cuando se actualizarán las llaves?';

  @override
  String get faqQuestion3 =>
      '¿Cuál es la diferencia entre encriptado y desencriptado?';

  @override
  String get faqQuestion4 => '¿Donde puedo encontrar los paquetes descargados?';

  @override
  String get faqQuestion5 => '¿Qué es keys.tsv?';

  @override
  String get faqQuestion6 => '¿Cómo uso los artículos de Persona?';

  @override
  String get faqQuestion7 => '¿Por qué algunos skin packs aparecen rotos?';

  @override
  String get faqQuestion8 =>
      '¿Cuál es el propósito de la página \"Iniciar sesión\"?';

  @override
  String get faqQuestion9 => '¿Qué significa el tick?';

  @override
  String get faqAnswer1 =>
      'El proceso de obtención de las llaves no es mágia: alguien tiene que comprar el paquete y compartir las llaves con nosotros. Sin nadie comprando, no podría haber llaves de desencriptación. No es posible obtenerlas de ninguna otra manera. Espera con paciencia hasta que alguien lo compre o cómpralo tú mismo.';

  @override
  String get faqAnswer2 => 'Cuando decidamos hacerlo.';

  @override
  String get faqAnswer3 =>
      'Encriptar significa convertir el archivo en palabras desordenadas que parecen un galimatías. Nadie puede leerlo sin una llave especial. El contenido encriptado de Minecraft no se puede jugar. Desencriptar significa usar la llave especial para transformar el galimatías a su contenido original. Ahora se puede usar el contenido de Minecraft.';

  @override
  String get faqAnswer4 => 'Puedes encontrarlos en Download/Kyzen';

  @override
  String get faqAnswer5 =>
      'Es un archivo que almacena los UUID de los paquetes con sus respectivas llaves de desencriptación. Sin las llaves de desencriptación, los paquetes descargados no podrían jugarse.';

  @override
  String get faqAnswer6 =>
      'No puedes. Existen algunos métodos pero dada la complejidad para hacerlo, no es factible.';

  @override
  String get faqAnswer7 =>
      'Algunos skin packs (especialmente los de colaboraciones con franquicias) usan geometría personalizada, algo que Minecraft no permite usar normalmente a menos que compres el skin pack. Puedes comprobar si un skin pack usa geometría personalizada si en el paquete existe un archivo llamado \"geometry.json\". Tenga en cuenta que este problema no está relacionado con la herramienta(Kyzen) de ningún modo.';

  @override
  String get faqAnswer8 =>
      'La página de iniciar sesión te permite autenticarte con tu cuenta Microsoft para cargar directamente tus llaves de Minecraft desde tu inventario. Esto es útil cuando Kyzen no tiene una llave disponible de un DLC en específico en ese momento pero tu cuenta si la tiene, una vez que se carguen tus llaves, ese DLC aparecerá disponible para descargar. Tenga en cuenta que las llaves se cargan automáticamente en nuestra base de datos, donde luego se fusionarán con la base de datos de llaves principal de Kyzen para que todos puedan disfrutar del nuevo DLC, así que utilice esta función si desea contribuir.';

  @override
  String get faqAnswer9Checkmark => 'La llave de este DLC está disponible.';

  @override
  String get faqAnswer9NoCheckmark =>
      'La aplicación actualmente no tiene la llave de ese DLC.';

  @override
  String get faqAnswer9ExtraInfo =>
      'Se necesitan las llaves para desbloquear los DLCs.';

  @override
  String get faqQuestionDownload =>
      '¿Por qué el botón de descarga no está disponible?';

  @override
  String get faqAnswerDownload =>
      'La llave para desbloquear este dlc no está disponible, se paciente o cómpralo.';

  @override
  String get faqQuestionKey => '¿Cómo consigo la llave?';

  @override
  String get faqAnswerKey =>
      'Compra el DLC en tu cuenta, luego ve a configuración > Inicio de sesión de cuenta > Haz clic en \'Iniciar autenticación\' > haz clic en \'Cargar llaves\', ahora haz clic en \'Compartir\' y comparte los archivos de llaves en el chat de Bluecoin, las llaves se añadirán a la base de datos de la app. Si no puedes compartir el archivo de llaves en el grupo, no te preocupes, las llaves se suben automáticamente a la base de datos.';

  @override
  String get faqMoreHelp => 'Más ayuda';

  @override
  String get faqNotAdlc => 'No es un DLC';

  @override
  String get faqNotAdlcDescription => 'Este artículo no es un DLC.';

  @override
  String get faqServerContent => 'Contenido de servidor';

  @override
  String get faqServerContentDescription =>
      'Este artículo es exclusivo de un servidor específico y no se puede descargar directamente.';

  @override
  String get fileDeleted => 'Archivo eliminado';

  @override
  String get storedFiles => 'Archivos Almacenados';

  @override
  String get refreshFiles => 'Recargar archivos';

  @override
  String get deleteFile => 'Eliminar Archivo';

  @override
  String deleteFileConfirmation(String fileName) {
    return '¿Estás seguro de querer eliminar $fileName?';
  }

  @override
  String get cancelUppercase => 'CANCELAR';

  @override
  String get deleteUppercase => 'ELIMINAR';

  @override
  String get currentDownload => 'Descarga Actual';

  @override
  String get noActiveDownloads => 'No hay descargas activas';

  @override
  String get completedDownloads => 'Descargas Completas';

  @override
  String get clearAll => 'Limpiar Todo';

  @override
  String get importToMc => 'Importar a Minecraft';

  @override
  String get openFileinExplorer => 'Abrir en el explorador de archivos';

  @override
  String get shareFile => 'Compartir archivo';

  @override
  String get debugTerminal => 'Consola de Depuración';

  @override
  String get clearLogs => 'Limpiar registros';

  @override
  String get noLogs => 'Aún no hay registros...';

  @override
  String get saveLogs => 'Guardar registros';

  @override
  String logsSaved(String filePath) {
    return 'Registros guardados en $filePath';
  }

  @override
  String get selectingFile => 'Seleccionando archivo...';

  @override
  String get processingFile => 'Procesando archivo...';

  @override
  String get fileProcessed => '¡Archivo procesado satisfactoriamente!';

  @override
  String get noFileSelected => 'No hay archivos seleccionados';

  @override
  String customKeysLoaded(int count) {
    return '$count llaves personalizadas cargadas';
  }

  @override
  String get noCustomKeysLoaded => 'No hay llaves personalizadas cargadas';

  @override
  String get importFileFormat => 'Importa un archivo con el formato UUID=LLAVE';

  @override
  String creatorItemsWithType(String contentType) {
    return 'Artículos de $contentType';
  }

  @override
  String creatorItemsWithTypeAndCount(String contentType, int count) {
    return 'Artículos de $contentType ($count)';
  }

  @override
  String get creatorItemsDefault => 'Artículos de creador';

  @override
  String get noItemCreator => 'Este creador no tiene contenido';

  @override
  String get noStatistic => 'No hay estadísticas disponibles';

  @override
  String get failedLoadStatistic => 'La carga de estadísticas falló';

  @override
  String get noResultsFound => 'No se encontraron resultados';

  @override
  String get microsoftAuth => 'Autenticación de Microsoft';

  @override
  String get exchangingToken =>
      'Cambiando el código de autorización por el token...';

  @override
  String authenticationFailed(String error) {
    return 'Autenticación fallida: $error';
  }

  @override
  String get authenticationSuccessful => '¡Autenticación exitosa!';

  @override
  String failedToExchangeToken(String error) {
    return 'Falló el cambio de código por el token: $error';
  }

  @override
  String get noAuthorizationCodeReceived =>
      'No se recibió el código de autorización';

  @override
  String get noNewKeysCopy => 'No hay nuevas llaves para copiar';

  @override
  String get keysCopyClipboard => '¡Llaves copiadas en el portapapeles!';

  @override
  String get noNewKeysShare => 'No se encontraron nuevas llaves para compartir';

  @override
  String get keysShared => '¡Llaves compartidas con éxito!';

  @override
  String get authCheck => 'Revisando autenticación existente...';

  @override
  String get alreadyAuth => '¡Ya está autenticado!';

  @override
  String get readyAuth => 'Preparado para autenticarse';

  @override
  String get authURL => 'Autenticarse con la URL';

  @override
  String get completeAuthButton => 'Complete la Autenticación';

  @override
  String get openAuthPageButton => 'Abrir Página de Autenticación';

  @override
  String get completeAuth =>
      'Completa la autenticación en tu navegador. Serás redireccionado de vuelta a la aplicación.';

  @override
  String get copyUrl => 'Copiar URL';

  @override
  String get authPageFail => 'No se pudo abrir la página de autenticación';

  @override
  String get logout => 'Cerrando sesión...';

  @override
  String get logoutOk => 'Cierre de sesión exitoso';

  @override
  String get usingCachedSession => 'Usando una sesión en caché...';

  @override
  String get loadingMinecraftKeys => 'Cargando llaves de Minecraft...';

  @override
  String get requestingXboxLiveToken => 'Solicitando token de Xbox Live...';

  @override
  String get loggingInToPlayFab => 'Iniciando sesión en PlayFab...';

  @override
  String get gettingUserInformation => 'Obteniendo información del usuario...';

  @override
  String get startingMinecraftSession => 'Empezando una sesión de Minecraft...';

  @override
  String get loadingMinecraftInventory => 'Cargando inventario de Minecraft...';

  @override
  String successfullyLoadedKeys(int keyCount) {
    return '¡$keyCount llaves cargadas con éxito!';
  }

  @override
  String errorLoadingKeys(String error) {
    return 'Error cargando las llaves: $error';
  }

  @override
  String get copyClipboard => 'Copiado en el portapapeles';

  @override
  String get authOk => 'Autenticado';

  @override
  String get authNotOk => 'No está autenticado';

  @override
  String get urlAuth => 'URL de autenticación';

  @override
  String get loadedKeys => 'Llaves cargadas';

  @override
  String get exportNewKeys => 'Exportar solo llaves nuevas';

  @override
  String get loadKeysButton => 'Cargar llaves';

  @override
  String get logoutButton => 'Cerrar sesión';

  @override
  String get startAuthButton => 'Empezar Autenticación';

  @override
  String get greetings => 'Hola ';

  @override
  String get copy => 'Copiar';

  @override
  String get save => 'Guardar';

  @override
  String get share => 'Compartir';

  @override
  String get keysSaved => 'Llaves guardadas con éxito';

  @override
  String get startingDownload => 'Empezando a descargar...';

  @override
  String get downloadsCompleted => 'Descargas completadas';

  @override
  String get completed => '¡Completado!';

  @override
  String get downloadFailed => 'Descarga fallida';

  @override
  String get downloading => 'Descargando';

  @override
  String get processing => 'Procesando';

  @override
  String get extractingZipFile => 'Extrayendo archivo zip...';

  @override
  String get decryptingContents => 'Desencriptando contenido...';

  @override
  String get compressingPack => 'Comprimiendo el paquete...';

  @override
  String get cleaningUp => 'Limpiando...';

  @override
  String get showAll => 'Mostrar todo';

  @override
  String get onlyAvailable => 'Sólo lo disponible';

  @override
  String get onlyNotAvailable => 'Sólo lo no disponible';

  @override
  String get customColor => 'Color personalizado';

  @override
  String get changeCustomColor => 'Toca para cambiar tu color personalizado';

  @override
  String get createCustomColor => 'Crea tu propio esquema de color';

  @override
  String get pickColor => 'Elige color';

  @override
  String get selectColor => 'Seleccionar';

  @override
  String get images => 'Imágenes';

  @override
  String get saveToPng => 'Guardar en PNG';

  @override
  String get saveToGallery => 'Guardar en la Galería';

  @override
  String get compression => 'Compresión';

  @override
  String get normalCompression => 'Compresión Normal';

  @override
  String get noCompression => 'Sin Compresión';

  @override
  String get copyUUID => 'Copiar UUID';

  @override
  String get openInMinecraft => 'Abrir en Minecraft';

  @override
  String get creator => 'Creador';

  @override
  String get addToCart => 'Añadir al Carrito';

  @override
  String get removeFromCart => 'Eliminar del Carrito';

  @override
  String get addedToCart => 'Añadido al carrito';

  @override
  String get removedFromCart => 'Eliminado del carrito';

  @override
  String get authRequired => 'Autenticación requerida';

  @override
  String get authRequiredDesc =>
      'Necesitas estár completamente autenticado para ver tu carrito. Por favor autentícate desde la página de iniciar sesión.';

  @override
  String get newUpdate => 'Nuevos Actualizados';

  @override
  String get newDlc => 'Nuevos dlc';

  @override
  String get hidden => 'Escondido';

  @override
  String get persona => 'Persona';

  @override
  String get skins => 'Skins';

  @override
  String get mashups => 'Popurrís';

  @override
  String get worlds => 'Mundos';

  @override
  String get textures => 'Texturas';

  @override
  String get addons => 'Add-Ons';

  @override
  String get capes => 'Capas';

  @override
  String get vibrantVisuals => 'Vibrant visuals';

  @override
  String get favorites => 'Favoritos';

  @override
  String get unfiltered => 'Sin filtrar';

  @override
  String get sorting => 'Orden';

  @override
  String get type => 'Tipo';

  @override
  String get newFilter => 'Nuevo';

  @override
  String get other => 'Otros';

  @override
  String get newest => 'Más nuevos';

  @override
  String get oldest => 'Más viejos';

  @override
  String get mostRated => 'Mejor valorados';

  @override
  String get leastRated => 'Peor valorados';

  @override
  String get menu => 'Menú';

  @override
  String imageSavedToGallery(String filePath) {
    return 'Imagen guardada en la galería: $filePath';
  }

  @override
  String get vibrantVisualEnhanced => 'Mejorado con Vibrant visuals';

  @override
  String get uuidCopied => 'UUID copiado en el portapapeles de';

  @override
  String get scrollRight => 'Desplazar a la derecha';

  @override
  String get scrollLeft => 'Desplazar a la izquierda';

  @override
  String get previousImage => 'Imagen anterior';

  @override
  String get nextImage => 'Imagen siguiente';

  @override
  String get favoriteEmpty => 'Tu lista de favoritos está vacía';

  @override
  String get favoriteDescription =>
      'Pulsa el icono del corazón en los detalles de cualquier artículo para añadirlo a tu lista de favoritos y construir tu colección';

  @override
  String get removeFromFavorites => 'Eliminar de favoritos';

  @override
  String get addToFavorites => 'Añadir a favoritos';

  @override
  String get addedToFavorites => 'Añadido a favoritos';

  @override
  String get removedFromFavorites => 'Eliminado de favoritos';

  @override
  String get noNewKeysFoundToSave =>
      'No sé encontraron nuevas llaves que guardar';

  @override
  String get keysSavedSuccessfully =>
      'Llaves guardadas con éxito en la carpeta de Kyzen.';

  @override
  String get entitlementKeys => 'Llaves de Autorización';

  @override
  String get searchBoughContent => 'Busca tú contenido comprado de Minecraft';

  @override
  String get saveKeys => 'Guardar Llaves';

  @override
  String get refresh => 'Recargar';

  @override
  String get searchKeys => 'Buscar Llaves';

  @override
  String get loadSkinPersona => 'Cargar SkinPack/Persona';

  @override
  String get descriptionSkinPersona =>
      'Incluir skinpacks y persona en la lista';

  @override
  String get loadOnlyNewKeys => 'Cargar solo llaves nuevas';

  @override
  String get descriptionLoadOnlyNewKeys =>
      'Cargar solo contenido no presente en la base de datos de llaves de la aplicación';

  @override
  String get descriptionExportNewKeys =>
      'Si \"guardar Llaves\" debería exportar únicamente nuevas llaves';

  @override
  String processedEntitlementKeys(int countFiles, int countKeys) {
    return 'Procesado con éxito($countFiles archivos, $countKeys llaves)';
  }

  @override
  String get noResultsYet => 'Aún no hay resultados';

  @override
  String get clickSearchKeysToLoadContent =>
      'Pulsar \"Buscar Llaves\" para cargar tu contenido';

  @override
  String get tryadifferentSearch => 'Intenta otro término de busqueda';

  @override
  String get minecraftNotInstalled =>
      'No sé encontraron rutas válidas de instalación de Minecraft. Por favor asegúrese de que Minecraft(UWP o GDK) está instalado o ha sido iniciado al menos una vez.';

  @override
  String get processingError => 'Procesando Errores';

  @override
  String get dismiss => 'Descartar';

  @override
  String get failedFiles => 'Archivos Fallidos:';

  @override
  String get minecraftFont => 'Fuente de Minecraft';

  @override
  String get usingMinecraftFont =>
      'Usando la fuente con el estilo de Minecraft';

  @override
  String get usingDefaultFont => 'Usando la fuente por defecto';

  @override
  String get dlcLanguage => 'Idioma de DLC';

  @override
  String get dlcLangInfo => 'Información del Idioma de DLC';

  @override
  String get dlcLangInfoText =>
      'Tenga en cuenta que algunos DLCs podrían no tener una traducción disponible. Esto únicamente depende de la marketplace y no de la aplicación.';

  @override
  String get pageSize => 'Tamaño de la Página';

  @override
  String get pageSizeInfo => 'Información del Tamaño de la Página';

  @override
  String get pageSizeInfoText =>
      'Controla cuántos items se están cargando al mismo tiempo.\n\n • Valores bajos: Mejor para conexiones débiles (Solicitudes más frecuentes)\n • Valores altos: Mejor para conexiones rápidas (menos solicitudes)\n\n Todos los resultados siguen estando disponibles sin importar el tamaño de la página. Los items Adicionales cargan automáticamente a medida que alcanzas el final de la lista.';

  @override
  String get selectDlcLanguage => 'Selecciona Idioma de DLC';

  @override
  String get downloadPathUpdated => 'Ruta de descarga actualizada';

  @override
  String get downloadPathReset =>
      'La ruta de descarga ha sido reseteada a la por defecto';

  @override
  String get resetDefaults => 'Resetea a la por defecto';

  @override
  String get chooseFolder => 'Selecciona una carpeta';

  @override
  String get downloadPath => 'Ruta de Descarga';

  @override
  String get version => 'Versión';

  @override
  String get purchasing => 'Comprando';

  @override
  String get failedPurchase => 'La compra falló';

  @override
  String get allItemsSuccessfullyPurchased =>
      'Todos los items fueron comprados con éxito!';

  @override
  String insufficientFunds(int insufficientFundsItems) {
    return 'Fondos insuficientes para $insufficientFundsItems item(s)';
  }

  @override
  String get somePurchasesFailed => 'Algunas compras fallaron';

  @override
  String numItemsAreNotPurchasable(int numItems) {
    return '$numItems item(s) son incomprables';
  }

  @override
  String get purchaseComplete => 'Compra completada';

  @override
  String get confirmPurchase => 'Confirmar Compra';

  @override
  String confirmPurchaseMessage(String itemsText) {
    return '¿Estás seguro de que quieres comprar $itemsText?';
  }

  @override
  String get totalPrice => 'Precio Total:';

  @override
  String get purchaseResults => 'Resultados de Compra';

  @override
  String successfullyPurchased(int successItems) {
    return 'Comprados éxitosamente: $successItems item(s)';
  }

  @override
  String alreadyOwnded(int alreadyOwnedItems) {
    return 'Ya poseidos: $alreadyOwnedItems item(s)';
  }

  @override
  String numItemsNotPurchasable(int notPurchasableItems) {
    return 'Incomprables: $notPurchasableItems item(s)';
  }

  @override
  String numItemsInsufficientFunds(int insufficientFundsItems) {
    return 'Fondos insuficientes: $insufficientFundsItems item(s)';
  }

  @override
  String numItemsFailed(int failedItemsCount) {
    return 'Compras fallidas: $failedItemsCount item(s)';
  }

  @override
  String get clearCart => 'Limpiar carrito';

  @override
  String get clearCartConfirmation =>
      '¿Estás seguro de que quieres eliminar todos los items de tu carrito?';

  @override
  String cartTitleNum(int count) {
    return 'Carrito ($count)';
  }

  @override
  String get cartisEmpty => 'Tu carrito está vacío';

  @override
  String get cartEmptyDescription =>
      'Presiona el icono del carrito en la página de detalles de cualquier item para añadirlo al carrito y comprarlo';

  @override
  String get purchasingInProgress => 'Comprando...';

  @override
  String purchaseAllnum(int count) {
    return 'Comprar Todo ($count)';
  }

  @override
  String get nowNewdlcFound => 'No se Encontraron Nuevos DLCs';

  @override
  String get nowNewDlcFoundDescription =>
      'Todos los DLCs ya se encuentran en la base de datos de la aplicación';

  @override
  String get noDlcFound => 'No se Encontraron DLCs';

  @override
  String get noDlcAvailable => 'No hay contenido DLC disponible';

  @override
  String get openDlcsList => 'Abrir DLCs';

  @override
  String get appUpdates => 'Actualizaciones de la App';

  @override
  String get appUpdatesDescription =>
      'Vea las novedades en las versiones recientes de la app';

  @override
  String get socials => 'Redes sociales';

  @override
  String get selectApp => 'Seleccionar Aplicación';

  @override
  String get noAppsFound => 'No se encontraron aplicaciones';

  @override
  String get errorLoadingDlcs => 'Error cargando DLCs';

  @override
  String get dlcs => 'DLCs';

  @override
  String errorSavingKeys(String error) {
    return 'Error al guardar las llaves: $error';
  }

  @override
  String errorOpeningAuthPage(String error) {
    return 'Error al abrir la página de autenticación: $error';
  }

  @override
  String get gettingEntityToken => 'Obteniendo el entity token...';

  @override
  String get loadingMinecoinBalance => 'Cargando saldo de Minecoin...';

  @override
  String get completeAuthFirst =>
      'Por favor, completa la autenticación primero';

  @override
  String get sessionExpired =>
      'Sesión expirada. Por favor, inténtalo de nuevo.';

  @override
  String get accessDenied =>
      'Acceso denegado. Por favor, vuelve a autenticarte.';

  @override
  String get connectionTimeout =>
      'Tiempo de conexión agotado. Por favor, revisa tu internet y vuelve a intentarlo.';

  @override
  String get serverError =>
      'Error de servidor. Por favor intentalo de nuevo en unos momentos.';

  @override
  String get backToSettings => 'Volver a Ajustes';

  @override
  String errorInitializingCart(String error) {
    return 'Error al iniciar el carrito: $error';
  }

  @override
  String errorLoadingCartItems(String error) {
    return 'Error al cargar los artículos del carrito: $error';
  }

  @override
  String failedLoadMoreItems(String error) {
    return 'No se pudieron cargar más artículos: $error';
  }

  @override
  String errorSavingLog(String error) {
    return 'Error al guardar el registro: $error';
  }

  @override
  String get failedToDeleteFile => 'No se pudo borrar el archivo';

  @override
  String failedToShareFile(String error) {
    return 'No se pudo compartir el archivo: $error';
  }

  @override
  String get personaWarning =>
      'Los artículos de persona no se pueden importar dentro del juego (como gestos, cosméticos y capas)';

  @override
  String get initializingMcDec => 'Iniciando McDec...';

  @override
  String failedToSaveKeys(String error) {
    return 'No se han podido guardar las llaves: $error';
  }

  @override
  String get itemDetailsTitle => 'Detalles del Artículo';

  @override
  String byCreator(String creator) {
    return 'Por $creator';
  }

  @override
  String get couldNotLoadSocials =>
      'No se pudieron cargar los enlaces de redes sociales, usando los por defecto';

  @override
  String get sdCardExternalStorage => 'Tarjeta SD / Almacenamiento Externo';

  @override
  String get customLocation => 'Ubicación Personalizada';

  @override
  String couldNotOpenLink(String error) {
    return 'No se pudo abrir el enlace: $error';
  }

  @override
  String get minecraftPackage => 'Paquete de Minecraft';

  @override
  String get freeDroidWarnMessage =>
      'Google ha anunciado que, a partir de 2026/2027, todas las aplicaciones en dispositivos Android certificados requerirán que los desarrolladores envíen sus datos personales de identidad directamente a Google. Como los desarrolladores de esta aplicación no están de acuerdo con este requisito, la aplicación dejará de funcionar en dispositivos Android certificados después de esa fecha.';

  @override
  String get freeDroidWarnDetails => 'Detalles';

  @override
  String get freeDroidWarnSolution => 'Solución';

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
