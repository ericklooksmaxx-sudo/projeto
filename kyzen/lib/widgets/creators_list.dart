import 'package:material_ui/material_ui.dart';
import '../models/search_result.dart';
import '../services/search_service.dart';
import 'creator_bottom_sheet.dart';

class CreatorResultItem extends StatelessWidget {
  final CreatorResult creator;
  final SearchService searchService;
  final int pageSize;

  const CreatorResultItem({
    super.key,
    required this.creator,
    required this.searchService,
    required this.pageSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _handleCreatorTap(context, creator),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              radius: 24,
              child: Icon(
                Icons.person,
                color: colorScheme.onPrimaryContainer,
                size: 24,
              ),
            ),
            title: Text(
              creator.filterName,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 17),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
          ),
        ),
      ),
    );
  }

  void _handleCreatorTap(BuildContext context, CreatorResult creator) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreatorStatsBottomSheet(
        creator: creator,
        searchService: searchService,
        pageSize: pageSize,
      ),
    );
  }
}
