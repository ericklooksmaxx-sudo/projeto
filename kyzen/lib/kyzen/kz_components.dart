import 'package:material_ui/material_ui.dart';

import 'kz_motion.dart';
import 'kz_surface.dart';
import 'kz_tokens.dart';

enum KzButtonKind { primary, secondary, light, ghost }

enum KzButtonSize { md, sm }

/// The site's `.btn`: capsule, 48 px (40 px small), purple metal when primary,
/// glass when secondary, and a 0.96 press.
class KzButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final KzButtonKind kind;
  final KzButtonSize size;
  final IconData? icon;
  final Widget? leading;
  final bool block;
  final bool loading;

  const KzButton({
    super.key,
    required this.label,
    this.onPressed,
    this.kind = KzButtonKind.primary,
    this.size = KzButtonSize.md,
    this.icon,
    this.leading,
    this.block = false,
    this.loading = false,
  });

  bool get _enabled => onPressed != null && !loading;

  double get _height => size == KzButtonSize.md ? 48 : 40;

  double get _fontSize => size == KzButtonSize.md ? 16 : 14;

  EdgeInsets get _padding => EdgeInsets.symmetric(
    horizontal: size == KzButtonSize.md ? 22 : 16,
  );

  Color get _ink {
    if (!_enabled) return KzColors.ink3;
    switch (kind) {
      case KzButtonKind.primary:
        return Colors.white;
      case KzButtonKind.light:
        return const Color(0xFF14062A);
      case KzButtonKind.secondary:
        return KzColors.ink;
      case KzButtonKind.ghost:
        return KzColors.ink2;
    }
  }

  BoxDecoration _decoration() {
    if (!_enabled) {
      return BoxDecoration(
        color: KzColors.s3,
        borderRadius: KzRadius.rPill,
        border: Border.all(color: KzColors.line),
      );
    }
    switch (kind) {
      case KzButtonKind.primary:
        return kzMetalDecoration();
      case KzButtonKind.light:
        return kzLightDecoration();
      case KzButtonKind.secondary:
        return const BoxDecoration(
          color: Color(0x0BFFFFFF),
          gradient: KzGradients.glass,
          borderRadius: KzRadius.rPill,
        );
      case KzButtonKind.ghost:
        return const BoxDecoration(borderRadius: KzRadius.rPill);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color ink = _ink;
    final TextStyle style = KzType.label.copyWith(
      fontSize: _fontSize,
      fontWeight: FontWeight.w600,
      color: ink,
      height: 1.0,
    );

    Widget content = Row(
      mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(ink),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (leading != null) ...[
          leading!,
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          Icon(icon, size: size == KzButtonSize.md ? 20 : 18, color: ink),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            label,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    Widget body = Container(
      height: _height,
      width: block ? double.infinity : null,
      padding: _padding,
      alignment: Alignment.center,
      decoration: _decoration(),
      child: content,
    );

    if (_enabled &&
        (kind == KzButtonKind.secondary || kind == KzButtonKind.primary)) {
      body = Stack(
        children: [
          body,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: KzEdgePainter(
                  radius: KzRadius.rPill,
                  ring: kind == KzButtonKind.primary
                      ? const Color(0x29E9DBFF)
                      : KzColors.line2,
                  topEdge: kind == KzButtonKind.primary
                      ? const Color(0x80FFFFFF)
                      : const Color(0x1FFFFFFF),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Opacity(
      opacity: _enabled ? 1 : 0.9,
      child: KzPressable(
        enabled: _enabled,
        onTap: onPressed,
        child: body,
      ),
    );
  }
}

/// Square glass button for a single icon (`.btn-icon`).
class KzIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final String? tooltip;
  final Color? color;

  const KzIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 44,
    this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    Widget body = Stack(
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0x0BFFFFFF),
            gradient: KzGradients.glass,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: size * 0.45, color: color ?? KzColors.ink2),
        ),
      ],
    );

    if (tooltip != null) {
      body = Tooltip(message: tooltip!, child: body);
    }

    return KzPressable(onTap: onPressed, enabled: onPressed != null, child: body);
  }
}

