import 'package:material_ui/material_ui.dart';
import 'package:kyzen/l10n/context_extensions.dart';

import '../kyzen/kz_motion.dart';
import '../kyzen/kz_surface.dart';
import '../kyzen/kz_tokens.dart';
import '../services/announcements_service.dart';

/// The site's mobile bar, in the app: a floating glass capsule, the active tab
/// lit by a white gradient with a lavender ring, everything moving on scale.
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    return Directionality(
      textDirection: TextDirection.ltr, // the bar is never mirrored
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, 6, 10, 10 + bottomInset),
        child: KzGlass(
          radius: const BorderRadius.all(Radius.circular(26)),
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: context.l10n.home,
                  selected: currentIndex == 0,
                  onTap: () => onTap(0),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.download_outlined,
                  activeIcon: Icons.download,
                  label: context.l10n.downloads,
                  selected: currentIndex == 1,
                  onTap: () => onTap(1),
                ),
              ),
              Expanded(
                child: ValueListenableBuilder<bool>(
                  valueListenable: AnnouncementsService.hasUnreadNotifier,
                  builder: (context, hasUnread, child) {
                    return _NavItem(
                      icon: Icons.newspaper_outlined,
                      activeIcon: Icons.newspaper,
                      label: context.l10n.news,
                      selected: currentIndex == 2,
                      dot: hasUnread,
                      onTap: () => onTap(2),
                    );
                  },
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  label: context.l10n.settings,
                  selected: currentIndex == 3,
                  onTap: () => onTap(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final bool dot;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color ink = selected ? Colors.white : KzColors.ink3;

    return KzPressable(
      scale: 0.94,
      onTap: onTap,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: KzMotion.hover,
            curve: Curves.linear,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(20)),
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x26FFFFFF), Color(0x0BFFFFFF)],
                    )
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedScale(
                      duration: KzMotion.release,
                      curve: KzMotion.spring,
                      scale: selected ? 1.0 : 0.94,
                      child: Icon(
                        selected ? activeIcon : icon,
                        size: 21,
                        color: ink,
                      ),
                    ),
                    if (dot)
                      Positioned(
                        right: -3,
                        top: -2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: KzColors.p400,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: KzColors.bg,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KzType.tiny.copyWith(
                    fontSize: 11,
                    color: ink,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: const KzEdgePainter(
                    radius: BorderRadius.all(Radius.circular(20)),
                    ring: Color(0x33BB92FF),
                    topEdge: Color(0x3DFFFFFF),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
