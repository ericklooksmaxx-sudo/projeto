import 'package:material_ui/material_ui.dart';

import '../kyzen/kz_components.dart';

/// Full-width secondary action, Kyzen glass capsule.
/// Kept as its own widget because the auth screens build rows of them.
class StyledButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;

  const StyledButton({
    super.key,
    required this.onTap,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return KzButton(
      label: label,
      icon: icon,
      kind: KzButtonKind.secondary,
      block: true,
      onPressed: onTap,
    );
  }
}
