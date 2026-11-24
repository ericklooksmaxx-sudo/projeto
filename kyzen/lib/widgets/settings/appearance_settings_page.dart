import 'dart:io';
import 'dart:typed_data';

import 'package:kyzen/l10n/context_extensions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import '../../services/persona_glb_service.dart';
import '../../services/settings_service.dart';
import '../theme.dart';

class AppearanceSettingsPage extends StatefulWidget {
  final bool isDarkMode;
  final String? colorScheme;
  final Color? customColor;
  final Function(bool) onThemeChanged;
  final Function(String?) onColorSchemeChanged;
  final Function(Color?) onCustomColorChanged;
  final Function(String) onLanguageChanged;
  final Function(bool)? onFontChanged;

  const AppearanceSettingsPage({
    super.key,
    required this.isDarkMode,
    this.colorScheme,
    this.customColor,
    required this.onThemeChanged,
    required this.onColorSchemeChanged,
    required this.onCustomColorChanged,
    required this.onLanguageChanged,
    this.onFontChanged,
  });

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  final SettingsService _settingsService = SettingsService.instance;
  late bool _isDarkMode;
  String? _selectedColorScheme;
  Color? _customColor;
  late String _selectedLanguage;
  late String _selectedApiLanguage;
  late bool _mcFontSetting;
  bool _preview3DSetting = true;
  bool _adaptiveResolutionSetting = false;
  bool _isLoading = true;
  bool _hasCustomSkin = false;
  String? _customSkinName;
  Uint8List? _customSkinAvatarBytes;
  bool _isSavingSkin = false;

  static const Map<String, String> _languageOptions = {
    'en': 'English',
    'it': 'Italiano',
    'es': 'Español',
    'pt': 'Português',
    'lt': 'Lietuvių',
    'fr': 'Français',
    'ru': 'Русский',
    'uk': 'Українська',
    'fa': 'فارسی',
    'ar': 'اَلْعَرَبِيَّةُ',
    'zh': '简体中文',
    'th': 'ภาษาไทย',
    'id': 'Indonesia',
    'hi': 'हिन्दी',
    'fil': 'Filipino',
    'fi': 'Suomalainen',
    'cs': 'Čeština',
    'bn': 'বাংলা',
    'ms': 'Malaysia',
  };

