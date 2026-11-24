import 'package:material_ui/material_ui.dart';

Widget getFileIcon(
  String fileName,
  BuildContext context, {
  double size = 32,
  bool useColorFilter = false,
}) {
  String? iconAsset;
  if (fileName.contains('(skin_pack')) {
    iconAsset = 'assets/skin.png';
  } else if (fileName.contains('(world_template')) {
    iconAsset = 'assets/world.png';
  } else if (fileName.contains('(persona')) {
    iconAsset = 'assets/persona.png';
  } else if (fileName.contains('(resources')) {
    iconAsset = 'assets/texture.png';
  } else if (fileName.contains('(addon')) {
    iconAsset = 'assets/addon.png';
  }

  final primaryColor = Theme.of(context).colorScheme.primary;

  if (iconAsset != null) {
    final image = Image.asset(
      iconAsset,
      width: size,
      height: size,
      filterQuality: FilterQuality.none,
    );
    if (useColorFilter) {
      return ColorFiltered(
        colorFilter: ColorFilter.mode(primaryColor, BlendMode.srcIn),
        child: image,
      );
    }
    return image;
  }

  return Icon(Icons.insert_drive_file, size: size, color: primaryColor);
}
