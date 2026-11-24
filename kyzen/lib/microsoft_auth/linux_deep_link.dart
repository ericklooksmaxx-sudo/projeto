import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

class LinuxDeepLink {
  static Future<String> createTempDesktopEntry({
    String? explicitExecPath,
    String scheme = 'ms-xal-0000000048183522',
    String appName = 'Kyzen',
  }) async {
    if (!Platform.isLinux) {
      throw UnsupportedError('This helper only supports Linux.');
    }

    final execPath = explicitExecPath ?? Platform.resolvedExecutable;

    final execFile = File(execPath);
    if (!await execFile.exists()) {
      throw ArgumentError('Executable not found at $execPath');
    }

    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      throw StateError('HOME environment variable is not set.');
    }

    final xdgDataHome =
        Platform.environment['XDG_DATA_HOME'] ?? '$home/.local/share';
    final desktopDir = Directory('$xdgDataHome/applications');
    await desktopDir.create(recursive: true);

    final rnd = Random().nextInt(1 << 31);
    final desktopBasename = 'kyzen-temp-$rnd.desktop';
    final desktopPath = '${desktopDir.path}/$desktopBasename';

    final execQuoted = execPath.contains(' ') ? '"$execPath"' : execPath;

    final desktopContent = StringBuffer()
      ..writeln('[Desktop Entry]')
      ..writeln('Name=$appName')
      ..writeln('GenericName=$appName')
      ..writeln('Exec=$execQuoted %u')
      ..writeln('Icon=kyzen')
      ..writeln('Type=Application')
      ..writeln('MimeType=x-scheme-handler/$scheme;')
      ..writeln('Categories=Utility')
      ..writeln('Keywords=Application');

    final desktopFile = File(desktopPath);
    await desktopFile.writeAsString(desktopContent.toString(), flush: true);

    await _safeRun('chmod', ['644', desktopPath]);

    await _safeRun('xdg-mime', [
      'default',
      desktopBasename,
      'x-scheme-handler/$scheme',
    ]);

    await _safeRun('update-desktop-database', [desktopDir.path]);

    return desktopPath;
  }

  static Future<void> cleanupTempDesktopEntries({
    String scheme = 'ms-xal-0000000048183522',
  }) async {
    if (!Platform.isLinux) return;

    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return;

    final xdgDataHome =
        Platform.environment['XDG_DATA_HOME'] ?? '$home/.local/share';
    final desktopDir = Directory('$xdgDataHome/applications');

    if (await desktopDir.exists()) {
      await for (final entity in desktopDir.list()) {
        if (entity is File) {
          final name = entity.uri.pathSegments.isNotEmpty
              ? entity.uri.pathSegments.last
              : entity.path;
          if (name.startsWith('kyzen-temp-') && name.endsWith('.desktop')) {
            try {
              await entity.delete();
            } catch (e) {
              debugPrint('Failed to delete temporary desktop file: $name');
            }
          }
        }
      }
    }

    final mimeapps = File('$home/.config/mimeapps.list');
    if (await mimeapps.exists()) {
      final lines = await mimeapps.readAsLines();
      final filtered = lines
          .where((l) => !l.contains('x-scheme-handler/$scheme'))
          .toList();
      final backup = File('${mimeapps.path}.bak');
      await mimeapps.copy(backup.path);
      await mimeapps.writeAsString(filtered.join('\n'), flush: true);
    }

    await _safeRun('update-desktop-database', ['$xdgDataHome/applications']);
  }

  static Future<ProcessResult?> _safeRun(
    String program,
    List<String> args,
  ) async {
    try {
      final pr = await Process.run(program, args);
      return pr;
    } on ProcessException catch (e) {
      debugPrint(
        'Failed to run $program with args: ${args.join(' ')}: ${e.message}',
      );
      return null;
    }
  }
}
