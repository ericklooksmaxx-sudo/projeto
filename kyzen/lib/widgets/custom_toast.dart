import 'package:material_ui/material_ui.dart';

import '../kyzen/kz_surface.dart';
import '../kyzen/kz_tokens.dart';

/// Kyzen toast: floating glass, green or red edge, rises in and fades out.
class CustomToast {
  static void showToast({
    required BuildContext context,
    required String message,
    bool isSuccess = true,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final Color tone = isSuccess ? KzColors.ok : KzColors.bad;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: duration + const Duration(milliseconds: 400),
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.only(bottom: 14, left: 16, right: 16),
        content: Center(
          child: _AnimatedToastContent(
            duration: duration,
            child: Material(
              color: Colors.transparent,
              child: KzGlass(
                floating: true,
                radius: const BorderRadius.all(Radius.circular(20)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSuccess
                          ? Icons.check_circle_outline_rounded
                          : Icons.error_outline_rounded,
                      size: 20,
                      color: tone,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        message,
                        textAlign: TextAlign.left,
                        style: KzType.body.copyWith(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void dismissToast({BuildContext? context}) {
    if (context != null) {
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    }
  }
}

class _AnimatedToastContent extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const _AnimatedToastContent({required this.child, required this.duration});

  @override
  State<_AnimatedToastContent> createState() => _AnimatedToastContentState();
}

class _AnimatedToastContentState extends State<_AnimatedToastContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: KzMotion.enter,
    reverseDuration: const Duration(milliseconds: 240),
    vsync: this,
  );

  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: KzMotion.easeOut,
    reverseCurve: KzMotion.easeIo,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();

    Future<void>.delayed(widget.duration, () async {
      if (!mounted) return;
      await _controller.reverse();
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) {
        final double v = _t.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - v)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
