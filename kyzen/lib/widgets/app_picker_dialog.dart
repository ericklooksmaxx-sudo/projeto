import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import '../l10n/context_extensions.dart';
import '../services/minecraft_launcher.dart';
import '../models/installed_apps.dart';

class AppPickerDialog extends StatefulWidget {
  const AppPickerDialog({super.key});

  @override
  State<AppPickerDialog> createState() => _AppPickerDialogState();
}

class _AppPickerDialogState extends State<AppPickerDialog> {
  List<InstalledApp> _allApps = [];
  List<InstalledApp> _filtered = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  // Cache icons so we don't re-fetch on scroll
  final Map<String, Uint8List?> _iconCache = {};

  @override
  void initState() {
    super.initState();
    _loadApps();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    final apps = await MinecraftLauncher.getInstalledApps();
    if (mounted) {
      setState(() {
        _allApps = apps;
        _filtered = apps;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _allApps.where((app) {
        return app.appName.toLowerCase().contains(query) ||
            app.packageName.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<Uint8List?> _getIcon(String packageName) async {
    if (_iconCache.containsKey(packageName)) return _iconCache[packageName];
    final icon = await MinecraftLauncher.getAppIcon(packageName);
    _iconCache[packageName] = icon;
    return icon;
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(viewInsets: EdgeInsets.zero),
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title row with close button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.selectApp,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: context.l10n.hintText,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            Flexible(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    )
                  : _filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(context.l10n.noAppsFound),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final app = _filtered[index];
                        return ListTile(
                          leading: FutureBuilder<Uint8List?>(
                            future: _getIcon(app.packageName),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data != null) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    snapshot.data!,
                                    width: 48,
                                    height: 48,
                                    gaplessPlayback: true,
                                  ),
                                );
                              }
                              return const SizedBox(
                                width: 48,
                                height: 48,
                                child: Icon(Icons.android_rounded),
                              );
                            },
                          ),
                          title: Text(app.appName),
                          subtitle: Text(
                            app.packageName,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () async {
                            final icon = await _getIcon(app.packageName);
                            if (context.mounted) {
                              Navigator.of(
                                context,
                              ).pop((packageName: app.packageName, icon: icon));
                            }
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
