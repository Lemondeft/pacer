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
}
