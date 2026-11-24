import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'settings_service.dart';
import '../models/installed_apps.dart';

class MinecraftLauncher {
  static const platform = MethodChannel('xyz.kyzendlc.app/import');

  // i can use url_launcher, but it doesnt work with some uri like showDressingRoomOffer so im not using it
  static Future<void> openInMinecraft(
    String packType,
    String dlcId,
    BuildContext context,
  ) async {
    final String uri;
    // get uri scheme https://github.com/phasephasephase/MCBEProtocolURIs
    if (packType == 'Persona') {
      uri =
          'minecraft://showDressingRoomOffer?offerID=$dlcId'; // persona uri scheme
    } else {
      uri =
          'minecraft://domain?showStoreOffer=$dlcId'; // regular dlc uri scheme
    }

    try {
      await platform.invokeMethod('openMinecraftUri', {'uri': uri});
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open Minecraft: ${e.toString()}')),
        );
      }
    }
  }

  // importing files to Minecraft
  static Future<void> importToMinecraft(
    String filePath,
    BuildContext context,
  ) async {
    try {
      final packageName = await SettingsService.instance
          .getMinecraftPackageName();

      final result = await platform.invokeMethod('getContentUri', {
        'filePath': filePath,
        'packageName': packageName,
      });
      debugPrint("Launch result: $result");
    } on PlatformException catch (e) {
      if (context.mounted) {
        debugPrint("Failed to launch Minecraft: ${e.message}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to launch Minecraft: ${e.message}')),
        );
      }
    }
  }

  static Future<List<InstalledApp>> getInstalledApps() async {
    try {
      final List<dynamic> raw = await platform.invokeMethod('getInstalledApps');
      return raw
          .map((e) => InstalledApp.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } on PlatformException catch (e) {
      debugPrint('Failed to get installed apps: ${e.message}');
      return [];
    }
  }

  static Future<Uint8List?> getAppIcon(String packageName) async {
    try {
      final String base64Icon = await platform.invokeMethod('getAppIcon', {
        'packageName': packageName,
      });
      return base64Decode(base64Icon);
    } on PlatformException catch (e) {
      debugPrint('Failed to get icon for $packageName: ${e.message}');
      return null;
    }
  }

  static Future<File> _iconCacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/minecraft_app_icon.png');
  }

  static Future<void> saveSelectedAppIcon(Uint8List iconBytes) async {
    final file = await _iconCacheFile();
    await file.writeAsBytes(iconBytes);
  }

  static Future<Uint8List?> loadSavedAppIcon() async {
    final file = await _iconCacheFile();
    if (await file.exists()) return await file.readAsBytes();
    return null;
  }

  static Future<void> clearSavedAppIcon() async {
    final file = await _iconCacheFile();
    if (await file.exists()) await file.delete();
  }
}
