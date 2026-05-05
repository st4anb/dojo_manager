import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color backgroundBlack = Color(0xFF000000);
  static const Color accentGold = Color(0xFFFFD700);
  static const Color cardDarkGrey = Color(0xFF080808); // Ultra-preto: blend máximo com fundo #000
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGrey = Color(0xFF8C8C8C);
  static const Color glassWhite = Color(0x08FFFFFF); // rgba(255, 255, 255, 0.03)

  // ═══ PREMIUM 3D GLASS TOKENS ═══
  static const Color glassBg = Color(0x66191919);       // rgba(25, 25, 25, 0.4)
  static const Color glassBorder = Color(0x14FFFFFF);    // rgba(255, 255, 255, 0.08)
  static const Color glassInset = Color(0x1AFFFFFF);     // rgba(255, 255, 255, 0.1) - inset highlight

  /// Premium 3D floating shadow for glass cards
  static List<BoxShadow> get premiumShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.37),
      blurRadius: 32,
      offset: const Offset(0, 8),
    ),
  ];

  /// Complete glass decoration for Container-based cards
  static BoxDecoration glassDecoration({double radius = 20, Border? customBorder}) => BoxDecoration(
    color: cardDarkGrey,
    borderRadius: BorderRadius.circular(radius),
    border: customBorder ?? Border.all(color: glassBorder, width: 1),
    boxShadow: premiumShadow,
  );

  static const LinearGradient premiumGoldGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundBlack,
      primaryColor: accentGold,
      colorScheme: const ColorScheme.dark(
        primary: accentGold,
        secondary: accentGold,
        surface: backgroundBlack,
        onPrimary: backgroundBlack,
        onSurface: textWhite,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(color: textWhite, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.inter(color: textWhite, fontWeight: FontWeight.bold),
        displaySmall: GoogleFonts.inter(color: textWhite, fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.inter(color: textWhite, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.inter(color: textWhite, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: textWhite),
        bodyMedium: GoogleFonts.inter(color: textGrey),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundBlack,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: accentGold),
        titleTextStyle: TextStyle(
          color: textWhite,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardDarkGrey,
        elevation: 0, // Usando custom premiumShadow via BoxDecoration
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
          side: const BorderSide(color: glassBorder, width: 1),
        ),
        margin: const EdgeInsets.all(16.0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentGold,
          foregroundColor: backgroundBlack, // text color
          elevation: 4,
          shadowColor: accentGold.withValues(alpha: 0.3),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDarkGrey,
        hintStyle: const TextStyle(color: textGrey),
        labelStyle: const TextStyle(color: textWhite),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: accentGold, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}
