import 'package:material_ui/material_ui.dart';

/// Kyzen design tokens — the same values as the site's kz.css (v6 "liquid glass"
/// layer): true black floor, violet light behind the glass, capsule controls,
/// Anton for display, Work Sans for text.
///
/// Nothing here reads the Theme: these are constants, so a widget can use them
/// before MaterialApp is built (splash, backdrop, gate).
class KzColors {
  const KzColors._();

  // ── floor and surfaces ────────────────────────────────────────────────
  static const Color bg = Color(0xFF000000);
  static const Color soft = Color(0xFF09080C);
  static const Color s1 = Color(0xFF0C0B10);
  static const Color s2 = Color(0xFF131217);
  static const Color s3 = Color(0xFF1C1A22);

  /// Hairlines are white at low alpha, like the site's --line ramp.
  static const Color line = Color(0x12FFFFFF); // rgba(255,255,255,.07)
  static const Color line2 = Color(0x1CFFFFFF); // rgba(255,255,255,.11)
  static const Color line3 = Color(0x33FFFFFF); // rgba(255,255,255,.20)

  // ── ink ───────────────────────────────────────────────────────────────
  static const Color ink = Color(0xFFF2F0F5);
  static const Color ink2 = Color(0xFFBDB8C4);
  static const Color ink3 = Color(0xFF8B8693);

  // ── purple ramp from #6f0ecf ──────────────────────────────────────────
  static const Color p50 = Color(0xFFF5EEFF);
  static const Color p100 = Color(0xFFE9DBFF);
  static const Color p200 = Color(0xFFD4B8FF);
  static const Color p300 = Color(0xFFBB92FF);
  static const Color p400 = Color(0xFFA06BFB);
  static const Color p500 = Color(0xFF8A3FF0);
  static const Color p600 = Color(0xFF6F0ECF);
  static const Color p700 = Color(0xFF5A0AAA);
  static const Color p800 = Color(0xFF450884);
  static const Color p900 = Color(0xFF2E0659);
  static const Color p950 = Color(0xFF1B0436);

  static const Color accent = p600;
  static const Color accentHi = p500;
  static const Color accentLo = p700;
  static const Color hl = p300;

  // ── state ─────────────────────────────────────────────────────────────
  static const Color ok = Color(0xFF46D18A);
  static const Color okBg = Color(0xFF0F2A1C);
  static const Color warn = Color(0xFFF2B33D);
  static const Color warnBg = Color(0xFF2A2010);
  static const Color bad = Color(0xFFFF6B81);
  static const Color badBg = Color(0xFF2C141A);

  // ── chrome (floating bars) and floating glass ─────────────────────────
  static const Color chromeSolid = Color(0xF20B0A0F); // rgba(11,10,15,.95)
  static const Color floatSolid = Color(0xF70F0E14); // rgba(15,14,20,.97)
}

/// Gradients: the glass sheen, the purple metal and the chrome text fills.
class KzGradients {
  const KzGradients._();

  /// --glass: white sheen fading into a violet foot.
  static const LinearGradient glass = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x12FFFFFF), Color(0x06FFFFFF), Color(0x0DA06BFB)],
    stops: [0.0, 0.42, 1.0],
  );

  /// --glass-hi: the brighter sheen used on bars and floating panels.
  static const LinearGradient glassHi = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x1FFFFFFF), Color(0x0AFFFFFF), Color(0x17A06BFB)],
    stops: [0.0, 0.46, 1.0],
  );

  /// --metal: purple metal for primary buttons.
  static const LinearGradient metal = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF9A55F7), Color(0xFF6F0ECF), Color(0xFF560AA3)],
    stops: [0.0, 0.58, 1.0],
  );

  /// The white highlight laid over --metal (first layer of the CSS stack).
  static const LinearGradient metalSheen = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x6BFFFFFF),
      Color(0x1AFFFFFF),
      Color(0x00FFFFFF),
      Color(0x33000000),
    ],
    stops: [0.0, 0.45, 0.5, 1.0],
  );

  /// --metal-light: the light (ink) button.
  static const LinearGradient metalLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF1E8FF),
      Color(0xFFCDB7F3),
      Color(0xFFE4D6FF),
    ],
    stops: [0.0, 0.40, 0.54, 1.0],
  );

  /// --metal-text: chromed purple, for the brand word.
  static const LinearGradient metalText = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF5EEFF),
      Color(0xFFD4B8FF),
      Color(0xFFA06BFB),
      Color(0xFF6F0ECF),
      Color(0xFF9A5CF6),
      Color(0xFFD4B8FF),
    ],
    stops: [0.0, 0.26, 0.50, 0.66, 0.82, 1.0],
  );

  /// --steel-text: brushed steel, for page and section titles.
  static const LinearGradient steelText = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFE6DEF2), Color(0xFFA99DC4)],
    stops: [0.18, 0.58, 1.0],
  );

  /// --rim: the metal ring drawn on big panels.
  static const LinearGradient rim = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xB8E9DBFF),
      Color(0x47A06BFB),
      Color(0x0AFFFFFF),
      Color(0x526F0ECF),
      Color(0x9ED4B8FF),
    ],
    stops: [0.0, 0.24, 0.50, 0.76, 1.0],
  );

  /// --metal-line: the hairline that lights up under a scrolled bar.
  static const LinearGradient metalLine = LinearGradient(
    colors: [
      Color(0x00BB92FF),
      Color(0x99BB92FF),
      Color(0xF28A3FF0),
      Color(0x99BB92FF),
      Color(0x00BB92FF),
    ],
    stops: [0.0, 0.22, 0.5, 0.78, 1.0],
  );
}

