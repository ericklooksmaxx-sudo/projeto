import 'search_result.dart';

class HomeDiscoveryData {
  final List<SearchResult> spotlight;
  final List<SearchResult> newReleases;
  final List<SearchResult> addons;
  final List<SearchResult> scaryDlc;
  final List<SearchResult> worlds;
  final List<SearchResult> sounds;
  final List<SearchResult> textures;
  final List<SearchResult> mashups;
  final DateTime timestamp;

  const HomeDiscoveryData({
    required this.spotlight,
    required this.newReleases,
    required this.addons,
    required this.scaryDlc,
    required this.worlds,
    required this.sounds,
    required this.textures,
    required this.mashups,
    required this.timestamp,
  });

  bool get isEmpty =>
      spotlight.isEmpty &&
      newReleases.isEmpty &&
      addons.isEmpty &&
      scaryDlc.isEmpty &&
      worlds.isEmpty &&
      sounds.isEmpty &&
      textures.isEmpty &&
      mashups.isEmpty;
}
