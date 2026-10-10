import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens verified against Figma dump rN1K7Sh0zLPHRNTUX9ZCOK.
/// All photo fills (imageRef) excluded — gradients/initials/icons only.
/// Fonts are SIL OFL via google_fonts; SF Pro / Abhaya Libre excluded.
class PacerColors {
  static const ink = Color(0xFF252525);
  static const cardLabel = Color(0xFF334155);
  static const hintInk = Color(0xCC000000);
  static const errorRed = Color(0xFFBA1A1A);
  static const primary = Color(0xFF64B5F6);
  static const lime = Color(0xFFBAFF29);
  static const joinYellow = Color(0xFFCCFF00);
  static const runCardBg = Color(0x7FE7FFF8);
  static const timeRed = Color(0xFFCC5050);
  static const paceOrange = Color(0xFFCC8C2B);
  static const streakBg = Color(0xFF565693);
  static const streakNum = Color(0xFFF5FFF4);
  static const streakLabel = Color(0xFFE2EC07);
  static const neon = Color(0xFF10FFA0);
  static const navy = Color(0xFF0F172A);
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const border = Color(0xFFE5E7EB);
  static const bottomBar = Color(0xBF2B2B2B);
  static const chatGreen = Color(0xFF10B924);
  static const chatGreenInk = Color(0xFF004105);
  static const formBg = Color(0xFFEFF4FF);
  static const formBorder = Color(0xFFC4C9AC);
  static const formText = Color(0xFF565E74);
  static const chipGreen = Color(0xFF059669);
  static const streakBlue = Color(0xFF0066FF);
  static const gpsPill = Color(0xFFE5F0C5);
  static const postBg = Color(0xFFE3FFA8);
  static const medalGold = Color(0xFFFFD700);
  static const medalSilver = Color(0xFFC0C0C0);
  static const medalBronze = Color(0xFF49371B);
  static const podiumGray = Color(0xFFD9D9D9);
  static const cardShadow = Color(0x40000000);

  // Brand fills identical in both modes (already dark-friendly surfaces and
  // accents). Hoisted here so no dark hex lives outside this file.
  static const teamShade = Color(0xFF2B2B2B);
  static const avatarBg = Color(0xFF2C2C2C);
  static const streakPill = Color(0x99343538);
  static const streakGlowA = Color(0x1ADFE900);
  static const streakGlowB = Color(0x1A10FFA0);
  static const fireYellow = Color(0xFFDFE900);
  static const fireBadge = Color(0xCC292A2D);
  static const neonGlow = Color(0x5910FFA0);
  static const checkDark = Color(0xFF007144);
  static const limeDivider = Color(0x40000000);
}

/// Type styles from dump §2. displaySmall height fixed to 0.8 (32/40).
class PacerText {
  static TextStyle get pageTitle => GoogleFonts.outfit(
    fontWeight: FontWeight.w800,
    fontSize: 32,
    color: PacerColors.ink,
  );
  static TextStyle get authTitle => GoogleFonts.outfit(
    fontWeight: FontWeight.w800,
    fontSize: 40,
    height: 0.8,
    color: PacerColors.ink,
  );
  static TextStyle get fugazBrand =>
      GoogleFonts.fugazOne(fontSize: 24, color: PacerColors.ink);
  static TextStyle giantNum(double size) =>
      GoogleFonts.fugazOne(fontSize: size, color: PacerColors.ink);
  static TextStyle get kmSuffix => GoogleFonts.outfit(
    fontWeight: FontWeight.w900,
    fontSize: 64,
    color: PacerColors.primary,
  );
  static TextStyle get statValue => GoogleFonts.outfit(
    fontWeight: FontWeight.w600,
    fontSize: 20,
    color: PacerColors.ink,
  );
  static TextStyle get cardDistance => GoogleFonts.outfit(
    fontWeight: FontWeight.w700,
    fontSize: 32,
    color: PacerColors.ink,
  );
  static TextStyle get cardTitle => GoogleFonts.outfit(
    fontWeight: FontWeight.w800,
    fontSize: 12,
    color: PacerColors.ink,
  );
  static TextStyle get cardTime => GoogleFonts.outfit(
    fontWeight: FontWeight.w600,
    fontSize: 13,
    color: PacerColors.timeRed,
  );
  static TextStyle get cardPace => GoogleFonts.outfit(
    fontWeight: FontWeight.w600,
    fontSize: 14,
    color: PacerColors.paceOrange,
  );
  static TextStyle get cardDate => GoogleFonts.outfit(
    fontWeight: FontWeight.w400,
    fontSize: 12,
    color: PacerColors.slate700,
  );
  static TextStyle get cardSub =>
      GoogleFonts.outfit(fontSize: 12, color: PacerColors.cardLabel);
  static TextStyle get teamName =>
      GoogleFonts.fugazOne(fontSize: 16, color: Colors.white);
  static TextStyle get teamLoc =>
      GoogleFonts.hankenGrotesk(fontSize: 12, color: Color(0xFFFDFDFD));
  static TextStyle get hint => GoogleFonts.outfit(
    fontWeight: FontWeight.w300,
    fontSize: 15,
    color: PacerColors.hintInk,
  );
  static TextStyle get button => GoogleFonts.outfit(
    fontWeight: FontWeight.w500,
    fontSize: 15,
    color: PacerColors.ink,
  );
  static TextStyle get mono => GoogleFonts.jetBrainsMono(
    fontWeight: FontWeight.w500,
    fontSize: 11,
    letterSpacing: 1.0,
    color: PacerColors.primary,
  );
  static TextStyle get emptyBody =>
      GoogleFonts.outfit(fontSize: 14, color: PacerColors.slate500);
  static TextStyle get errorBody => GoogleFonts.outfit(
    fontWeight: FontWeight.w500,
    fontSize: 15,
    color: PacerColors.errorRed,
  );

