import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:win32_registry/win32_registry.dart';

class WindowsDeepLinkRegistration {
  /// Checks if a URL scheme is already registered
  static Future<bool> isSchemeRegistered(String scheme) async {
    if (!Platform.isWindows) return false;

    try {
      String protocolRegKey = 'Software\\Classes\\$scheme';
      final regKey = CURRENT_USER.open(protocolRegKey);

      // If we can open the key and it has the URL Protocol value, it's registered
      final values = regKey.values;
      final isRegistered = values.any((value) => value.name == 'URL Protocol');

      regKey.close();
      return isRegistered;
    } catch (e) {
      return false;
    }
  }

  /// Registers the custom URL scheme in Windows Registry
  /// This allows Windows to open the fucking app and returns the obtained token
  static Future<void> registerScheme(String scheme) async {
    if (!Platform.isWindows) return;

    // Check if already registered
    if (await isSchemeRegistered(scheme)) {
      return;
    }

    try {
      String appPath = Platform.resolvedExecutable;

      String protocolRegKey = 'Software\\Classes\\$scheme';

      const protocolRegValue = RegistryValue.string(
        '',
      ); // Empty value, just needs to exist

      String protocolCmdRegKey = 'shell\\open\\command';

      // this tells Windows how to launch the app with the URL
      final protocolCmdRegValue = RegistryValue.string(
        '"$appPath" "%1"',
      ); // %1 gets replaced with the full URL

      final regKey = CURRENT_USER.create(protocolRegKey);

      regKey.setValue('URL Protocol', protocolRegValue);

      // Create the command subkey and set the executable path
      regKey.create(protocolCmdRegKey).setValue('', protocolCmdRegValue);
    } catch (e) {
      debugPrint('Failed to register URL scheme: $e');
    }
  }

  static Future<void> registerMicrosoftAuthScheme() async {
    await registerScheme('ms-xal-0000000048183522');
  }

  /// Unregisters URL scheme
  /// cmd admin command: reg delete "HKCU\Software\Classes\ms-xal-0000000048183522" /f
  static Future<void> unregisterScheme(String scheme) async {
    if (!Platform.isWindows) return;

    try {
      String protocolRegKey = 'Software\\Classes\\$scheme';
      CURRENT_USER.removeSubkey(protocolRegKey);
      debugPrint('Successfully unregistered URL scheme: $scheme://');
    } catch (e) {
      debugPrint('Failed to unregister URL scheme: $e');
    }
  }
}