  static const Map<String, String> _apilanguageOptions = {
    'en': 'English',
    'it': 'Italiano',
    'es': 'Español',
    'bg': 'български',
    'cs': 'Čeština',
    'da': 'Dansk',
    'de': 'Deutsch',
    'el': 'Ελληνικά',
    'fi': 'Suomi',
    'fr': 'Français',
    'hu': 'Magyar',
    'id': 'Indonesia',
    'ja': '日本語',
    'ko': '한국어',
    'nb': 'Norsk bokmål',
    'nl': 'Nederlands',
    'pl': 'Polski',
    'pt': 'Português',
    'ru': 'Русский',
    'sk': 'Slovenčina',
    'sv': 'Svenska',
    'tr': 'Türkçe',
    'uk': 'Українська',
    'zh': '中文',
  };

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _selectedColorScheme = widget.colorScheme;
    _customColor = widget.customColor;
    _loadSettings();
  }

  @override
  void didUpdateWidget(AppearanceSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isDarkMode != widget.isDarkMode ||
        _selectedColorScheme != widget.colorScheme ||
        _customColor != widget.customColor) {
      setState(() {
        _isDarkMode = widget.isDarkMode;
        _selectedColorScheme = widget.colorScheme;
        _customColor = widget.customColor;
      });
    }
  }

  Future<void> _loadSettings() async {
    final isDark = await _settingsService.getDarkMode();
    final colorScheme = await _settingsService.getColorScheme();
    final customColor = await _settingsService.getCustomColor();
    final language = await _settingsService.getLanguage();
    final apiLanguage = await _settingsService.getApiLanguage();
    final mcFont = await _settingsService.getFont();
    final preview3D = await _settingsService.get3DPreview();
    final adaptiveResolution = await _settingsService.getAdaptiveResolution();
    final hasCustomSkin = await PersonaGlbService.instance.hasCustomPersona();
    final customSkinName = await PersonaGlbService.instance.getCustomSkinName();
    Uint8List? avatarBytes;
    if (hasCustomSkin) {
      try {
        avatarBytes = await PersonaGlbService.instance.getCustomHeadBytes();
      } catch (e) {
        debugPrint('Error loading persona avatar: $e');
      }
    }

    if (mounted) {
      setState(() {
        _isDarkMode = isDark;
        _selectedColorScheme = colorScheme;
        _customColor = customColor;
        _selectedLanguage = language;
        _selectedApiLanguage = apiLanguage;
        _mcFontSetting = mcFont;
        _preview3DSetting = preview3D;
        _adaptiveResolutionSetting = adaptiveResolution;
        _hasCustomSkin = hasCustomSkin;
        _customSkinName = customSkinName;
        _customSkinAvatarBytes = avatarBytes;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPersonaSkinState() async {
    final hasCustom = await PersonaGlbService.instance.hasCustomPersona();
    final name = await PersonaGlbService.instance.getCustomSkinName();
    Uint8List? avatarBytes;
    if (hasCustom) {
      try {
        avatarBytes = await PersonaGlbService.instance.getCustomHeadBytes();
      } catch (e) {
        debugPrint('Error loading persona avatar: $e');
      }
    }
    if (mounted) {
      setState(() {
        _hasCustomSkin = hasCustom;
        _customSkinName = name;
        _customSkinAvatarBytes = avatarBytes;
      });
    }
  }

  Future<void> _pickAndApplyCustomSkin() async {
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Select Minecraft Skin (.png)',
        type: FileType.custom,
        allowedExtensions: ['png'],
      );

      if (file == null || file.path == null) return;

      final bytes = await File(file.path!).readAsBytes();
      if (bytes.isEmpty) {
        _showErrorSnackBar('Failed to read the selected file');
        return;
      }

      // Validate skin format
      final validation = PersonaGlbService.validateSkinBytes(bytes);
      if (!validation.isValid) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.l10n.unsupportedSkinFormat),
            content: Text(
              validation.error ?? context.l10n.invalidSkinFormatMessage,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(context.l10n.ok),
              ),
            ],
          ),
        );
        return;
      }

      setState(() => _isSavingSkin = true);

      final skinName = p.basenameWithoutExtension(file.name);
      await PersonaGlbService.instance.saveCustomSkin(
        bytes,
        skinName: skinName,
      );

      await _loadPersonaSkinState();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.customPersonaSkinUpdated(skinName)),
        ),
      );
    } catch (e) {
      debugPrint('Error applying custom skin: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to apply custom skin: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingSkin = false);
      }
    }
  }

  Future<void> _resetPersonaSkin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.resetPersonaSkinQuestion),
        content: Text(context.l10n.resetPersonaSkinDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.reset),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isSavingSkin = true);
      await PersonaGlbService.instance.resetToDefault();
      await _loadPersonaSkinState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.resetPersonaSkinSuccess)),
      );
    } catch (e) {
      _showErrorSnackBar('Failed to reset persona skin: $e');
    } finally {
      if (mounted) {
        setState(() => _isSavingSkin = false);
      }
    }
  }

  Future<void> _toggleDarkMode(bool value) async {
    try {
      await _settingsService.setDarkMode(value);
      setState(() => _isDarkMode = value);
      widget.onThemeChanged(value);
    } catch (_) {
      _showErrorSnackBar('Failed to save theme setting');
    }
  }

  Future<void> _toggleMinecraftFont(bool value) async {
    try {
      await _settingsService.updateFont(value);
      setState(() => _mcFontSetting = value);
      widget.onFontChanged?.call(value);
    } catch (_) {
      _showErrorSnackBar('Failed to save font setting');
    }
  }

  Future<void> _toggle3DPreview(bool value) async {
    try {
      await _settingsService.set3DPreview(value);
      setState(() => _preview3DSetting = value);
    } catch (_) {
      _showErrorSnackBar('Failed to save 3D preview setting');
    }
  }

  Future<void> _toggleAdaptiveResolution(bool value) async {
    try {
      await _settingsService.setAdaptiveResolution(value);
      setState(() => _adaptiveResolutionSetting = value);
    } catch (_) {
      _showErrorSnackBar('Failed to save adaptive resolution setting');
    }
  }

  Future<void> _changeColorScheme(String? colorScheme) async {
    try {
      await _settingsService.setColorScheme(colorScheme);
      setState(() => _selectedColorScheme = colorScheme);
      widget.onColorSchemeChanged(colorScheme);
    } catch (_) {
      _showErrorSnackBar('Failed to save color scheme setting');
    }
  }

  Future<void> _changeCustomColor(Color color) async {
    try {
      await _settingsService.setCustomColor(color);
      await _settingsService.setColorScheme('custom');
      setState(() {
        _customColor = color;
        _selectedColorScheme = 'custom';
      });
      widget.onCustomColorChanged(color);
      widget.onColorSchemeChanged('custom');
    } catch (_) {
      _showErrorSnackBar('Failed to save custom color setting');
    }
  }

  Future<void> _updateLanguage(String languageCode) async {
    try {
      await _settingsService.setLanguage(languageCode);
      setState(() => _selectedLanguage = languageCode);
      widget.onLanguageChanged(languageCode);
    } catch (_) {
      _showErrorSnackBar('Failed to save language setting');
    }
  }

  Future<void> _updateApiLanguage(String languageCode) async {
    try {
      await _settingsService.setApiLanguage(languageCode);
      setState(() => _selectedApiLanguage = languageCode);
    } catch (_) {
      _showErrorSnackBar('Failed to save DLC language setting');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Color _getCurrentSchemeColor() {
    if (_selectedColorScheme == null) {
      return Colors.purple;
    }
    if (_selectedColorScheme == 'custom' && _customColor != null) {
      return _customColor!;
    }
    return AppTheme.getSeedColor(_selectedColorScheme!);
  }

  String _getColorSchemeDisplayName() {
    if (_selectedColorScheme == null) {
      return context.l10n.defaultPurple;
    }
    if (_selectedColorScheme == 'custom') {
      return context.l10n.customColor;
    }
    final displayNames = AppTheme.getColorSchemeDisplayNames(context);
    return displayNames[_selectedColorScheme] ?? _selectedColorScheme!;
  }

  void _showLanguagePicker({bool isApiLanguage = false}) {
    final Map<String, String> options = isApiLanguage
        ? _apilanguageOptions
        : _languageOptions;
    final String selectedLang = isApiLanguage
        ? _selectedApiLanguage
        : _selectedLanguage;
    final String title = isApiLanguage
        ? context.l10n.selectDlcLanguage
        : context.l10n.selectLanguage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ListView(
                      children: [
                        ...options.entries.map((entry) {
                          final isSelected = selectedLang == entry.key;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainer,
                              child: Text(
                                entry.key.toUpperCase(),
                                style: TextStyle(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Text(entry.value),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  )
                                : null,
                            onTap: () {
                              if (isApiLanguage) {
                                _updateApiLanguage(entry.key);
                              } else {
                                _updateLanguage(entry.key);
                              }
                              Navigator.pop(context);
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showColorSchemePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Text(
                      context.l10n.colorScheme,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      _buildCustomColorCard(),
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 2,
                          childAspectRatio: 2,
                          children: [
                            _buildColorCard(
                              colorScheme: null,
                              displayName: context.l10n.defaultColor,
                              displayColor: Colors.purple,
                              isSelected: _selectedColorScheme == null,
                              onTap: () {
                                Navigator.of(context).pop();
                                _changeColorScheme(null);
                              },
                            ),
                            ...AppTheme.availableColorSchemes.map((scheme) {
                              final displayNames =
                                  AppTheme.getColorSchemeDisplayNames(context);
                              final displayName =
                                  displayNames[scheme] ?? scheme;
                              final seedColor = AppTheme.getSeedColor(scheme);
                              return _buildColorCard(
                                colorScheme: scheme,
                                displayName: displayName,
                                displayColor: seedColor,
                                isSelected: _selectedColorScheme == scheme,
                                onTap: () {
                                  Navigator.of(context).pop();
                                  _changeColorScheme(scheme);
                                },
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCustomColorPicker() {
    Color pickerColor = _customColor ?? Colors.blue;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.l10n.pickColor),
          content: SingleChildScrollView(
            child: ColorPicker(
              color: pickerColor,
              onColorChanged: (Color color) {
                pickerColor = color;
              },
              wheelDiameter: 280,
              wheelWidth: 18,
              hasBorder: false,
              showMaterialName: false,
              showColorName: true,
              showColorCode: true,
              colorCodeHasColor: true,
              enableShadesSelection: false,
              padding: const EdgeInsets.all(4),
              pickersEnabled: const <ColorPickerType, bool>{
                ColorPickerType.both: false,
                ColorPickerType.primary: false,
                ColorPickerType.accent: false,
                ColorPickerType.bw: false,
                ColorPickerType.custom: false,
                ColorPickerType.wheel: true,
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _changeCustomColor(pickerColor);
              },
              child: Text(context.l10n.selectColor),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCustomColorCard() {
    final isSelected = _selectedColorScheme == 'custom';
    final customColor = _customColor ?? Colors.grey;

    return Card(
      elevation: isSelected ? 12 : 4,
      shadowColor: isSelected ? customColor.withValues(alpha: 0.4) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? BorderSide(color: customColor, width: 3)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).pop();
          if (_customColor != null && !isSelected) {
            _changeColorScheme('custom');
          } else {
            _showCustomColorPicker();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: customColor.withValues(alpha: 0.7),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _customColor != null
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          color: customColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 28,
                              )
                            : null,
                      )
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Colors.red,
                              Colors.orange,
                              Colors.yellow,
                              Colors.green,
                              Colors.blue,
                              Colors.indigo,
                              Colors.purple,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.palette,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  context.l10n.customColor,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? customColor : null,
                  ),
                ),
              ),
              if (_customColor != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: context.l10n.selectColor,
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showCustomColorPicker();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorCard({
    required String? colorScheme,
    required String displayName,
    required Color displayColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: isSelected ? 12 : 4,
      shadowColor: isSelected ? displayColor.withValues(alpha: 0.4) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? BorderSide(color: displayColor, width: 3)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [displayColor, displayColor.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: displayColor.withValues(alpha: 0.7),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 24)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  displayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? displayColor : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children, String? title}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.appearance)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.appearance),
        forceMaterialTransparency: true,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          12.0,
          12.0,
          12.0,
          12.0 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _buildSectionCard(
            title: context.l10n.themeAndFont,
            children: [
              // Kyzen is a black product, like the site: no light copy of it.
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(context.l10n.darkMode),
                subtitle: Text(context.l10n.darkEnabled),
                leading: const Icon(Icons.dark_mode),
                enabled: false,
              ),
              const Divider(),
              SwitchListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(context.l10n.minecraftFont),
                subtitle: Text(
                  _mcFontSetting
                      ? context.l10n.usingMinecraftFont
                      : context.l10n.usingDefaultFont,
                ),
                value: _mcFontSetting,
                onChanged: _toggleMinecraftFont,
                secondary: const Icon(Icons.format_size_rounded),
              ),
              const Divider(),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getCurrentSchemeColor(),
                  radius: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(context.l10n.colorScheme),
                subtitle: Text(_getColorSchemeDisplayName()),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _showColorSchemePicker,
              ),
            ],
          ),
          _buildSectionCard(
            title: context.l10n.options3D,
            children: [
              SwitchListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(context.l10n.preview3D),
                subtitle: Text(
                  _preview3DSetting
                      ? context.l10n.show3DPreviewSubtitle
                      : context.l10n.hide3DPreviewSubtitle,
                ),
                value: _preview3DSetting,
                onChanged: _toggle3DPreview,
                secondary: const Icon(Icons.view_in_ar_outlined),
              ),
              if (_preview3DSetting) ...[
                const Divider(),
                SwitchListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: Text(context.l10n.adaptiveResolution),
                  subtitle: Text(context.l10n.adaptiveResolutionDescription),
                  value: _adaptiveResolutionSetting,
                  onChanged: _toggleAdaptiveResolution,
                  secondary: const Icon(Icons.speed_rounded),
                ),
                const Divider(),
                ListTile(
                  minLeadingWidth: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: SizedBox.square(
                    dimension: 48,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: _hasCustomSkin && _customSkinAvatarBytes != null
                            ? Image.memory(
                                _customSkinAvatarBytes!,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.none,
                                errorBuilder: (_, _, _) => Image.asset(
                                  'assets/persona_head.png',
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.none,
                                ),
                              )
                            : Image.asset(
                                'assets/persona_head.png',
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.none,
                              ),
                      ),
                    ),
                  ),
                  title: Text(context.l10n.customCharacterSkin),
                  subtitle: Text(
                    _isSavingSkin
                        ? context.l10n.updating3DPersona
                        : (_hasCustomSkin && _customSkinName != null
                              ? context.l10n.activeCustomSkin(_customSkinName!)
                              : context.l10n.defaultMannequin),
                  ),
                  trailing: _isSavingSkin
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_hasCustomSkin) ...[
                              IconButton(
                                icon: const Icon(Icons.refresh_rounded),
                                tooltip: context.l10n.resetDefaults,
                                onPressed: _resetPersonaSkin,
                              ),
                            ],
                            IconButton(
                              icon: const Icon(Icons.file_upload_outlined),
                              tooltip: context.l10n.chooseSkinPng,
                              onPressed: _pickAndApplyCustomSkin,
                            ),
                          ],
                        ),
                  onTap: _isSavingSkin ? null : _pickAndApplyCustomSkin,
                ),
              ],
            ],
          ),
          _buildSectionCard(
            title: context.l10n.languages,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    _selectedLanguage.toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                title: Text(context.l10n.language),
                subtitle: Text(
                  _languageOptions[_selectedLanguage] ?? 'English',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () => _showLanguagePicker(),
              ),
              const Divider(),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    _selectedApiLanguage.toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Row(
                  children: [
                    Text(context.l10n.dlcLanguage),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(context.l10n.dlcLangInfo),
                            content: Text(context.l10n.dlcLangInfoText),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(context.l10n.ok),
                              ),
                            ],
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  _apilanguageOptions[_selectedApiLanguage] ?? 'English',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showLanguagePicker(isApiLanguage: true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
