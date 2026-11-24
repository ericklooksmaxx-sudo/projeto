import 'package:material_ui/material_ui.dart';

import 'kz_tokens.dart';

/// Text filled with a gradient, the way the site chromes its titles
/// (`background-clip: text`). The gradient is laid over the text's own box, so
/// every line gets the full ramp.
class KzGradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Gradient gradient;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const KzGradientText(
    this.text, {
    super.key,
    required this.style,
    required this.gradient,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (Rect bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        style: style.copyWith(color: Colors.white),
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}

/// The brand word: Anton, uppercase, chromed purple (--metal-text).
class KzBrandWord extends StatelessWidget {
  final String text;
  final double size;

  const KzBrandWord({super.key, this.text = 'KYZEN', this.size = 24});

  @override
  Widget build(BuildContext context) {
    return KzGradientText(
      text.toUpperCase(),
      style: KzType.brand.copyWith(fontSize: size),
      gradient: KzGradients.metalText,
      maxLines: 1,
    );
  }
}

/// Page title: Anton, uppercase, brushed steel (--steel-text).
class KzPageTitle extends StatelessWidget {
  final String text;
  final double? size;
  final TextAlign? textAlign;

  const KzPageTitle(this.text, {super.key, this.size, this.textAlign});

  @override
  Widget build(BuildContext context) {
    return KzGradientText(
      text.toUpperCase(),
      style: size == null
          ? KzType.pageTitle
          : KzType.pageTitle.copyWith(fontSize: size),
      gradient: KzGradients.steelText,
      textAlign: textAlign,
    );
  }
}

/// Section title: same steel fill, smaller.
class KzSectionTitle extends StatelessWidget {
  final String text;
  final double? size;
  final TextAlign? textAlign;
  final int? maxLines;

  const KzSectionTitle(
    this.text, {
    super.key,
    this.size,
    this.textAlign,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return KzGradientText(
      text.toUpperCase(),
      style: size == null
          ? KzType.secTitle
          : KzType.secTitle.copyWith(fontSize: size),
      gradient: KzGradients.steelText,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}

/// Heading + optional sub, the pair the site uses above every grid.
class KzHeading extends StatelessWidget {
  final String title;
  final String? sub;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const KzHeading({
    super.key,
    required this.title,
    this.sub,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                KzSectionTitle(title, maxLines: 2),
                if (sub != null) ...[
                  const SizedBox(height: 8),
                  Text(sub!, style: KzType.lead.copyWith(fontSize: 14)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}
