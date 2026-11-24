import 'package:material_ui/material_ui.dart';
import '../models/search_result.dart';

class ItemFaqSection extends StatefulWidget {
  final List<FaqEntry> entries;

  const ItemFaqSection({super.key, required this.entries});

  @override
  State<ItemFaqSection> createState() => _ItemFaqSectionState();
}

class _ItemFaqSectionState extends State<ItemFaqSection> {
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < widget.entries.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
          _buildEntry(i, widget.entries[i], theme),
        ],
      ],
    );
  }

  Widget _buildEntry(int index, FaqEntry entry, ThemeData theme) {
    final isExpanded = _expandedIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          _expandedIndex = isExpanded ? null : index;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.help_outline,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.heading,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topLeft,
              child: isExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(left: 26, top: 6),
                      child: Text(
                        entry.content,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
