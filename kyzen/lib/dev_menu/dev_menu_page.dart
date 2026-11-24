import 'package:kyzen/services/search_service.dart';
import 'package:material_ui/material_ui.dart';

import 'widgets/api_settings_page.dart';
import 'widgets/microsoft_catalog_api_page.dart';
import 'widgets/playfab_api_page.dart';
import 'widgets/cape_render_export_page.dart';

class DevMenuPage extends StatelessWidget {
  final SearchService searchService;

  const DevMenuPage({super.key, required this.searchService});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Dev Menu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildNavTile(
            icon: null,
            title: 'Api Settings',
            leading: ImageFiltered(
              imageFilter: ColorFilter.mode(primary, BlendMode.srcIn),
              child: Image.asset('assets/api.png', width: 24, height: 24),
            ),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ApiSettingsPage())),
          ),
          _buildNavTile(
            icon: null,
            title: 'PlayFab API',
            leading: ImageFiltered(
              imageFilter: ColorFilter.mode(primary, BlendMode.srcIn),
              child: Image.asset('assets/playfab.png', width: 24, height: 24),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlayFabApiPage(searchService: searchService),
              ),
            ),
          ),
          _buildNavTile(
            icon: null,
            title: 'Microsoft Catalog API',
            leading: Image.asset('assets/microslop.png', width: 24, height: 24),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MicrosoftCatalogApiPage(),
              ),
            ),
          ),
          _buildNavTile(
            icon: null,
            title: '3D Cape Renderer',
            leading: ImageFiltered(
              imageFilter: ColorFilter.mode(primary, BlendMode.srcIn),
              child: Image.asset('assets/cape.png', width: 24, height: 24),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CapeRenderExportPage()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile({
    required IconData? icon,
    required String title,
    required VoidCallback onTap,
    Widget? leading,
  }) {
    return ListTile(
      leading: leading ?? Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}
