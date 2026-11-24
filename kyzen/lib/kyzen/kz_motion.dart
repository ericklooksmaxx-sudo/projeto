import 'package:material_ui/material_ui.dart';

import 'kz_tokens.dart';

/// Page transition used for every route: the incoming page rises 16 px and
/// fades in on --ease-out, the outgoing page sinks slightly and fades.
/// Same feel as the site's view transitions, no platform chrome.
class KzPageTransitionsBuilder extends PageTransitionsBuilder {
  const KzPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return KzPageTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

/// The transition itself, reusable by [KzPageRoute].
class KzPageTransition extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  const KzPageTransition({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final enter = CurvedAnimation(
      parent: animation,
      curve: KzMotion.easeOut,
      reverseCurve: KzMotion.easeIo,
    );
    final leave = CurvedAnimation(
      parent: secondaryAnimation,
      curve: KzMotion.easeOut,
      reverseCurve: KzMotion.easeIo,
    );

    return AnimatedBuilder(
      animation: leave,
      builder: (context, inner) {
        // the page underneath sinks a touch and dims while a new one covers it
        final double away = leave.value;
        return Transform.translate(
          offset: Offset(0, -10 * away),
          child: Opacity(opacity: 1 - (0.35 * away), child: inner),
        );
      },
      child: AnimatedBuilder(
        animation: enter,
        builder: (context, inner) {
          final double t = enter.value;
          return Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - t)),
              child: Transform.scale(
                scale: 0.99 + (0.01 * t),
                child: inner,
              ),
            ),
          );
        },
        child: child,
      ),
    );
  }
}

/// Route that uses the Kyzen transition even when pushed outside MaterialApp's
/// theme (dialog-ish pages, the gate).
class KzPageRoute<T> extends PageRouteBuilder<T> {
  KzPageRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool fullscreenDialog = false,
  }) : super(
         settings: settings,
         fullscreenDialog: fullscreenDialog,
         transitionDuration: KzMotion.page,
         reverseTransitionDuration: KzMotion.pageBack,
         opaque: true,
         barrierColor: KzColors.bg,
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionsBuilder:
             (context, animation, secondaryAnimation, child) =>
                 KzPageTransition(
                   animation: animation,
                   secondaryAnimation: secondaryAnimation,
                   child: child,
                 ),
       );
}

/// Shrinks a touch while held, like `.btn:active { transform: scale(.96) }`.
/// It does not swallow the gesture: the child keeps its own hit testing when
/// [onTap] is null.
class KzPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool enabled;
  final HitTestBehavior behavior;

  const KzPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = KzMotion.pressScale,
    this.enabled = true,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<KzPressable> createState() => _KzPressableState();
}

class _KzPressableState extends State<KzPressable> {
  bool _down = false;

  void _set(bool v) {
    if (!widget.enabled) return;
    if (_down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.enabled ? widget.onTap : null,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: _down ? KzMotion.press : KzMotion.release,
        curve: _down ? Curves.linear : KzMotion.spring,
        child: widget.child,
      ),
    );
  }
}

/// Fades and lifts its child in once, on mount. [delay] staggers a list.
class KzReveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final double rise;
  final Duration duration;

  const KzReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.rise = 14,
    this.duration = KzMotion.enter,
  });

  /// Index-based stagger, capped so long lists do not crawl in.
  static Duration stagger(int index, {int step = 45, int cap = 360}) {
    final int ms = index * step;
    return Duration(milliseconds: ms > cap ? cap : ms);
  }

  @override
  State<KzReveal> createState() => _KzRevealState();
}

class _KzRevealState extends State<KzReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: KzMotion.easeOut,
  );
  bool _started = false;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _start();
    } else {
      Future<void>.delayed(widget.delay, _start);
    }
  }

  void _start() {
    if (!mounted || _started) return;
    _started = true;
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
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
            offset: Offset(0, widget.rise * (1 - v)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Cross-fade between two states without a layout jump (tab bodies, labels).
class KzFade extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const KzFade({
    super.key,
    required this.child,
    this.duration = KzMotion.hover,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: KzMotion.easeOut,
      switchOutCurve: KzMotion.easeIo,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.985, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
