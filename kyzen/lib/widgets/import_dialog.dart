import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as path;

import '../l10n/context_extensions.dart';
import '../services/minecraft_launcher.dart';
import 'file_icon_helper.dart';

String getDisplayFileName(String filePath) {
  if (filePath.startsWith('content://')) {
    // decode uri for android when using SAF
    final decoded = Uri.decodeFull(filePath);
    return decoded.split('/').last;
  }
  return path.basename(filePath);
}

void showImportDialog(BuildContext context, List<String> filePaths) {
  if (filePaths.isEmpty) return;

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.l10n.importToMc),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: filePaths.map((filePath) {
          final fileName = getDisplayFileName(filePath);
          return ListTile(
            leading: getFileIcon(fileName, dialogContext, useColorFilter: true),
            title: Text(fileName),
            onTap: () {
              Navigator.of(dialogContext).pop();
              MinecraftLauncher.importToMinecraft(filePath, dialogContext);
            },
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dialogContext.l10n.cancel),
        ),
      ],
    ),
  );
}
