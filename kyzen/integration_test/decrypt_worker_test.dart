import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kyzen/decrypt/aes_256_cfb8.dart';


// flutter test integration_test/decrypt_worker_test.dart 
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late DecryptWorker worker;

  setUp(() {
    worker = DecryptWorker();
  });

  tearDown(() {
    worker.dispose();
  });

  testWidgets('throws informative error when file does not exist', (tester) async {
    await expectLater(
      () => worker.decryptFile(
        inputPath: '/this/does/not/exist.bin',
        outputPath: '/tmp/out.bin',
        key: 'hY266wgXKamr2i1HXigOBlsMKBwSQ1cM',
      ),
      throwsA(
        predicate((e) =>
          e is Exception &&
          e.toString().contains('errno')
        ),
      ),
    );
  });

  testWidgets('decrypts contents.json and result is valid json', (tester) async {
    final inputPath = 'integration_test/contents.json';
    final outputPath = '${Directory.systemTemp.path}/contents_decrypted.json';

    await worker.decryptFile(
      inputPath: inputPath,
      outputPath: outputPath,
      key: 'xV4pizMlpmru7wsMxvGF45kh7cwtkicQ',
    );

    final decryptedFile = File(outputPath);
    expect(decryptedFile.existsSync(), true, reason: 'Decrypted file should exist');

    final content = decryptedFile.readAsStringSync();
    expect(() => jsonDecode(content), returnsNormally, reason: 'Decrypted content should be valid JSON');
  });
}