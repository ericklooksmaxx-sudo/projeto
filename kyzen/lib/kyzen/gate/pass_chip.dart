import 'package:material_ui/material_ui.dart';

import '../kz_motion.dart';
import '../kz_surface.dart';
import '../kz_tokens.dart';
import 'gate_page.dart';
import 'pass_service.dart';

/// The site's `.pass-chip`, in the app: purple capsule while locked, green
/// while the 24 h pass is running, and it opens the gate when tapped.
class KzPassChip extends StatelessWidget {
  final String? dlcId;
  final bool compact;

  const KzPassChip({super.key, this.dlcId, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final KzPass pass = KzPass.instance;

    return AnimatedBuilder(
      animation: pass,
      builder: (context, _) {
        final bool on = pass.active;
        final Color ink = on ? KzColors.ok : KzColors.p100;
        final Color ring = on
            ? const Color(0x6646D18A)
            : const Color(0x57BB92FF);
        final Color fill = on
            ? const Color(0x1A46D18A)
            : const Color(0x336F0ECF);
        final String label = on
            ? (compact ? pass.remainingLabel : 'Pass · ${pass.remainingLabel}')
            : (compact ? 'Unlock' : 'Unlock 24 h');

        return KzPressable(
          onTap: () => KzGatePage.open(context, dlcId: dlcId),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: KzMotion.hover,
                curve: Curves.linear,
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: KzRadius.rPill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Dot(on: on, busy: pass.busy || pass.checking),
                    const SizedBox(width: 8),
                    KzFade(
                      child: Text(
                        label,
                        key: ValueKey<String>(label),
                        style: KzType.label.copyWith(color: ink),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: KzEdgePainter(
                      radius: KzRadius.rPill,
                      ring: ring,
                      topEdge: const Color(0x29FFFFFF),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Dot extends StatefulWidget {
  final bool on;
  final bool busy;

  const _Dot({required this.on, required this.busy});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = widget.on ? KzColors.ok : KzColors.p400;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final double t = widget.busy ? _c.value : 1.0;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.45 + (0.55 * t)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5 * t),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}
