import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';

enum AppThemeOption {
  pastel('Pastel'),
  mint('Mint'),
  sunset('Sunset'),
  dark('Dark'),
  edgerunners('Edgerunners'),
  cyberpunk2077('Cyberpunk 2077'),
  lalaland('La La Land');

  final String displayName;
  const AppThemeOption(this.displayName);
}

class ThemeService {
  static final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(false);
  static final ValueNotifier<AppThemeOption> currentTheme = ValueNotifier<AppThemeOption>(AppThemeOption.pastel);

  static Future<void> init() async {
    try {
      final savedThemeStr = await DatabaseHelper.instance.getSetting('app_theme');
      if (savedThemeStr != null) {
        final option = AppThemeOption.values.firstWhere(
              (e) => e.name == savedThemeStr,
          orElse: () => AppThemeOption.pastel,
        );
        currentTheme.value = option;
      }

      final savedDarkModeStr = await DatabaseHelper.instance.getSetting('dark_mode');
      if (savedDarkModeStr != null) {
        isDarkMode.value = savedDarkModeStr == 'true';
      } else {
        isDarkMode.value = currentTheme.value == AppThemeOption.dark ||
            currentTheme.value == AppThemeOption.edgerunners ||
            currentTheme.value == AppThemeOption.cyberpunk2077 ||
            currentTheme.value == AppThemeOption.lalaland;
      }
    } catch (_) {}
  }

  static void toggleDarkMode(bool value) {
    isDarkMode.value = value;
    if (value) {
      currentTheme.value = AppThemeOption.dark;
    } else if (currentTheme.value == AppThemeOption.dark) {
      currentTheme.value = AppThemeOption.pastel;
    }
    DatabaseHelper.instance.saveSetting('app_theme', currentTheme.value.name);
    DatabaseHelper.instance.saveSetting('dark_mode', value.toString());
  }

  static void setTheme(AppThemeOption option) {
    currentTheme.value = option;
    if (option == AppThemeOption.dark ||
        option == AppThemeOption.edgerunners ||
        option == AppThemeOption.cyberpunk2077 ||
        option == AppThemeOption.lalaland) {
      isDarkMode.value = true;
    } else {
      isDarkMode.value = false;
    }
    DatabaseHelper.instance.saveSetting('app_theme', option.name);
    DatabaseHelper.instance.saveSetting('dark_mode', isDarkMode.value.toString());
  }

  static bool get isDarkOrCyber {
    final theme = currentTheme.value;
    return isDarkMode.value ||
        theme == AppThemeOption.dark ||
        theme == AppThemeOption.edgerunners ||
        theme == AppThemeOption.cyberpunk2077 ||
        theme == AppThemeOption.lalaland;
  }

