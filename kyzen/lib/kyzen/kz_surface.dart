import 'package:material_ui/material_ui.dart';

import 'kz_tokens.dart';

/// The floor: true black with the three violet lights the site parks behind the
/// glass (body::before in kz.css). It never scrolls and never catches taps.
class KzBackdrop extends StatelessWidget {
  final Widget child;

  const KzBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(child: _BackdropLights()),
        ),
        child,
      ],
    );
  }
}

class _BackdropLights extends StatelessWidget {
  const _BackdropLights();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: KzColors.bg),
      child: Stack(
        children: [
          // radial-gradient(72% 44% at 10% -8%, rgba(111,14,207,.36), transparent 70%)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.8, -1.16),
                  radius: 1.15,
                  colors: [Color(0x5C6F0ECF), Color(0x006F0ECF)],
                  stops: [0.0, 0.7],
                ),
              ),
            ),
          ),
          // radial-gradient(54% 36% at 98% 6%, rgba(138,63,240,.17), transparent 72%)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.96, -0.88),
                  radius: 0.95,
                  colors: [Color(0x2B8A3FF0), Color(0x008A3FF0)],
                  stops: [0.0, 0.72],
                ),
              ),
            ),
          ),
          // radial-gradient(64% 34% at 50% 106%, rgba(69,8,132,.3), transparent 72%)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, 1.12),
                  radius: 1.0,
                  colors: [Color(0x4D450884), Color(0x00450884)],
                  stops: [0.0, 0.72],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the inset hairlines CSS gets from `inset 0 0 0 1px` and
/// `inset 0 1px 0`: a ring plus a brighter top edge.
class KzEdgePainter extends CustomPainter {
  final BorderRadius radius;
  final Color ring;
  final Color topEdge;
  final double width;

  const KzEdgePainter({
    required this.radius,
    this.ring = const Color(0x12FFFFFF),
    this.topEdge = const Color(0x2BFFFFFF),
    this.width = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final RRect outer = radius
        .toRRect(Offset.zero & size)
        .deflate(width / 2);

    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = ring;
    canvas.drawRRect(outer, ringPaint);

    if (topEdge.a == 0) return;

    // brighter line along the top edge only
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, width * 2));
    final Paint top = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = topEdge;
    canvas.drawRRect(outer, top);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant KzEdgePainter old) =>
      old.radius != radius ||
      old.ring != ring ||
      old.topEdge != topEdge ||
      old.width != width;
}

/// Paints the metal ring (--rim) used on the big panels.
class KzRimPainter extends CustomPainter {
  final BorderRadius radius;
  final double width;
  final double opacity;

  const KzRimPainter({
    required this.radius,
    this.width = 1,
    this.opacity = 0.75,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = KzGradients.rim.createShader(rect);

    // a shader ignores Paint.color, so the ring is dimmed through a layer
    final bool dim = opacity < 1;
    if (dim) {
      canvas.saveLayer(
        rect.inflate(width),
        Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
      );
    }
    canvas.drawRRect(radius.toRRect(rect).deflate(width / 2), p);
    if (dim) canvas.restore();
  }

  @override
  bool shouldRepaint(covariant KzRimPainter old) =>
      old.radius != radius || old.width != width || old.opacity != opacity;
}

/// A sheet of Kyzen glass: tinted fill, sheen, hairline ring.
///
/// [floating] uses the heavier tint and drop shadow the site gives menus,
/// toasts and docks; [rim] adds the metal ring used on hero-sized panels.
class KzGlass extends StatelessWidget {
  final Widget? child;
  final BorderRadius radius;
  final EdgeInsetsGeometry? padding;
  final bool floating;
  final bool rim;
  final Color? tint;
  final Gradient? sheen;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;

  const KzGlass({
    super.key,
    this.child,
    this.radius = KzRadius.rPanel,
    this.padding,
    this.floating = false,
    this.rim = false,
    this.tint,
    this.sheen,
    this.width,
    this.height,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final Widget body = Container(
      width: width,
      height: height,
      alignment: alignment,
      padding: padding,
      decoration: BoxDecoration(
        color: tint ?? (floating ? KzColors.floatSolid : KzColors.chromeSolid),
        gradient: sheen ?? KzGradients.glassHi,
        borderRadius: radius,
        boxShadow: floating
            ? const [
                BoxShadow(
                  color: Color(0xF2000000),
                  blurRadius: 60,
                  spreadRadius: -22,
                  offset: Offset(0, 24),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0xF2000000),
                  blurRadius: 36,
                  spreadRadius: -20,
                  offset: Offset(0, 16),
                ),
              ],
      ),
      child: child,
    );

    return Stack(
      children: [
        body,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: KzEdgePainter(radius: radius),
              foregroundPainter: rim ? KzRimPainter(radius: radius) : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// A quieter panel: the `--glass` fill used for cards, states and rows.
class KzPanel extends StatelessWidget {
  final Widget? child;
  final BorderRadius radius;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final Color ring;
  final bool active;

  const KzPanel({
    super.key,
    this.child,
    this.radius = KzRadius.rCard,
    this.padding,
    this.tint,
    this.ring = KzColors.line2,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: padding,
          decoration: BoxDecoration(
            color:
                tint ??
                (active
                    ? const Color(0x5C6F0ECF)
                    : const Color(0x0BFFFFFF)),
            gradient: KzGradients.glass,
            borderRadius: radius,
          ),
          child: child,
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: KzEdgePainter(
                radius: radius,
                ring: active ? const Color(0x85BB92FF) : ring,
                topEdge: active
                    ? const Color(0x47FFFFFF)
                    : const Color(0x1FFFFFFF),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Purple-metal fill for primary actions (--metal + --metal-edge + glow).
BoxDecoration kzMetalDecoration({
  BorderRadius radius = KzRadius.rPill,
  bool glow = true,
}) {
  return BoxDecoration(
    borderRadius: radius,
    gradient: KzGradients.metal,
    boxShadow: glow
        ? const [
            BoxShadow(
              color: Color(0xF26F0ECF),
              blurRadius: 28,
              spreadRadius: -14,
              offset: Offset(0, 12),
            ),
          ]
        : const [],
  );
}

/// Light (ink) fill: --metal-light.
BoxDecoration kzLightDecoration({
  BorderRadius radius = KzRadius.rPill,
}) {
  return BoxDecoration(
    borderRadius: radius,
    gradient: KzGradients.metalLight,
    boxShadow: const [
      BoxShadow(
        color: Color(0xD9BB92FF),
        blurRadius: 24,
        spreadRadius: -14,
        offset: Offset(0, 10),
      ),
    ],
  );
}
