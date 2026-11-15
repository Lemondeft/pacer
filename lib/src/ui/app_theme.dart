import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
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
  static const streakAmber = Color(0xFFFFB020);
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

extension PacerTextStyleX on TextStyle {
  /// Returns this style with proportional-width lining replaced by fixed-width
  /// tabular figures for aligned counters, pace splits, and standings.
  TextStyle tabularFigures() =>
      copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}

/// Shared 8pt-grid spacing steps and one soft card shadow.
/// Screens snap odd paddings/gaps to these instead of inventing new values.
class PacerGaps {
  static const double xs = 8;
  static const double sm = 16;
  static const double md = 24;
  static const double lg = 32;
}

/// Unified corner radius ladder aligned with continuous squircle cards.
class PacerRadii {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double hero = 24;
  static const double pill = 999;
}

class PacerShadows {
  static const soft = BoxShadow(
    color: Color(0x0D000000),
    blurRadius: 2,
    offset: Offset(0, 1),
  );
}

/// Classic Linux desktop theme presets (inspired by KDE Breeze, Linux Mint
/// Cinnamon, GNOME Adwaita, Ubuntu Yaru, and Arch Nord).
enum PacerLinuxTheme {
  defaultPacer,
  breeze,
  cinnamon,
  adwaita,
  yaru,
  nord,
}

/// Active Linux desktop theme preset. Defaults to [PacerLinuxTheme.defaultPacer]
/// so all existing tests see the exact default Pacer palette unless switched.
final ValueNotifier<PacerLinuxTheme> linuxThemeNotifier = ValueNotifier(
  PacerLinuxTheme.defaultPacer,
);

void setLinuxTheme(PacerLinuxTheme preset) {
  linuxThemeNotifier.value = preset;
}

/// Metadata & preview swatches for each classic Linux desktop theme.
class PacerLinuxThemeInfo {
  final PacerLinuxTheme id;
  final String name;
  final String desktopEnv;
  final Color darkBg;
  final Color darkSurface;
  final Color accent;
  final Color secondaryAccent;

  const PacerLinuxThemeInfo({
    required this.id,
    required this.name,
    required this.desktopEnv,
    required this.darkBg,
    required this.darkSurface,
    required this.accent,
    required this.secondaryAccent,
  });

  static const List<PacerLinuxThemeInfo> all = [
    PacerLinuxThemeInfo(
      id: PacerLinuxTheme.defaultPacer,
      name: 'Pacer Argon',
      desktopEnv: 'Default • Athletic Neon & Deep Navy',
      darkBg: Color(0xFF0F172A),
      darkSurface: Color(0xFF1E293B),
      accent: Color(0xFFBAFF29),
      secondaryAccent: Color(0xFF64B5F6),
    ),
    PacerLinuxThemeInfo(
      id: PacerLinuxTheme.breeze,
      name: 'KDE Breeze',
      desktopEnv: 'KDE Plasma • Plasma Blue & Charcoal',
      darkBg: Color(0xFF1B1E20),
      darkSurface: Color(0xFF232629),
      accent: Color(0xFF3DAEE9),
      secondaryAccent: Color(0xFF1CDC9A),
    ),
    PacerLinuxThemeInfo(
      id: PacerLinuxTheme.cinnamon,
      name: 'Mint-Y Cinnamon',
      desktopEnv: 'Linux Mint • Mint Leaf & Warm Slate',
      darkBg: Color(0xFF1E1E1E),
      darkSurface: Color(0xFF2B2B2B),
      accent: Color(0xFF8FA876),
      secondaryAccent: Color(0xFFA3BE8C),
    ),
    PacerLinuxThemeInfo(
      id: PacerLinuxTheme.adwaita,
      name: 'GNOME Adwaita',
      desktopEnv: 'GNOME • Libadwaita Blue & Obsidian',
      darkBg: Color(0xFF1E1E1E),
      darkSurface: Color(0xFF303030),
      accent: Color(0xFF62A0EA),
      secondaryAccent: Color(0xFF3584E4),
    ),
    PacerLinuxThemeInfo(
      id: PacerLinuxTheme.yaru,
      name: 'Ubuntu Yaru',
      desktopEnv: 'Ubuntu Desktop • Aubergine & Orange',
      darkBg: Color(0xFF1E0B18),
      darkSurface: Color(0xFF2C1224),
      accent: Color(0xFFE95420),
      secondaryAccent: Color(0xFF77216F),
    ),
    PacerLinuxThemeInfo(
      id: PacerLinuxTheme.nord,
      name: 'Arch Nord',
      desktopEnv: 'Hyprland / i3wm • Polar Night & Frost',
      darkBg: Color(0xFF242933),
      darkSurface: Color(0xFF2E3440),
      accent: Color(0xFF88C0D0),
      secondaryAccent: Color(0xFF81A1C1),
    ),
  ];

