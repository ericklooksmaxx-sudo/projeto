import 'package:kyzen/models/home_discovery_data.dart';
import 'package:kyzen/models/search_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeDiscoveryData tests', () {
    test('isEmpty returns true when all lists are empty', () {
      final data = HomeDiscoveryData(
        spotlight: [],
        newReleases: [],
        addons: [],
        scaryDlc: [],
        worlds: [],
        sounds: [],
        textures: [],
        mashups: [],
        timestamp: DateTime.now(),
      );

      expect(data.isEmpty, isTrue);
    });

    test('isEmpty returns false when any list has items', () {
      final sampleItem = SearchResult(
        title: 'Epic Pack',
        creator: 'Creator Team',
        description: 'An epic discovery pack',
        downloadUrls: ['https://example.com/dl'],
        dlcId: 'dlc-1234',
        packType: 'Addon',
        extraImages: [],
        isOwned: true,
        hasVibrantVisuals: false,
        creationDate: '2026-08-01T00:00:00Z',
        lastModifiedDate: '2026-08-02T00:00:00Z',
      );

      final data = HomeDiscoveryData(
        spotlight: [sampleItem],
        newReleases: [],
        addons: [],
        scaryDlc: [],
        worlds: [],
        sounds: [],
        textures: [],
        mashups: [],
        timestamp: DateTime.now(),
      );

      expect(data.isEmpty, isFalse);
      expect(data.spotlight.length, 1);
      expect(data.spotlight.first.title, 'Epic Pack');
      expect(data.spotlight.first.isOwned, isTrue);
    });

    test('isEmpty returns false when sounds list has items', () {
      final sampleSound = SearchResult(
        title: 'Music & Sounds Pack',
        creator: 'Sound Designer',
        description: 'Atmospheric audio tracks',
        downloadUrls: ['https://example.com/sound'],
        dlcId: 'dlc-sound-1',
        packType: 'Sounds',
        extraImages: [],
        isOwned: false,
        hasVibrantVisuals: false,
        creationDate: '2026-08-01T00:00:00Z',
        lastModifiedDate: '2026-08-02T00:00:00Z',
      );

      final data = HomeDiscoveryData(
        spotlight: [],
        newReleases: [],
        addons: [],
        scaryDlc: [],
        worlds: [],
        sounds: [sampleSound],
        textures: [],
        mashups: [],
        timestamp: DateTime.now(),
      );

      expect(data.isEmpty, isFalse);
      expect(data.sounds.length, 1);
      expect(data.sounds.first.title, 'Music & Sounds Pack');
      expect(data.sounds.first.packType, 'Sounds');
    });
  });
}
