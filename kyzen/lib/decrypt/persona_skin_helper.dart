import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../services/http_client.dart';
import 'dlc_dec.dart';

const String personaKey = 's5s5ejuDru4uchuF2drUFuthaspAbepE';

Future<void> downloadZip({
  required String url,
  required String savePath,
  void Function(double progress)? onProgress,
}) async {
  final request = http.Request('GET', Uri.parse(url));
  request.headers.addAll({
    'User-Agent': 'libhttpclient/1.0.0.0',
    'Accept-Encoding': 'gzip, deflate, br',
    'Connection': 'Keep-Alive',
  });

  final response = await AppHttpClient.instance.send(request);

  if (response.statusCode != 200) {
    throw Exception('Failed to download zip. Status: ${response.statusCode}');
  }

  final contentLength = response.contentLength ?? 0;
  int receivedBytes = 0;
  final sink = File(savePath).openWrite();

  try {
    await response.stream.forEach((chunk) {
      sink.add(chunk);
      receivedBytes += chunk.length;
      if (contentLength > 0 && onProgress != null) {
        onProgress(receivedBytes / contentLength);
      }
    });
    await sink.flush();
    await sink.close();
  } catch (e) {
    await sink.close();
    rethrow;
  }
}

Future<void> decryptPersonaFolders(
  List<String> folderPaths, {
  void Function(double progress)? onProgress,
  String key = personaKey,
}) async {
  final folderCount = folderPaths.length;
  if (folderCount == 0) return;

  for (int i = 0; i < folderCount; i++) {
    onProgress?.call(i / folderCount);

    final contentsJsonPaths = await findContentsJsonFiles(folderPaths[i]);
    for (final contentsFilePath in contentsJsonPaths) {
      await decryptFileWithKey(contentsFilePath, key);
      final decryptedBytes = await File(contentsFilePath).readAsBytes();
      await processDecryptedContentsJson(
        utf8.decode(decryptedBytes),
        contentsFilePath,
      );
    }
  }

  onProgress?.call(1.0);
}

Future<List<String>> extractAndDecryptPersonaZip({
  required String zipPath,
  required String outputDir,
  void Function(double progress)? onProgress,
  String key = personaKey,
}) async {
  final nestedFolders = await extractZip(zipPath, outputDir);
  if (nestedFolders.isEmpty) {
    throw Exception('No valid folders found in zip.');
  }

  await decryptPersonaFolders(nestedFolders, onProgress: onProgress, key: key);

  return nestedFolders;
}