  static PacerLinuxThemeInfo of(PacerLinuxTheme preset) =>
      all.firstWhere((e) => e.id == preset, orElse: () => all.first);
}

/// In-app theme mode. Defaults to the OS setting; the toggle persists
/// in-memory for the session (mirrors langNotifier's rebuild pattern —
/// PacerApp listens and rebuilds the whole tree). No backend column.
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(
  ThemeMode.dark,
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
  static const streakCard = Color(0xFF131C33);
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
  final Color streakCardBg;

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
    required this.streakCardBg,
  });

  static const light = PacerScheme(
    brightness: Brightness.light,
    scaffold: Color(0xFFE8EEF5),
    card: Color(0xFFF3F7FC),
    authField: Color(0xFFF1F5FA),
    formField: Color(0xFFF1F5FA),
    searchBg: Color(0xFFDCE5F0),
    ink: Color(0xFF16202E),
    deepInk: Color(0xFF0E1824),
    headline: Color(0xFF132238),
    chipFg: Color(0xFF182433),
    muted: Color(0xFF4E6075),
    soft: Color(0xFF60738A),
    bodyGray: Color(0xFF3E4F65),
    formMuted: Color(0xFF53657B),
    subtle: Color(0x9916202E),
    overlay: Color(0x990B1420),
    hint: Color(0x99253447),
    border: Color(0xFFC9D6E6),
    softBorder: Color(0xFFD3DFEC),
    hairline: Color(0xFFD8E2EE),
    chipBorder: Color(0xFFB9C8DA),
    formEdge: Color(0xFFBFD0E2),
    error: PacerColors.errorRed,
    timeRed: PacerColors.timeRed,
    paceOrange: PacerColors.paceOrange,
    success: Color(0xFF0E7A56),
    accent: Color(0xFF1C64D1),
    runCard: Color(0xFFEDF4FB),
    chatBubble: Color(0xFFE4ECF7),
    navBar: Color(0xFFDCE6F2),
    navIcon: Color(0xFF2B3A4D),
    emptyIcon: Color(0xFFCAD7E6),
    mapBtnB: Color(0xFFEDF3FA),
    finishTop: Color(0xFFE5EDF7),
    finishBottom: Color(0xFFD3E0EE),
    gridLine: Color(0xFFC5D3E3),
    chipSelBg: Color(0xFF16202E),
    chipSelFg: Color(0xFFF3F7FC),
    editBg: Color(0xFF16202E),
    streakCardBg: Color(0xFFDDEAF8),
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
    streakCardBg: PacerDark.streakCard,
  );

  static PacerScheme _buildDarkPreset({
    required Color scaffold,
    required Color surface,
    required Color border,
    required Color chipBorder,
    required Color accent,
    required Color chipSelFg,
    required Color streakCard,
  }) =>
      PacerScheme(
        brightness: Brightness.dark,
        scaffold: scaffold,
        card: surface,
        authField: surface,
        formField: surface,
        searchBg: Color.lerp(scaffold, surface, 0.65)!,
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
        border: border,
        softBorder: border,
        hairline: border,
        chipBorder: chipBorder,
        formEdge: border,
        error: PacerDark.error,
        timeRed: PacerDark.timeRed,
        paceOrange: PacerDark.paceOrange,
        success: PacerDark.success,
        accent: accent,
        runCard: surface,
        chatBubble: surface,
        navBar: surface.withValues(alpha: 0.94),
        navIcon: PacerDark.navIcon,
        emptyIcon: chipBorder,
        mapBtnB: surface,
        finishTop: scaffold,
        finishBottom: surface,
        gridLine: chipBorder,
        chipSelBg: accent,
        chipSelFg: chipSelFg,
        editBg: accent,
        streakCardBg: streakCard,
      );

  static PacerScheme _buildLightPreset({
    required Color scaffold,
    required Color card,
    required Color searchBg,
    required Color ink,
    required Color muted,
    required Color border,
    required Color accent,
    required Color streakCardBg,
  }) =>
      PacerScheme(
        brightness: Brightness.light,
        scaffold: scaffold,
        card: card,
        authField: card,
        formField: card,
        searchBg: searchBg,
        ink: ink,
        deepInk: ink,
        headline: ink,
        chipFg: ink,
        muted: muted,
        soft: muted,
        bodyGray: muted,
        formMuted: muted,
        subtle: ink.withValues(alpha: 0.6),
        overlay: ink.withValues(alpha: 0.6),
        hint: ink.withValues(alpha: 0.6),
        border: border,
        softBorder: border,
        hairline: border,
        chipBorder: border,
        formEdge: border,
        error: PacerColors.errorRed,
        timeRed: PacerColors.timeRed,
        paceOrange: PacerColors.paceOrange,
        success: const Color(0xFF0E7A56),
        accent: accent,
        runCard: Color.lerp(card, scaffold, 0.35)!,
        chatBubble: searchBg,
        navBar: searchBg,
        navIcon: ink,
        emptyIcon: border,
        mapBtnB: card,
        finishTop: scaffold,
        finishBottom: searchBg,
        gridLine: border,
        chipSelBg: accent,
        chipSelFg: Colors.white,
        editBg: accent,
        streakCardBg: streakCardBg,
      );

  static PacerScheme forPreset(Brightness brightness, PacerLinuxTheme preset) {
    final isDark = brightness == Brightness.dark;
    switch (preset) {
      case PacerLinuxTheme.defaultPacer:
        return isDark ? PacerScheme.dark : PacerScheme.light;
      case PacerLinuxTheme.breeze:
        return isDark
            ? _buildDarkPreset(
                scaffold: const Color(0xFF1B1E20),
                surface: const Color(0xFF232629),
                border: const Color(0xFF363B40),
                chipBorder: const Color(0xFF474E54),
                accent: const Color(0xFF3DAEE9),
                chipSelFg: const Color(0xFF0D151C),
                streakCard: const Color(0xFF1F2A34),
              )
            : _buildLightPreset(
                scaffold: const Color(0xFFEFF0F1),
                card: const Color(0xFFFCFDFD),
                searchBg: const Color(0xFFE3E5E7),
                ink: const Color(0xFF232629),
                muted: const Color(0xFF5E656D),
                border: const Color(0xFFCFD3D7),
                accent: const Color(0xFF2980B9),
                streakCardBg: const Color(0xFFDCEEFB),
              );
      case PacerLinuxTheme.cinnamon:
        return isDark
            ? _buildDarkPreset(
                scaffold: const Color(0xFF1E1F1E),
                surface: const Color(0xFF2B2C2B),
                border: const Color(0xFF3E403E),
                chipBorder: const Color(0xFF505450),
                accent: const Color(0xFF8FA876),
                chipSelFg: const Color(0xFF141A10),
                streakCard: const Color(0xFF232B20),
              )
            : _buildLightPreset(
                scaffold: const Color(0xFFEDEDEC),
                card: const Color(0xFFF8F8F7),
                searchBg: const Color(0xFFE1E3DF),
                ink: const Color(0xFF2B2B2B),
                muted: const Color(0xFF5D625B),
                border: const Color(0xFFCFD3CC),
                accent: const Color(0xFF688949),
                streakCardBg: const Color(0xFFE1ECD9),
              );
      case PacerLinuxTheme.adwaita:
        return isDark
            ? _buildDarkPreset(
                scaffold: const Color(0xFF1E1E1E),
                surface: const Color(0xFF303030),
                border: const Color(0xFF454545),
                chipBorder: const Color(0xFF575757),
                accent: const Color(0xFF62A0EA),
                chipSelFg: const Color(0xFF0E1724),
                streakCard: const Color(0xFF242B35),
              )
            : _buildLightPreset(
                scaffold: const Color(0xFFF2F1F0),
                card: const Color(0xFFFAFAFA),
                searchBg: const Color(0xFFE6E5E3),
                ink: const Color(0xFF241F31),
                muted: const Color(0xFF5E5C64),
                border: const Color(0xFFD5D3CF),
                accent: const Color(0xFF3584E4),
                streakCardBg: const Color(0xFFDFECFA),
              );
      case PacerLinuxTheme.yaru:
        return isDark
            ? _buildDarkPreset(
                scaffold: const Color(0xFF1E0B18),
                surface: const Color(0xFF2C1224),
                border: const Color(0xFF4B213E),
                chipBorder: const Color(0xFF612B50),
                accent: const Color(0xFFE95420),
                chipSelFg: Colors.white,
                streakCard: const Color(0xFF351329),
              )
            : _buildLightPreset(
                scaffold: const Color(0xFFF5F1F3),
                card: const Color(0xFFFCF9FA),
                searchBg: const Color(0xFFEAE1E6),
                ink: const Color(0xFF2C001E),
                muted: const Color(0xFF664B5D),
                border: const Color(0xFFD9C8D2),
                accent: const Color(0xFFE95420),
                streakCardBg: const Color(0xFFFCE5DC),
              );
      case PacerLinuxTheme.nord:
        return isDark
            ? _buildDarkPreset(
                scaffold: const Color(0xFF242933),
                surface: const Color(0xFF2E3440),
                border: const Color(0xFF434C5E),
                chipBorder: const Color(0xFF4C566A),
                accent: const Color(0xFF88C0D0),
                chipSelFg: const Color(0xFF1E242E),
                streakCard: const Color(0xFF293242),
              )
            : _buildLightPreset(
                scaffold: const Color(0xFFE5E9F0),
                card: const Color(0xFFECEFF4),
                searchBg: const Color(0xFFD8DEE9),
                ink: const Color(0xFF2E3440),
                muted: const Color(0xFF4C566A),
                border: const Color(0xFFC8D0DF),
                accent: const Color(0xFF5E81AC),
                streakCardBg: const Color(0xFFD8E4F0),
              );
    }
  }

  static PacerScheme of(BuildContext context) =>
      forPreset(Theme.of(context).brightness, linuxThemeNotifier.value);

  /// Ink-colored action label for lime/dark-selected fills; identical to
  /// [chipSelFg] in both modes (white text on black in light, ink on lime
  /// in dark).
  Color get actionFg => chipSelFg;

  /// Theme-aware highlight accent for Join/Joined buttons, badges, and pills.
  /// Resolves to [PacerColors.lime] in the default Pacer theme and to [accent]
  /// when any classic Linux desktop theme is active.
  Color get brandAccent =>
      linuxThemeNotifier.value == PacerLinuxTheme.defaultPacer
      ? PacerColors.lime
      : accent;

  /// High-contrast foreground color for text/icons placed on [brandAccent].
  Color get onBrandAccent =>
      ThemeData.estimateBrightnessForColor(brandAccent) == Brightness.light
      ? PacerColors.ink
      : Colors.white;

  bool get isDark => brightness == Brightness.dark;

  /// Optical rim & surface layering tokens matching the Liquid Glass nav bar.
  Color get cardTopRim => isDark
      ? Colors.white.withValues(alpha: 0.14)
      : Colors.white.withValues(alpha: 0.88);

  Color get cardBottomRim =>
      isDark ? Colors.black.withValues(alpha: 0.28) : border;

  Color get surfaceSheen => isDark
      ? Color.lerp(card, Colors.white, 0.045)!
      : Color.lerp(card, Colors.white, 0.45)!;

  Color get groupedDivider =>
      border.withValues(alpha: isDark ? 0.55 : 0.72);

  List<Color> get heroCardGradient {
    switch (linuxThemeNotifier.value) {
      case PacerLinuxTheme.defaultPacer:
        return isDark
            ? const [PacerColors.teamShade, PacerColors.streakBg]
            : const [Color(0xFF2855C7), Color(0xFF4748B8)];
      case PacerLinuxTheme.breeze:
        return isDark
            ? const [Color(0xFF1A2936), Color(0xFF234766)]
            : const [Color(0xFF1F6391), Color(0xFF2980B9)];
      case PacerLinuxTheme.cinnamon:
        return isDark
            ? const [Color(0xFF212B1E), Color(0xFF364930)]
            : const [Color(0xFF4A6632), Color(0xFF688949)];
      case PacerLinuxTheme.adwaita:
        return isDark
            ? const [Color(0xFF1F2836), Color(0xFF2C456B)]
            : const [Color(0xFF225EA8), Color(0xFF3584E4)];
      case PacerLinuxTheme.yaru:
        return isDark
            ? const [Color(0xFF2C1224), Color(0xFF632145)]
            : const [Color(0xFF5E2144), Color(0xFFB83E1B)];
      case PacerLinuxTheme.nord:
        return isDark
            ? const [Color(0xFF2B3240), Color(0xFF3B4C63)]
            : const [Color(0xFF435D7D), Color(0xFF5E81AC)];
    }
  }

  BoxShadow get shadowBox => BoxShadow(
    color: isDark ? PacerDark.shadow : const Color(0x1416243D),
    blurRadius: isDark ? 2 : 10,
    offset: Offset(0, isDark ? 1 : 3),
  );
}