/// `.chip`: capsule filter, purple when active.
class KzChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final IconData? icon;
  final Widget? leading;
  final String? count;

  const KzChip({
    super.key,
    required this.label,
    this.active = false,
    this.onTap,
    this.icon,
    this.leading,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final Color ink = active ? KzColors.p50 : KzColors.ink2;

    return KzPressable(
      scale: 0.95,
      onTap: onTap,
      enabled: onTap != null,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: KzMotion.hover,
            curve: Curves.linear,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: active ? const Color(0x5C6F0ECF) : const Color(0x09FFFFFF),
              gradient: active
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x47D4B8FF), Color(0x006F0ECF)],
                      stops: [0.0, 0.72],
                    )
                  : null,
              borderRadius: KzRadius.rPill,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 8)],
                if (leading == null && icon != null) ...[
                  Icon(icon, size: 18, color: ink),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: KzType.label.copyWith(color: ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (count != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    count!,
                    style: KzType.label.copyWith(
                      color: KzColors.ink3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: KzEdgePainter(
                  radius: KzRadius.rPill,
                  ring: active ? const Color(0x85BB92FF) : KzColors.line2,
                  topEdge: active
                      ? const Color(0x47FFFFFF)
                      : const Color(0x14FFFFFF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small flat label over a thumbnail (`.card-type-badge`).
class KzBadge extends StatelessWidget {
  final String label;
  final Widget? leading;
  final Color? color;

  const KzBadge({super.key, required this.label, this.leading, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xBD08070C),
        borderRadius: KzRadius.rPill,
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Text(
            label,
            style: KzType.tiny.copyWith(color: color ?? KzColors.ink),
          ),
        ],
      ),
    );
  }
}

enum KzAlertTone { info, good, warn, bad }

/// `.alert`: a glass block with a tone edge, used for gate and error notices.
class KzAlert extends StatelessWidget {
  final String title;
  final String? body;
  final IconData icon;
  final KzAlertTone tone;
  final Widget? action;

  const KzAlert({
    super.key,
    required this.title,
    this.body,
    this.icon = Icons.info_outline,
    this.tone = KzAlertTone.info,
    this.action,
  });

  Color get _tint {
    switch (tone) {
      case KzAlertTone.good:
        return KzColors.ok;
      case KzAlertTone.warn:
        return KzColors.warn;
      case KzAlertTone.bad:
        return KzColors.bad;
      case KzAlertTone.info:
        return KzColors.p300;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color tint = _tint;
    return KzPanel(
      radius: KzRadius.rCtl,
      tint: tint.withValues(alpha: 0.08),
      ring: tint.withValues(alpha: 0.36),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: tint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: KzType.label.copyWith(fontSize: 15, color: KzColors.ink),
                ),
                if (body != null) ...[
                  const SizedBox(height: 4),
                  Text(body!, style: KzType.meta.copyWith(color: KzColors.ink2)),
                ],
                if (action != null) ...[const SizedBox(height: 12), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `.state`: the empty / error block.
class KzEmptyState extends StatelessWidget {
  final String title;
  final String? body;
  final Widget? art;
  final Widget? action;

  const KzEmptyState({
    super.key,
    required this.title,
    this.body,
    this.art,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: KzReveal(
          child: KzPanel(
            radius: KzRadius.rPanel,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                art ??
                    Opacity(
                      opacity: 0.85,
                      child: Image.asset(
                        'assets/kyzen/fox.png',
                        width: 86,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: KzType.label.copyWith(fontSize: 18),
                ),
                if (body != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    body!,
                    textAlign: TextAlign.center,
                    style: KzType.meta.copyWith(fontSize: 14),
                  ),
                ],
                if (action != null) ...[const SizedBox(height: 20), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hairline divider (`1px var(--line)`).
class KzDivider extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry padding;

  const KzDivider({
    super.key,
    this.height = 1,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SizedBox(
        height: height,
        child: const DecoratedBox(
          decoration: BoxDecoration(color: KzColors.line),
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}