  // Brightness-aware variants. Light branch resolves to the exact values
  // above (pixel-identical); dark branch resolves to the dark tokens.
  static TextStyle pageTitleOf(BuildContext context) =>
      pageTitle.copyWith(color: PacerScheme.of(context).ink);
  static TextStyle authTitleOf(BuildContext context) =>
      authTitle.copyWith(color: PacerScheme.of(context).ink);
  static TextStyle fugazOf(BuildContext context) =>
      fugazBrand.copyWith(color: PacerScheme.of(context).ink);
  static TextStyle giantNumOf(BuildContext context, double size) =>
      giantNum(size).copyWith(color: PacerScheme.of(context).ink);
  static TextStyle statValueOf(BuildContext context) =>
      statValue.copyWith(color: PacerScheme.of(context).ink);
  static TextStyle cardTitleOf(BuildContext context) =>
      cardTitle.copyWith(color: PacerScheme.of(context).ink);
  static TextStyle cardDistanceOf(BuildContext context) =>
      cardDistance.copyWith(color: PacerScheme.of(context).ink);
  static TextStyle cardTimeOf(BuildContext context) =>
      cardTime.copyWith(color: PacerScheme.of(context).timeRed);
  static TextStyle cardPaceOf(BuildContext context) =>
      cardPace.copyWith(color: PacerScheme.of(context).paceOrange);
  static TextStyle cardDateOf(BuildContext context) =>
      cardDate.copyWith(color: PacerScheme.of(context).muted);
  static TextStyle cardSubOf(BuildContext context) =>
      cardSub.copyWith(color: PacerScheme.of(context).muted);
  static TextStyle hintOf(BuildContext context) =>
      hint.copyWith(color: PacerScheme.of(context).hint);
}

/// Shared 8pt-grid spacing steps and one soft card shadow.
/// Screens snap odd paddings/gaps to these instead of inventing new values.
class PacerGaps {
  static const double xs = 8;
  static const double sm = 16;
  static const double md = 24;
  static const double lg = 32;
}

class PacerShadows {
  static const soft = BoxShadow(
    color: Color(0x0D000000),
    blurRadius: 2,
    offset: Offset(0, 1),
  );
}

/// In-app theme mode. Defaults to the OS setting; the toggle persists
/// in-memory for the session (mirrors langNotifier's rebuild pattern —
/// PacerApp listens and rebuilds the whole tree). No backend column.
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(
  ThemeMode.system,
);

/// Set the moment the user explicitly picks a theme mode.
void setThemeMode(ThemeMode mode) {
  themeModeNotifier.value = mode;
}

/// Dark palette. Every dark color lives here (and only here) — screens
/// resolve through [PacerScheme], never hardcoded literals.
class PacerDark {
  static const scaffold = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const text = Color(0xFFF8FAFC);
  static const muted = Color(0xFF94A3B8);
  static const soft = Color(0xFFCBD5E1);
  static const subtle = Color(0xB3FFFFFF);
  static const overlay = Color(0x99E2E8F0);
  static const hint = Color(0x99FFFFFF);
  static const border = Color(0xFF334155);
  static const chipBorder = Color(0xFF475569);
  static const error = Color(0xFFF87171);
  static const timeRed = Color(0xFFF87171);
  static const paceOrange = Color(0xFFFBBF24);
  static const success = Color(0xFF34D399);
  static const emptyIcon = Color(0xFF475569);
  static const gridLine = Color(0xFF475569);
  static const shadow = Color(0x59000000);
  static const navBar = Color(0xF21E293B);
  static const navIcon = Color(0xFFCBD5E1);
}

