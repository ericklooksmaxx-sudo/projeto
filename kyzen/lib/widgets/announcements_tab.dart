import 'dart:io';
import 'package:kyzen/l10n/context_extensions.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/announcement.dart';
import '../services/announcements_service.dart';

class AnnouncementsTab extends StatefulWidget {
  const AnnouncementsTab({super.key});

  @override
  State<AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<AnnouncementsTab> {
  bool _isLoading = true;
  String? _error;
  List<Announcement> _announcements = [];

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await AnnouncementsService.fetchAnnouncements(
        forceRefresh: forceRefresh,
      );

      if (!mounted) return;

      setState(() {
        _announcements = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotOpenLink(e.toString()))),
      );
    }
  }

  Widget _buildRefreshButton() {
    return FilledButton.icon(
      onPressed: () => _loadAnnouncements(forceRefresh: true),
      icon: const Icon(Icons.refresh_rounded),
      label: Text(context.l10n.refresh),
    );
  }

  String _formatDate(DateTime date) =>
      DateFormat.yMMMMd().add_jm().format(date.toLocal());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 10),
                Text(
                  context.l10n.failedToLoadAnnouncements,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                _buildRefreshButton(),
              ],
            ),
          ),
        ),
      );
    }

    if (_announcements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.newspaper_rounded,
              size: 48,
              color: colorScheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.noAnnouncementsAvailable,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            _buildRefreshButton(),
          ],
        ),
      );
    }

    final isDesktop = !Platform.isAndroid && !Platform.isIOS;

    // mobile its pull and refresh, on desktop its a refresh button on the corner
    final listView = RefreshIndicator(
      onRefresh: () => _loadAnnouncements(forceRefresh: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        itemCount: _announcements.length,
        itemBuilder: (context, index) {
          final item = _announcements[index];
          return _buildAnnouncementCard(context, item);
        },
      ),
    );

    if (isDesktop) {
      return Stack(
        children: [
          listView,
          Positioned(
            right: 20.0,
            bottom: 20.0,
            child: FloatingActionButton.small(
              heroTag: null,
              onPressed: () => _loadAnnouncements(forceRefresh: true),
              tooltip: context.l10n.refresh,
              child: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      );
    }

    return listView;
  }

  Widget _buildAnnouncementCard(BuildContext context, Announcement item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section
          if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                width: double.infinity,
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                child: CachedNetworkImage(
                  imageUrl: item.imageUrl!,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  placeholder: (context, url) => AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorBuilder: (context, url, error) => AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: colorScheme.outline,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date
                if (item.date != null) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(item.date!),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],

                // Title
                Text(
                  item.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),

                const SizedBox(height: 10),

                // Body
                Text(
                  item.body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.40,
                  ),
                ),

                // Links Section
                if (item.links.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: item.links.map((link) {
                      return ActionChip(
                        avatar: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: Text(link.label),
                        onPressed: () => _openUrl(link.url),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