  // Returns theme-appropriate text style matching font preferences
  static TextStyle getAppTextStyle({
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
  }) {
    final theme = currentTheme.value;
    if (theme == AppThemeOption.cyberpunk2077) {
      return GoogleFonts.shareTechMono(
        fontSize: fontSize - 1,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: 1.0,
      );
    } else if (theme == AppThemeOption.edgerunners) {
      return GoogleFonts.orbitron(
        fontSize: fontSize > 16 ? fontSize - 3 : fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: 1.0,
      );
    } else {
      return GoogleFonts.patrickHand(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
    }
  }

  // Returns appropriate text color based on background luminance
  static Color getTextColorForBackground(Color bg) {
    if (currentTheme.value == AppThemeOption.cyberpunk2077) {
      return bg.computeLuminance() > 0.4 ? Colors.black : Colors.white;
    }
    if (currentTheme.value == AppThemeOption.lalaland) {
      return bg.computeLuminance() > 0.4 ? Colors.black : const Color(0xFFFFF3BF); // Soft warm gold/white text
    }
    return bg.computeLuminance() > 0.4 ? Colors.black : Colors.white;
  }

  static Color getSecondaryTextColorForBackground(Color bg) {
    if (currentTheme.value == AppThemeOption.cyberpunk2077) {
      return const Color(0xFF00F0FF); // Cyberpunk Cyan
    }
    if (currentTheme.value == AppThemeOption.lalaland) {
      return const Color(0xFFD3B1A7); // Sunset Rose
    }
    return bg.computeLuminance() > 0.4 ? Colors.black54 : Colors.white70;
  }

  // Returns theme-appropriate card shadow color
  static Color getShadowColor() {
    switch (currentTheme.value) {
      case AppThemeOption.cyberpunk2077:
        return const Color(0xFFFF003C).withValues(alpha: 0.8); // Cyber Red glow shadow
      case AppThemeOption.edgerunners:
        return const Color(0xFF00F0FF).withValues(alpha: 0.8); // Neon Cyan glow shadow
      case AppThemeOption.lalaland:
        return const Color(0xFFB59424).withValues(alpha: 0.8); // Golden glow shadow
      case AppThemeOption.dark:
        return Colors.black.withValues(alpha: 0.7);
      case AppThemeOption.mint:
      case AppThemeOption.sunset:
      case AppThemeOption.pastel:
        return Colors.black;
    }
  }

  // Returns theme-appropriate border color
  static Color getBorderColor() {
    switch (currentTheme.value) {
      case AppThemeOption.cyberpunk2077:
        return const Color(0xFFFF003C); // Cyberpunk Red border
      case AppThemeOption.edgerunners:
        return const Color(0xFFFEE715); // Neon Yellow border
      case AppThemeOption.lalaland:
        return const Color(0xFFB59424); // Emma Stone Dress Gold border
      case AppThemeOption.dark:
        return const Color(0xFF4A4A68);
      case AppThemeOption.mint:
      case AppThemeOption.sunset:
      case AppThemeOption.pastel:
        return Colors.black;
    }
  }

  // Returns header pill color
  static Color getHeaderPillColor() {
    switch (currentTheme.value) {
      case AppThemeOption.cyberpunk2077:
        return const Color(0xFFFF003C); // Cyberpunk Red
      case AppThemeOption.edgerunners:
        return const Color(0xFFFEE715); // Edgerunners Yellow
      case AppThemeOption.lalaland:
        return const Color(0xFFB59424); // Mustard Gold
      case AppThemeOption.dark:
        return const Color(0xFF2D2D44);
      case AppThemeOption.mint:
        return const Color(0xFFBCE6FF);
      case AppThemeOption.sunset:
        return const Color(0xFFFFC6C7);
      case AppThemeOption.pastel:
        return const Color(0xFFE8C8EC);
    }
  }

  static ThemeData getThemeData() {
    final theme = currentTheme.value;

    switch (theme) {
      case AppThemeOption.cyberpunk2077:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF100206),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFF003C),
            secondary: Color(0xFF00F0FF),
            surface: Color(0xFF1C050C),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFFF003C),
            foregroundColor: Colors.black,
          ),
          useMaterial3: true,
        );

      case AppThemeOption.edgerunners:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0D0D15),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFEE715),
            secondary: Color(0xFF00F0FF),
            surface: Color(0xFF1A1A2A),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFFEE715),
            foregroundColor: Colors.black,
          ),
          useMaterial3: true,
        );

      case AppThemeOption.lalaland:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Colors.transparent, // Transparent so starry background shows
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFB59424), // Mustard Gold
            secondary: Color(0xFF8F93B8), // Twilight Lavender
            surface: Color(0xFF182226), // Twilight Pine / Navy Card
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFB59424),
            foregroundColor: Colors.black,
          ),
          useMaterial3: true,
        );

      case AppThemeOption.dark:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF1A1A24),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFF9EAA),
            secondary: Color(0xFFA8E6CF),
            surface: Color(0xFF282836),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF282836),
            foregroundColor: Colors.white,
          ),
          useMaterial3: true,
        );

      case AppThemeOption.mint:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFFD0F4DE),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFBCE6FF),
            secondary: Color(0xFFFFC6C7),
            surface: Color(0xFFE8A87C),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFBCE6FF),
            foregroundColor: Colors.black,
          ),
          useMaterial3: true,
        );

      case AppThemeOption.sunset:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFFE8A87C),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFFFC6C7),
            secondary: Color(0xFFFFF3BF),
            surface: Color(0xFFD0F4DE),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFFFC6C7),
            foregroundColor: Colors.black,
          ),
          useMaterial3: true,
        );

      case AppThemeOption.pastel:
        return ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFBCE6FF),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFFFC6C7),
            secondary: Color(0xFFD0F4DE),
            surface: Color(0xFFE8A87C),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFFFC6C7),
            foregroundColor: Colors.black,
          ),
          useMaterial3: true,
        );
    }
  }
}
