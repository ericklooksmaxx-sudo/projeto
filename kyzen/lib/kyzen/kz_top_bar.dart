import 'package:material_ui/material_ui.dart';

import 'gate/pass_chip.dart';
import 'kz_components.dart';
import 'kz_surface.dart';
import 'kz_text.dart';
import 'kz_tokens.dart';

/// The site's floating top bar: a glass capsule with the brand word on the
/// left, the pass chip on the right, and whatever the screen puts between.
class KzTopBar extends StatelessWidget {
  final List<Widget> actions;
  final bool showPass;
  final VoidCallback? onMenu;
  final String? title;
  final EdgeInsets margin;

  const KzTopBar({
    super.key,
    this.actions = const <Widget>[],
    this.showPass = true,
    this.onMenu,
    this.title,
    this.margin = const EdgeInsets.fromLTRB(8, 8, 8, 4),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: KzGlass(
        radius: const BorderRadius.all(Radius.circular(20)),
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            if (onMenu != null) ...[
              KzIconButton(
                icon: Icons.menu,
                size: 38,
                tooltip: 'Menu',
                onPressed: onMenu,
              ),
              const SizedBox(width: 10),
            ],
            if (title == null) ...[
              // the site pairs the mark with the word
              ClipRRect(
                borderRadius: KzRadius.rChip,
                child: Image.asset(
                  'assets/kyzen/mark.png',
                  width: 30,
                  height: 30,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              const SizedBox(width: 10),
              const KzBrandWord(size: 22),
            ]
            else
              Flexible(child: KzSectionTitle(title!, size: 20, maxLines: 1)),
            const Spacer(),
            for (final Widget a in actions) ...[a, const SizedBox(width: 8)],
            if (showPass) const KzPassChip(compact: true),
          ],
        ),
      ),
    );
  }
}

/// A screen header for pushed pages: back button, title, optional action.
class KzPageBar extends StatelessWidget {
  final String? title;
  final List<Widget> actions;
  final bool showPass;

  const KzPageBar({
    super.key,
    this.title,
    this.actions = const <Widget>[],
    this.showPass = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: KzGlass(
        radius: const BorderRadius.all(Radius.circular(20)),
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            KzIconButton(
              icon: Icons.arrow_back,
              size: 38,
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: title == null
                  ? const SizedBox.shrink()
                  : Text(
                      title!,
                      style: KzType.label.copyWith(fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            for (final Widget a in actions) ...[const SizedBox(width: 8), a],
            if (showPass) ...[
              const SizedBox(width: 8),
              const KzPassChip(compact: true),
            ],
          ],
        ),
      ),
    );
  }
}