/// Brightness-resolved semantic tokens. The light branch returns the exact
/// current light values (light theme stays pixel-identical); the dark
/// branch returns [PacerDark]. Resolves via Theme brightness so tests and
/// previews pumping a light MaterialApp see zero change.
class PacerScheme {
  final Brightness brightness;
  final Color scaffold;
  final Color card;
  final Color authField;
  final Color formField;
  final Color searchBg;
  final Color ink;
  final Color deepInk;
  final Color headline;
  final Color chipFg;
  final Color muted;
  final Color soft;
  final Color bodyGray;
  final Color formMuted;
  final Color subtle;
  final Color overlay;
  final Color hint;
  final Color border;
  final Color softBorder;
  final Color hairline;
  final Color chipBorder;
  final Color formEdge;
  final Color error;
  final Color timeRed;
  final Color paceOrange;
  final Color success;
  final Color accent;
  final Color runCard;
  final Color chatBubble;
  final Color navBar;
  final Color navIcon;
  final Color emptyIcon;
  final Color mapBtnB;
  final Color finishTop;
  final Color finishBottom;
  final Color gridLine;
  final Color chipSelBg;
  final Color chipSelFg;
  final Color editBg;

  const PacerScheme({
    required this.brightness,
    required this.scaffold,
    required this.card,
    required this.authField,
    required this.formField,
    required this.searchBg,
    required this.ink,
    required this.deepInk,
    required this.headline,
    required this.chipFg,
    required this.muted,
    required this.soft,
    required this.bodyGray,
    required this.formMuted,
    required this.subtle,
    required this.overlay,
    required this.hint,
    required this.border,
    required this.softBorder,
    required this.hairline,
    required this.chipBorder,
    required this.formEdge,
    required this.error,
    required this.timeRed,
    required this.paceOrange,
    required this.success,
    required this.accent,
    required this.runCard,
    required this.chatBubble,
    required this.navBar,
    required this.navIcon,
    required this.emptyIcon,
    required this.mapBtnB,
    required this.finishTop,
    required this.finishBottom,
    required this.gridLine,
    required this.chipSelBg,
    required this.chipSelFg,
    required this.editBg,
  });

  static const light = PacerScheme(
    brightness: Brightness.light,
    scaffold: Colors.white,
    card: Colors.white,
    authField: Colors.white,
    formField: PacerColors.formBg,
    searchBg: PacerColors.slate50,
    ink: PacerColors.ink,
    deepInk: Color(0xFF0B1C30),
    headline: PacerColors.navy,
    chipFg: Color(0xFF181C22),
    muted: PacerColors.slate700,
    soft: PacerColors.slate500,
    bodyGray: Color(0xFF444749),
    formMuted: PacerColors.formText,
    subtle: Colors.black54,
    overlay: Color(0x99000000),
    hint: PacerColors.hintInk,
    border: PacerColors.border,
    softBorder: PacerColors.slate200,
    hairline: Color(0xFFE5E8F1),
    chipBorder: Color(0xFFC4C7C8),
    formEdge: PacerColors.formBorder,
    error: PacerColors.errorRed,
    timeRed: PacerColors.timeRed,
    paceOrange: PacerColors.paceOrange,
    success: PacerColors.chipGreen,
    accent: PacerColors.primary,
    runCard: PacerColors.runCardBg,
    chatBubble: Color(0xFFF2F3FF),
    navBar: PacerColors.bottomBar,
    navIcon: Colors.white,
    emptyIcon: PacerColors.slate200,
    mapBtnB: PacerColors.slate50,
    finishTop: PacerColors.slate100,
    finishBottom: PacerColors.slate200,
    gridLine: Color(0xFFCBD5E1),
    chipSelBg: Colors.black,
    chipSelFg: Colors.white,
    editBg: PacerColors.navy,
  );