/// Shape: capsules and wide corners.
class KzRadius {
  const KzRadius._();

  static const double panel = 22;
  static const double ctl = 14;
  static const double chip = 10;
  static const double card = 18;
  static const double sheet = 26;
  static const double pill = 999;

  static const BorderRadius rPanel = BorderRadius.all(Radius.circular(panel));
  static const BorderRadius rCtl = BorderRadius.all(Radius.circular(ctl));
  static const BorderRadius rChip = BorderRadius.all(Radius.circular(chip));
  static const BorderRadius rCard = BorderRadius.all(Radius.circular(card));
  static const BorderRadius rSheet = BorderRadius.all(Radius.circular(sheet));
  static const BorderRadius rPill = BorderRadius.all(Radius.circular(pill));
}

/// Space: the site's gutter and bar height, in logical pixels.
class KzSpace {
  const KzSpace._();

  static const double gutter = 16;
  static const double barHeight = 64;
  static const double navHeight = 62;
  static const double wrap = 1280;
}

/// Motion: the site moves transform and opacity only, on these curves.
class KzMotion {
  const KzMotion._();

  // curves (cubic-bezier from kz.css)
  static const Curve easeOut = Cubic(0.16, 1, 0.3, 1);
  static const Curve easeIo = Cubic(0.65, 0, 0.35, 1);
  static const Curve spring = Cubic(0.34, 1.36, 0.64, 1);
  static const Curve sheet = Cubic(0.32, 0.72, 0, 1);
  static const Curve soft = Cubic(0.22, 0.8, 0.26, 1);

  // durations
  static const Duration press = Duration(milliseconds: 90);
  static const Duration release = Duration(milliseconds: 260);
  static const Duration hover = Duration(milliseconds: 220);
  static const Duration enter = Duration(milliseconds: 420);
  static const Duration reveal = Duration(milliseconds: 760);
  static const Duration page = Duration(milliseconds: 420);
  static const Duration pageBack = Duration(milliseconds: 320);

  /// How far a pressed control shrinks (`.btn:active { scale(.96) }`).
  static const double pressScale = 0.96;
  static const double pressScaleCard = 0.975;
}

/// Type: Anton for display, Work Sans for everything else.
class KzType {
  const KzType._();

  static const String display = 'Anton';
  static const String text = 'WorkSans';

  static const TextStyle pageTitle = TextStyle(
    fontFamily: display,
    fontSize: 38,
    height: 0.96,
    letterSpacing: 0.2,
    fontWeight: FontWeight.w400,
    color: KzColors.ink,
  );

  static const TextStyle secTitle = TextStyle(
    fontFamily: display,
    fontSize: 28,
    height: 0.98,
    letterSpacing: 0.2,
    fontWeight: FontWeight.w400,
    color: KzColors.ink,
  );

  static const TextStyle brand = TextStyle(
    fontFamily: display,
    fontSize: 24,
    height: 1.0,
    letterSpacing: 0.3,
    fontWeight: FontWeight.w400,
    color: KzColors.ink,
  );

  static const TextStyle lead = TextStyle(
    fontFamily: text,
    fontSize: 16,
    height: 1.55,
    color: KzColors.ink2,
  );

  static const TextStyle body = TextStyle(
    fontFamily: text,
    fontSize: 15,
    height: 1.5,
    color: KzColors.ink,
  );

  static const TextStyle label = TextStyle(
    fontFamily: text,
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: KzColors.ink,
  );

  static const TextStyle meta = TextStyle(
    fontFamily: text,
    fontSize: 13,
    height: 1.35,
    color: KzColors.ink3,
  );

  static const TextStyle tiny = TextStyle(
    fontFamily: text,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: KzColors.ink2,
  );
}
