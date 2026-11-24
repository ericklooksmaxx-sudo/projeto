import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyzen/decrypt/dlc_dec.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('Deterministic UUID v4 & replaceUuidsInManifest', () {
    test(
      'generateDeterministicUuidV4 produces valid, deterministic RFC 4122 v4 UUIDs',
      () {
        const orig = '2907ab39-4cf7-4c2b-9f1b-da02decc378f';

        final uuid1 = generateDeterministicUuidV4(orig, salt: 'header');
        final uuid2 = generateDeterministicUuidV4(orig, salt: 'header');

        // 1. Must be strictly deterministic
        expect(uuid1, equals(uuid2));

        // 2. Must differ from original
        expect(uuid1, isNot(equals(orig)));

        // 3. Must be valid UUID format
        expect(Uuid.isValidUUID(fromString: uuid1), isTrue);

        // 4. Must strictly be UUID Version 4
        expect(uuid1[14], equals('4'));
        expect(['8', '9', 'a', 'b'].contains(uuid1[19].toLowerCase()), isTrue);
      },
    );

    test(
      'replaceUuidsInManifest only replaces the header uuid and preserves modules/dependencies',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('manifest_test_');
        final manifestFile = File('${tempDir.path}/manifest.json');

        final sampleManifest = {
          "format_version": 2,
          "header": {
            "name": "pack.name",
            "description": "pack.description",
            "uuid": "5acd2ffe-b384-4521-8765-9884ed377d7f",
            "version": [1, 0, 1],
            "min_engine_version": [1, 26, 0],
            "pack_scope": "world",
          },
          "metadata": {"product_type": "addon"},
          "modules": [
            {
              "description": "Resource",
              "type": "resources",
              "uuid": "256ffc3c-dbac-47a3-a865-9648000efa2b",
              "version": [1, 0, 1],
            },
          ],
          "dependencies": [
            {
              "uuid": "43b818d9-a9f7-4d22-bc2c-eeb6d96bc769",
              "version": [1, 0, 1],
            },
          ],
          "capabilities": ["pbr"],
        };

        await manifestFile.writeAsString(jsonEncode(sampleManifest));

        // Replace UUIDs
        await replaceUuidsInManifest(manifestFile.path);

        final result = jsonDecode(await manifestFile.readAsString());

        // Header UUID must be replaced and deterministic
        expect(
          result['header']['uuid'],
          isNot(equals("5acd2ffe-b384-4521-8765-9884ed377d7f")),
        );
        expect(
          result['header']['uuid'],
          equals(
            generateDeterministicUuidV4(
              "5acd2ffe-b384-4521-8765-9884ed377d7f",
              salt: 'header',
            ),
          ),
        );

        // Modules must remain unchanged
        expect(
          result['modules'][0]['uuid'],
          equals("256ffc3c-dbac-47a3-a865-9648000efa2b"),
        );

        // Dependencies pointing to a companion pack header must be updated to match the new header uuid
        expect(
          result['dependencies'][0]['uuid'],
          equals(
            generateDeterministicUuidV4(
              "43b818d9-a9f7-4d22-bc2c-eeb6d96bc769",
              salt: 'header',
            ),
          ),
        );

        // Clean up
        await tempDir.delete(recursive: true);
      },
    );

    test(
      'addon BP and RP remain linked through updated dependency uuid',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'addon_link_test_',
        );
        final rpDir = Directory('${tempDir.path}/RP')..createSync();
        final bpDir = Directory('${tempDir.path}/BP')..createSync();

        const rpHeaderUuid = 'b56eb0ad-7637-2f47-52b1-0f13bceede49';
        const bpHeaderUuid = '11111111-2222-3333-4444-555555555555';

        final rpManifest = File('${rpDir.path}/manifest.json');
        await rpManifest.writeAsString(
          jsonEncode({
            "format_version": 2,
            "header": {
              "name": "Chop Chop RP",
              "uuid": rpHeaderUuid,
              "version": [1, 0, 6],
            },
            "modules": [
              {
                "type": "resources",
                "uuid": "66666666-7777-8888-9999-000000000000",
                "version": [1, 0, 6],
              },
            ],
          }),
        );

        final bpManifest = File('${bpDir.path}/manifest.json');
        await bpManifest.writeAsString(
          jsonEncode({
            "format_version": 2,
            "header": {
              "name": "Chop Chop BP",
              "uuid": bpHeaderUuid,
              "version": [1, 0, 6],
            },
            "modules": [
              {
                "type": "data",
                "uuid": "77777777-8888-9999-0000-111111111111",
                "version": [1, 0, 6],
              },
            ],
            "dependencies": [
              {
                "uuid": rpHeaderUuid,
                "version": [1, 0, 6],
              },
            ],
          }),
        );

        // Process both manifests
        await replaceUuidsInManifest(rpManifest.path);
        await replaceUuidsInManifest(bpManifest.path);

        final rpResult = jsonDecode(await rpManifest.readAsString());
        final bpResult = jsonDecode(await bpManifest.readAsString());

        // The new RP header UUID and the new BP dependency UUID must match exactly!
        final newRpHeaderUuid = rpResult['header']['uuid'];
        final newBpDepUuid = bpResult['dependencies'][0]['uuid'];

        expect(newRpHeaderUuid, equals(newBpDepUuid));
        expect(newRpHeaderUuid, isNot(equals(rpHeaderUuid)));

        await tempDir.delete(recursive: true);
      },
    );

    test(
      'persona piece manifest replaces header uuid and preserves module uuid',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'persona_piece_test_',
        );
        final manifestFile = File('${tempDir.path}/manifest.json');

        const personaJson =
            '{"format_version":1,"header":{"description":"pack.description","name":"pack.name","uuid":"c103b355-4b95-dc68-0d04-a8cf6ba8cc2d","version":[1,0,0]},"modules":[{"type":"persona_piece","uuid":"f925fa97-f08b-89d2-12b9-3f35c7c5c9f6","version":[1,0,0]}]}';

        await manifestFile.writeAsString(personaJson);
        await replaceUuidsInManifest(manifestFile.path);

        final result = jsonDecode(await manifestFile.readAsString());

        // Header uuid must be replaced deterministically
        expect(
          result['header']['uuid'],
          isNot(equals('c103b355-4b95-dc68-0d04-a8cf6ba8cc2d')),
        );
        expect(
          result['header']['uuid'],
          equals(
            generateDeterministicUuidV4(
              'c103b355-4b95-dc68-0d04-a8cf6ba8cc2d',
              salt: 'header',
            ),
          ),
        );

        // Module uuid must remain untouched
        expect(
          result['modules'][0]['uuid'],
          equals('f925fa97-f08b-89d2-12b9-3f35c7c5c9f6'),
        );

        await tempDir.delete(recursive: true);
      },
    );

    test(
      'mashup world template updates external texture pack id while preserving internal subpacks',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('mashup_test_');

        // 1. Create external texture pack manifest
        final texturePackDir = Directory('${tempDir.path}/texture_pack')
          ..createSync();
        final textureManifest = File('${texturePackDir.path}/manifest.json');
        const texturePackHeaderUuid = '5aaa8b16-cf1e-4abe-9202-3f749bd89501';
        await textureManifest.writeAsString(
          jsonEncode({
            "format_version": 2,
            "header": {
              "name": "RealismCraft Texture Pack",
              "uuid": texturePackHeaderUuid,
              "version": [1, 0, 86],
            },
            "modules": [
              {
                "type": "resources",
                "uuid": "2be875b6-3001-408a-a65c-3435d32b6f6c",
                "version": [1, 0, 86],
              },
            ],
          }),
        );

        // 2. Create world template with internal subpacks rp0 and bp0
        final worldDir = Directory('${tempDir.path}/world_template')
          ..createSync();
        final rp0Dir = Directory('${worldDir.path}/resource_packs/rp0')
          ..createSync(recursive: true);
        final bp0Dir = Directory('${worldDir.path}/behavior_packs/bp0')
          ..createSync(recursive: true);

        const rp0HeaderUuid = '9183af09-928c-45b7-9344-4c182cafdd81';
        const bp0HeaderUuid = 'ffc5f3ad-11b0-4551-b80e-4e7cdd22993c';

        final rp0Manifest = File('${rp0Dir.path}/manifest.json');
        await rp0Manifest.writeAsString(
          jsonEncode({
            "format_version": 2,
            "header": {
              "name": "rp0",
              "uuid": rp0HeaderUuid,
              "version": [1, 0, 86],
            },
            "modules": [
              {
                "type": "resources",
                "uuid": "5763256d-09df-4e78-86db-401117487b21",
                "version": [1, 0, 86],
              },
            ],
            "dependencies": [
              {
                "uuid": bp0HeaderUuid,
                "version": [1, 0, 86],
              },
            ],
          }),
        );

        final bp0Manifest = File('${bp0Dir.path}/manifest.json');
        await bp0Manifest.writeAsString(
          jsonEncode({
            "format_version": 2,
            "header": {
              "name": "bp0",
              "uuid": bp0HeaderUuid,
              "version": [1, 0, 86],
            },
            "modules": [
              {
                "type": "data",
                "uuid": "57406b58-2f9a-431b-861d-90739e972852",
                "version": [1, 0, 86],
              },
            ],
            "dependencies": [
              {
                "uuid": rp0HeaderUuid,
                "version": [1, 0, 86],
              },
            ],
          }),
        );

        // 3. Create world_resource_packs.json & world_behavior_packs.json
        final wrpFile = File('${worldDir.path}/world_resource_packs.json');
        await wrpFile.writeAsString(
          jsonEncode([
            {
              "pack_id": rp0HeaderUuid,
              "version": [1, 0, 86],
            },
            {
              "pack_id": texturePackHeaderUuid,
              "version": [1, 0, 86],
            },
          ]),
        );

        final wbpFile = File('${worldDir.path}/world_behavior_packs.json');
        await wbpFile.writeAsString(
          jsonEncode([
            {
              "pack_id": bp0HeaderUuid,
              "version": [1, 0, 86],
            },
          ]),
        );

        // 4. Process texture pack manifest
        await replaceUuidsInManifest(textureManifest.path);
        final textureResult = jsonDecode(await textureManifest.readAsString());
        final newTextureUuid = textureResult['header']['uuid'];
        expect(
          newTextureUuid,
          equals(
            generateDeterministicUuidV4(texturePackHeaderUuid, salt: 'header'),
          ),
        );

        // 5. Update world template pack references
        await updateWorldTemplatePackReferences(worldDir.path);

        // 6. Verify world_resource_packs.json
        final updatedWrp = jsonDecode(await wrpFile.readAsString()) as List;
        expect(updatedWrp.length, equals(2));
        // Internal rp0 must remain untouched
        expect(updatedWrp[0]['pack_id'], equals(rp0HeaderUuid));
        // External texture pack must match the new texture pack header UUID
        expect(updatedWrp[1]['pack_id'], equals(newTextureUuid));

        // 7. Verify world_behavior_packs.json
        final updatedWbp = jsonDecode(await wbpFile.readAsString()) as List;
        expect(updatedWbp.length, equals(1));
        // Internal bp0 must remain untouched
        expect(updatedWbp[0]['pack_id'], equals(bp0HeaderUuid));

        // 8. Verify internal subpack manifests were NOT modified
        final rp0Result = jsonDecode(await rp0Manifest.readAsString());
        expect(rp0Result['header']['uuid'], equals(rp0HeaderUuid));
        expect(rp0Result['dependencies'][0]['uuid'], equals(bp0HeaderUuid));

        final bp0Result = jsonDecode(await bp0Manifest.readAsString());
        expect(bp0Result['header']['uuid'], equals(bp0HeaderUuid));
        expect(bp0Result['dependencies'][0]['uuid'], equals(rp0HeaderUuid));

        await tempDir.delete(recursive: true);
      },
    );
  });
}
