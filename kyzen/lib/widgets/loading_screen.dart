import 'package:kyzen/l10n/context_extensions.dart';
import 'package:material_ui/material_ui.dart';

import '../kyzen/kz_boot.dart';
import '../kyzen/kz_motion.dart';
import '../kyzen/kz_surface.dart';
import '../kyzen/kz_tokens.dart';

/// Start-up screen: the Kyzen wordmark over the violet floor, with the three
/// boot steps drawn as one purple-metal bar.
class LoadingScreen extends StatelessWidget {
  final String loadingKey;

  /// Kept for callers that used to pass a Minecraft title image; the Kyzen
  /// splash always shows the wordmark.
  final String? titleAsset;

  const LoadingScreen({super.key, required this.loadingKey, this.titleAsset});

  double get _progress {
    switch (loadingKey) {
      case 'apiLogin':
        return 0.33;
      case 'processingEntitlement':
        return 0.66;
      case 'checkingKeys':
        return 1.0;
      default:
        return 1.0;
    }
  }

  String _message(BuildContext context) {
    switch (loadingKey) {
      case 'apiLogin':
        return context.l10n.apiLogin;
      case 'processingEntitlement':
        return context.l10n.initializingMcDec;
      case 'checkingKeys':
      case 'completed':
        return context.l10n.checkingKeys;
      default:
        return 'Loading…';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String message = _message(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: KzBackdrop(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KzReveal(
                    rise: 18,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Image.asset(
                        'assets/kyzen/wordmark.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  KzReveal(
                    delay: const Duration(milliseconds: 90),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: _BootBar(progress: _progress),
                    ),
                  ),
                  const SizedBox(height: 16),
                  KzFade(
                    child: Text(
                      message,
                      key: ValueKey<String>(message),
                      textAlign: TextAlign.center,
                      style: KzType.meta.copyWith(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // which call the boot is in, and for how long
                  ValueListenableBuilder<String>(
                    valueListenable: KzBoot.status,
                    builder: (context, status, _) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          status,
                          textAlign: TextAlign.center,
                          style: KzType.tiny.copyWith(
                            fontSize: 11,
                            color: status.startsWith('error')
                                ? KzColors.bad
                                : KzColors.ink3,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (KzBoot.tail().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            KzBoot.tail(),
                            textAlign: TextAlign.center,
                            style: KzType.tiny.copyWith(
                              fontSize: 10,
                              color: KzColors.ink3,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BootBar extends StatelessWidget {
  final double progress;

  const _BootBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress),
      duration: const Duration(milliseconds: 520),
      curve: KzMotion.easeOut,
      builder: (context, value, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0x0DFFFFFF),
                    borderRadius: KzRadius.rPill,
                  ),
                ),
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value.clamp(0.0, 1.0),
                    child: DecoratedBox(
                      decoration: kzMetalDecoration(radius: KzRadius.rPill),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: const KzEdgePainter(
                        radius: KzRadius.rPill,
                        ring: KzColors.line2,
                        topEdge: Color(0x1FFFFFFF),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${(value * 100).round()}%',
              style: KzType.tiny.copyWith(color: KzColors.ink2),
            ),
          ],
        );
      },
    );
  }
}