  static const dark = PacerScheme(
    brightness: Brightness.dark,
    scaffold: PacerDark.scaffold,
    card: PacerDark.surface,
    authField: PacerDark.surface,
    formField: PacerDark.surface,
    searchBg: PacerDark.surface,
    ink: PacerDark.text,
    deepInk: PacerDark.text,
    headline: PacerDark.text,
    chipFg: PacerDark.text,
    muted: PacerDark.muted,
    soft: PacerDark.soft,
    bodyGray: PacerDark.soft,
    formMuted: PacerDark.soft,
    subtle: PacerDark.subtle,
    overlay: PacerDark.overlay,
    hint: PacerDark.hint,
    border: PacerDark.border,
    softBorder: PacerDark.border,
    hairline: PacerDark.border,
    chipBorder: PacerDark.chipBorder,
    formEdge: PacerDark.border,
    error: PacerDark.error,
    timeRed: PacerDark.timeRed,
    paceOrange: PacerDark.paceOrange,
    success: PacerDark.success,
    accent: PacerColors.lime,
    runCard: PacerDark.surface,
    chatBubble: PacerDark.surface,
    navBar: PacerDark.navBar,
    navIcon: PacerDark.navIcon,
    emptyIcon: PacerDark.emptyIcon,
    mapBtnB: PacerDark.surface,
    finishTop: PacerDark.scaffold,
    finishBottom: PacerDark.surface,
    gridLine: PacerDark.gridLine,
    chipSelBg: PacerColors.lime,
    chipSelFg: PacerColors.ink,
    editBg: PacerColors.lime,
  );

  static PacerScheme of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? PacerScheme.dark
      : PacerScheme.light;

  /// Ink-colored action label for lime/dark-selected fills; identical to
  /// [chipSelFg] in both modes (white text on black in light, ink on lime
  /// in dark).
  Color get actionFg => chipSelFg;

  bool get isDark => brightness == Brightness.dark;

  BoxShadow get shadowBox => BoxShadow(
    color: isDark ? PacerDark.shadow : const Color(0x0D000000),
    blurRadius: 2,
    offset: const Offset(0, 1),
  );
}

class PacerTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
      textTheme: TextTheme(
        displaySmall: PacerText.authTitle,
        headlineLarge: PacerText.pageTitle,
        headlineSmall: GoogleFonts.outfit(
          fontWeight: FontWeight.w700,
          fontSize: 24,
          color: PacerColors.ink,
        ),
        titleMedium: GoogleFonts.outfit(
          fontWeight: FontWeight.w500,
          fontSize: 20,
          color: PacerColors.ink,
        ),
        bodyMedium: GoogleFonts.outfit(fontSize: 15, color: PacerColors.ink),
        labelSmall: GoogleFonts.outfit(fontSize: 12, color: PacerColors.ink),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: PacerColors.primary,
        primary: PacerColors.primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: PacerText.hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: PacerColors.border),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 44,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PacerColors.primary,
          foregroundColor: PacerColors.ink,
          minimumSize: const Size(315, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          textStyle: PacerText.button,
          elevation: 1,
        ),
      ),
    );
  }

  /// Dark theme: same structure as [light], navy surfaces, light text,
  /// lime accents. Brand fills (lime buttons, purple streak, medals)
  /// are untouched — only theme chrome adapts.
  static ThemeData dark() {
    final scheme = PacerScheme.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: scheme.scaffold,
      textTheme: TextTheme(
        displaySmall: PacerText.authTitle.copyWith(color: scheme.ink),
        headlineLarge: PacerText.pageTitle.copyWith(color: scheme.ink),
        headlineSmall: GoogleFonts.outfit(
          fontWeight: FontWeight.w700,
          fontSize: 24,
          color: scheme.ink,
        ),
        titleMedium: GoogleFonts.outfit(
          fontWeight: FontWeight.w500,
          fontSize: 20,
          color: scheme.ink,
        ),
        bodyMedium: GoogleFonts.outfit(fontSize: 15, color: scheme.ink),
        labelSmall: GoogleFonts.outfit(fontSize: 12, color: scheme.ink),
      ),
      colorScheme: ColorScheme.dark(
        primary: PacerColors.lime,
        onPrimary: PacerColors.ink,
        secondary: PacerColors.primary,
        surface: PacerDark.surface,
        onSurface: PacerDark.text,
        error: PacerDark.error,
        onError: PacerDark.text,
      ),
      iconTheme: const IconThemeData(color: PacerDark.text),
      appBarTheme: const AppBarTheme(
        backgroundColor: PacerDark.surface,
        foregroundColor: PacerDark.text,
        elevation: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PacerDark.surface,
        hintStyle: PacerText.hint.copyWith(color: scheme.hint),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: PacerDark.border),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 44,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PacerColors.primary,
          foregroundColor: PacerColors.ink,
          minimumSize: const Size(315, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          textStyle: PacerText.button,
          elevation: 1,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: PacerDark.surface,
        contentTextStyle: TextStyle(color: PacerDark.text),
        actionTextColor: PacerColors.lime,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: PacerDark.surface,
        titleTextStyle: TextStyle(color: PacerDark.text, fontSize: 20),
        contentTextStyle: TextStyle(color: PacerDark.text),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: PacerDark.surface,
        labelStyle: TextStyle(color: PacerDark.text),
        side: BorderSide(color: PacerDark.border),
      ),
    );
  }
}
