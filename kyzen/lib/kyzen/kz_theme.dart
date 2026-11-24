import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'kz_motion.dart';
import 'kz_tokens.dart';

/// The Kyzen theme: the site's black glass, applied to every Material surface
/// the app already uses, so untouched screens come out on-brand too.
///
/// [accent] only moves the Material accents (selection, switches, progress).
/// The brand metal — buttons, the brand word, the pass chip — stays Kyzen
/// purple, because that is the mark, not a preference.
class KzTheme {
  const KzTheme._();

  static const WidgetStateProperty<Icon> switchThumbIcon =
      WidgetStateProperty<Icon>.fromMap(<WidgetStatesConstraint, Icon>{
        WidgetState.selected: Icon(Icons.check),
        WidgetState.any: Icon(Icons.close),
      });

  static const PageTransitionsTheme pageTransitionsTheme = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: KzPageTransitionsBuilder(),
      TargetPlatform.iOS: KzPageTransitionsBuilder(),
      TargetPlatform.macOS: KzPageTransitionsBuilder(),
      TargetPlatform.windows: KzPageTransitionsBuilder(),
      TargetPlatform.linux: KzPageTransitionsBuilder(),
      TargetPlatform.fuchsia: KzPageTransitionsBuilder(),
    },
  );

  static SystemUiOverlayStyle get overlayStyle => const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );

  static ColorScheme scheme({Color accent = KzColors.accent}) {
    return ColorScheme(
      brightness: Brightness.dark,
      primary: accent,
      onPrimary: Colors.white,
      primaryContainer: KzColors.p900,
      onPrimaryContainer: KzColors.p100,
      secondary: KzColors.p400,
      onSecondary: Colors.white,
      secondaryContainer: KzColors.p950,
      onSecondaryContainer: KzColors.p200,
      tertiary: KzColors.p300,
      onTertiary: KzColors.p950,
      tertiaryContainer: KzColors.p800,
      onTertiaryContainer: KzColors.p100,
      error: KzColors.bad,
      onError: Colors.white,
      errorContainer: KzColors.badBg,
      onErrorContainer: KzColors.bad,
      surface: KzColors.bg,
      onSurface: KzColors.ink,
      surfaceDim: KzColors.bg,
      surfaceBright: KzColors.s3,
      surfaceContainerLowest: KzColors.bg,
      surfaceContainerLow: KzColors.soft,
      surfaceContainer: KzColors.s1,
      surfaceContainerHigh: KzColors.s2,
      surfaceContainerHighest: KzColors.s3,
      onSurfaceVariant: KzColors.ink2,
      outline: KzColors.line3,
      outlineVariant: KzColors.line2,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: KzColors.ink,
      onInverseSurface: KzColors.bg,
      inversePrimary: KzColors.p700,
    );
  }

  static TextTheme textTheme({bool minecraftFont = false}) {
    const TextStyle d = TextStyle(
      fontFamily: KzType.display,
      color: KzColors.ink,
      height: 0.98,
      letterSpacing: 0.2,
    );
    const TextStyle t = TextStyle(
      fontFamily: KzType.text,
      color: KzColors.ink,
    );

    final TextTheme base = TextTheme(
      displayLarge: d.copyWith(fontSize: 48),
      displayMedium: d.copyWith(fontSize: 40),
      displaySmall: d.copyWith(fontSize: 34),
      headlineLarge: d.copyWith(fontSize: 30),
      headlineMedium: d.copyWith(fontSize: 26),
      headlineSmall: d.copyWith(fontSize: 22),
      titleLarge: t.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
      titleMedium: t.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: t.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: t.copyWith(fontSize: 16, height: 1.5),
      bodyMedium: t.copyWith(fontSize: 14, height: 1.5, color: KzColors.ink2),
      bodySmall: t.copyWith(fontSize: 13, height: 1.45, color: KzColors.ink3),
      labelLarge: t.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      labelMedium: t.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      labelSmall: t.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: KzColors.ink2,
      ),
    );

    // the pixel font is a setting, so it replaces the family and keeps sizes
    return minecraftFont ? base.apply(fontFamily: 'MinecraftFont') : base;
  }

  static ThemeData build({
    Color accent = KzColors.accent,
    bool minecraftFont = false,
  }) {
    final ColorScheme cs = scheme(accent: accent);
    final TextTheme tt = textTheme(minecraftFont: minecraftFont);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: cs,
      textTheme: tt,
      primaryTextTheme: tt,
      fontFamily: minecraftFont ? 'MinecraftFont' : KzType.text,
      // the backdrop is painted once, behind the navigator
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: KzColors.bg,
      splashColor: const Color(0x14FFFFFF),
      highlightColor: Colors.transparent,
      hoverColor: const Color(0x0FFFFFFF),
      dividerColor: KzColors.line,
      pageTransitionsTheme: pageTransitionsTheme,
      switchTheme: const SwitchThemeData(thumbIcon: switchThumbIcon),
      dividerTheme: const DividerThemeData(
        color: KzColors.line,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: KzColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlayStyle,
        titleTextStyle: tt.titleLarge,
        iconTheme: const IconThemeData(color: KzColors.ink2, size: 22),
      ),
      iconTheme: const IconThemeData(color: KzColors.ink2, size: 22),
      navigationBarTheme: NavigationBarThemeData(
        height: KzSpace.navHeight,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0x3DFFFFFF),
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => tt.labelSmall!.copyWith(
            fontSize: 11,
            color: states.contains(WidgetState.selected)
                ? Colors.white
                : KzColors.ink3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? Colors.white
                : KzColors.ink3,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: Colors.white,
        unselectedItemColor: KzColors.ink3,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: KzColors.soft,
        surfaceTintColor: Colors.transparent,
        scrimColor: Color(0xB3000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(KzRadius.sheet),
            bottomRight: Radius.circular(KzRadius.sheet),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0x0BFFFFFF),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: KzRadius.rCard,
          side: const BorderSide(color: KzColors.line2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: KzColors.floatSolid,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: KzRadius.rSheet,
          side: const BorderSide(color: KzColors.line2),
        ),
        titleTextStyle: tt.titleLarge,
        contentTextStyle: tt.bodyLarge!.copyWith(color: KzColors.ink2),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: KzColors.floatSolid,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: KzColors.floatSolid,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: KzColors.line3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(KzRadius.sheet),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: KzColors.floatSolid,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        textStyle: tt.bodyLarge,
        shape: RoundedRectangleBorder(
          borderRadius: KzRadius.rCtl,
          side: const BorderSide(color: KzColors.line2),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll<Color>(
            KzColors.floatSolid,
          ),
          surfaceTintColor: const WidgetStatePropertyAll<Color>(
            Colors.transparent,
          ),
          elevation: const WidgetStatePropertyAll<double>(0),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: KzRadius.rCtl,
              side: const BorderSide(color: KzColors.line2),
            ),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: KzColors.ink2,
        textColor: KzColors.ink,
        titleTextStyle: tt.titleMedium,
        subtitleTextStyle: tt.bodySmall,
        shape: RoundedRectangleBorder(borderRadius: KzRadius.rCtl),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0x09FFFFFF),
        selectedColor: const Color(0x5C6F0ECF),
        disabledColor: KzColors.s2,
        labelStyle: tt.labelMedium!,
        secondaryLabelStyle: tt.labelMedium!.copyWith(color: KzColors.p100),
        side: const BorderSide(color: KzColors.line2),
        shape: const RoundedRectangleBorder(borderRadius: KzRadius.rPill),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: KzColors.p600,
          foregroundColor: Colors.white,
          disabledBackgroundColor: KzColors.s3,
          disabledForegroundColor: KzColors.ink3,
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          textStyle: tt.labelLarge!.copyWith(fontSize: 15),
          shape: const RoundedRectangleBorder(borderRadius: KzRadius.rPill),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: KzColors.p600,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          textStyle: tt.labelLarge!.copyWith(fontSize: 15),
          shape: const RoundedRectangleBorder(borderRadius: KzRadius.rPill),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: KzColors.ink,
          backgroundColor: const Color(0x0BFFFFFF),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: const BorderSide(color: KzColors.line2),
          textStyle: tt.labelLarge!.copyWith(fontSize: 15),
          shape: const RoundedRectangleBorder(borderRadius: KzRadius.rPill),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: KzColors.p300,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: tt.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: KzRadius.rPill),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: KzColors.ink2,
          highlightColor: const Color(0x14FFFFFF),
          shape: const RoundedRectangleBorder(borderRadius: KzRadius.rPill),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: KzColors.p600,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: KzRadius.rPill),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x0AFFFFFF),
        hintStyle: tt.bodyLarge!.copyWith(color: KzColors.ink3),
        labelStyle: tt.bodyLarge!.copyWith(color: KzColors.ink3),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: const OutlineInputBorder(
          borderRadius: KzRadius.rCtl,
          borderSide: BorderSide(color: KzColors.line2),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: KzRadius.rCtl,
          borderSide: BorderSide(color: KzColors.line2),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: KzRadius.rCtl,
          borderSide: BorderSide(color: KzColors.p400, width: 1.4),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: KzRadius.rCtl,
          borderSide: BorderSide(color: KzColors.bad),
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: const WidgetStatePropertyAll<Color>(
          Color(0x0DFFFFFF),
        ),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
        elevation: const WidgetStatePropertyAll<double>(0),
        textStyle: WidgetStatePropertyAll<TextStyle>(tt.bodyLarge!),
        hintStyle: WidgetStatePropertyAll<TextStyle>(
          tt.bodyLarge!.copyWith(color: KzColors.ink3),
        ),
        shape: const WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(borderRadius: KzRadius.rPill),
        ),
        side: const WidgetStatePropertyAll<BorderSide>(
          BorderSide(color: KzColors.line2),
        ),
      ),
      searchViewTheme: SearchViewThemeData(
        backgroundColor: KzColors.floatSolid,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        dividerColor: KzColors.line,
        headerHintStyle: tt.bodyLarge!.copyWith(color: KzColors.ink3),
        headerTextStyle: tt.bodyLarge,
        shape: const RoundedRectangleBorder(borderRadius: KzRadius.rPanel),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: KzColors.floatSolid,
        contentTextStyle: tt.bodyLarge,
        actionTextColor: KzColors.p300,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: KzRadius.rCtl,
          side: const BorderSide(color: KzColors.line2),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: KzColors.floatSolid,
          borderRadius: KzRadius.rChip,
          border: Border.all(color: KzColors.line2),
        ),
        textStyle: tt.bodySmall!.copyWith(color: KzColors.ink),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: KzColors.p400,
        linearTrackColor: Color(0x14FFFFFF),
        circularTrackColor: Color(0x14FFFFFF),
        strokeCap: StrokeCap.round,
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: KzColors.p500,
        inactiveTrackColor: Color(0x1AFFFFFF),
        thumbColor: KzColors.p200,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? KzColors.p600
              : Colors.transparent,
        ),
        side: const BorderSide(color: KzColors.line3),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? KzColors.p400
              : KzColors.line3,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: KzColors.ink,
        unselectedLabelColor: KzColors.ink3,
        indicatorColor: KzColors.p400,
        dividerColor: KzColors.line,
        labelStyle: tt.labelLarge,
        unselectedLabelStyle: tt.labelLarge,
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: KzColors.p300,
        collapsedIconColor: KzColors.ink3,
        textColor: KzColors.ink,
        collapsedTextColor: KzColors.ink,
        shape: RoundedRectangleBorder(borderRadius: KzRadius.rCtl),
        collapsedShape: RoundedRectangleBorder(borderRadius: KzRadius.rCtl),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: const Color(0x09FFFFFF),
          foregroundColor: KzColors.ink2,
          selectedBackgroundColor: const Color(0x5C6F0ECF),
          selectedForegroundColor: KzColors.p50,
          side: const BorderSide(color: KzColors.line2),
          shape: const RoundedRectangleBorder(borderRadius: KzRadius.rPill),
        ),
      ),
    );
  }
}