class PacerTheme {
  static const PageTransitionsTheme _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
    },
  );

  static ThemeData light([PacerLinuxTheme? preset]) {
    final scheme = PacerScheme.forPreset(
      Brightness.light,
      preset ?? linuxThemeNotifier.value,
    );
    return ThemeData(
      useMaterial3: true,
      pageTransitionsTheme: _pageTransitions,
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
      colorScheme: ColorScheme.fromSeed(
        seedColor: scheme.accent,
        primary: scheme.accent,
        surface: scheme.card,
      ),
      cardTheme: CardThemeData(
        color: scheme.card,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.card,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(PacerRadii.hero),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.scaffold,
        foregroundColor: scheme.ink,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.authField,
        hintStyle: PacerText.hint.copyWith(color: scheme.hint),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PacerColors.primary,
          foregroundColor: scheme.ink,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PacerRadii.md),
          ),
          textStyle: PacerText.button,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.ink,
          minimumSize: const Size(0, 50),
          side: BorderSide(color: scheme.border, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PacerRadii.md),
          ),
          textStyle: PacerText.button.copyWith(fontSize: 15),
        ),
      ),
    );
  }

  /// Dark theme: same structure as [light], navy surfaces, light text,
  /// lime accents. Brand fills (lime buttons, purple streak, medals)
  /// are untouched — only theme chrome adapts.
  static ThemeData dark([PacerLinuxTheme? preset]) {
    final scheme = PacerScheme.forPreset(
      Brightness.dark,
      preset ?? linuxThemeNotifier.value,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      pageTransitionsTheme: _pageTransitions,
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
        primary: scheme.accent,
        onPrimary: scheme.chipSelFg,
        secondary: PacerColors.primary,
        surface: scheme.card,
        onSurface: scheme.ink,
        error: scheme.error,
        onError: scheme.ink,
      ),
      iconTheme: IconThemeData(color: scheme.ink),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.card,
        foregroundColor: scheme.ink,
        elevation: 1,
      ),
      cardTheme: CardThemeData(
        color: scheme.card,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.card,
        hintStyle: PacerText.hint.copyWith(color: scheme.hint),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PacerColors.primary,
          foregroundColor: PacerColors.ink,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PacerRadii.md),
          ),
          textStyle: PacerText.button,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.ink,
          minimumSize: const Size(0, 50),
          side: BorderSide(color: scheme.border, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PacerRadii.md),
          ),
          textStyle: PacerText.button.copyWith(fontSize: 15),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(PacerRadii.hero),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.card,
        contentTextStyle: TextStyle(color: scheme.ink),
        actionTextColor: scheme.accent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PacerRadii.hero),
        ),
        titleTextStyle: TextStyle(color: scheme.ink, fontSize: 20),
        contentTextStyle: TextStyle(color: scheme.ink),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.card,
        labelStyle: TextStyle(color: scheme.ink),
        side: BorderSide(color: scheme.border),
      ),
    );
  }
}
