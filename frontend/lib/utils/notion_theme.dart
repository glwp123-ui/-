import 'package:flutter/material.dart';

class NotionTheme {
  // ── Sidebar (Dark)
  static const Color sidebarBg     = Color(0xFF1F1F1F);
  static const Color sidebarHover  = Color(0xFF2D2D2D);
  static const Color sidebarActive = Color(0xFF373737);
  static const Color sidebarText   = Color(0xFFCFCFCF);
  static const Color sidebarSubtext= Color(0xFF8B8B8B);
  static const Color sidebarIcon   = Color(0xFF9B9B9B);
  static const Color sidebarDivider= Color(0xFF2F2F2F);

  // ── Main Area (Light)
  static const Color mainBg        = Color(0xFFFFFFFF);
  static const Color surface       = Color(0xFFF7F7F5);
  static const Color border        = Color(0xFFE8E8E5);
  static const Color borderLight   = Color(0xFFF1F1EE);
  static const Color textPrimary   = Color(0xFF191919);
  static const Color textSecondary = Color(0xFF9B9B9B);
  static const Color textMuted     = Color(0xFFB0B0B0);

  // ── Board Column Headers
  static const Color colNotStartedBg = Color(0xFFF4F4F4);
  static const Color colInProgressBg = Color(0xFFF0F6FD);
  static const Color colDoneBg       = Color(0xFFEEF7F5);

  // ── Accent
  static const Color accent        = Color(0xFF2383E2);
  static const Color accentLight   = Color(0xFFDCEEFD);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Pretendard',
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      surface: mainBg,
    ),
    scaffoldBackgroundColor: mainBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: mainBg,
      foregroundColor: textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: mainBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: border, width: 1),
      ),
    ),
    dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 0),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      hintStyle: const TextStyle(color: textMuted, fontSize: 14),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accent),
    ),
  );
}
