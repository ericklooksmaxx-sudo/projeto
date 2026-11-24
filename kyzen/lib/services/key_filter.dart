import 'package:kyzen/l10n/context_extensions.dart';
import 'package:material_ui/material_ui.dart';

class KeyFilterType {
  static const String showAll = 'Show all';
  static const String onlyAvailable = 'Only available';
  static const String onlyNotAvailable = 'Only not available';

  // Map internal values to display strings
  static String getDisplayText(BuildContext context, String filterType) {
    switch (filterType) {
      case showAll:
        return context.l10n.showAll;
      case onlyAvailable:
        return context.l10n.onlyAvailable;
      case onlyNotAvailable:
        return context.l10n.onlyNotAvailable;
      default:
        return context.l10n.showAll;
    }
  }

  static Icon getIcon(String filterType) {
    switch (filterType) {
      case onlyAvailable:
        return const Icon(Icons.key_rounded);
      case onlyNotAvailable:
        return const Icon(Icons.key_off_rounded);
      default:
        return const Icon(Icons.list);
    }
  }

  static List<String> get allValues => [
    showAll,
    onlyAvailable,
    onlyNotAvailable,
  ];
}
