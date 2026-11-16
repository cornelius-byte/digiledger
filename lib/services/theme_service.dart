import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';

enum AppThemeOption {
  cleanModernFintech('Clean Modern Fintech'),
  sleekDark('Sleek Dark Mode'),
  minimalistEditorial('Minimalist Editorial'),
  orixFintech('Orix Fintech'),
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
  static final ValueNotifier<AppThemeOption> currentTheme = ValueNotifier<AppThemeOption>(AppThemeOption.cleanModernFintech);

  static Future<void> init() async {
    try {
      final savedThemeStr = await DatabaseHelper.instance.getSetting('app_theme');
      if (savedThemeStr != null) {
        final option = AppThemeOption.values.firstWhere(
              (e) => e.name == savedThemeStr,
          orElse: () => AppThemeOption.cleanModernFintech,
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
            currentTheme.value == AppThemeOption.lalaland ||
            currentTheme.value == AppThemeOption.sleekDark ||
            currentTheme.value == AppThemeOption.orixFintech;
      }
    } catch (_) {}
  }

  static void toggleDarkMode(bool value) {
    isDarkMode.value = value;
    if (value) {
      currentTheme.value = AppThemeOption.sleekDark;
    } else if (currentTheme.value == AppThemeOption.dark ||
        currentTheme.value == AppThemeOption.sleekDark ||
        currentTheme.value == AppThemeOption.orixFintech) {
      currentTheme.value = AppThemeOption.cleanModernFintech;
    }
    DatabaseHelper.instance.saveSetting('app_theme', currentTheme.value.name);
    DatabaseHelper.instance.saveSetting('dark_mode', value.toString());
  }

  static void setTheme(AppThemeOption option) {
    currentTheme.value = option;
    if (option == AppThemeOption.dark ||
        option == AppThemeOption.edgerunners ||
        option == AppThemeOption.cyberpunk2077 ||
        option == AppThemeOption.lalaland ||
        option == AppThemeOption.sleekDark ||
        option == AppThemeOption.orixFintech) {
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
        theme == AppThemeOption.lalaland ||
        theme == AppThemeOption.sleekDark ||
        theme == AppThemeOption.orixFintech;
  }

  // Returns theme-appropriate text style matching font preferences
  static TextStyle getAppTextStyle({
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    bool tabularNums = false,
  }) {
    final theme = currentTheme.value;
    List<FontFeature>? fontFeatures;
    if (tabularNums || theme == AppThemeOption.cleanModernFintech || theme == AppThemeOption.sleekDark || theme == AppThemeOption.orixFintech) {
      fontFeatures = [const FontFeature.tabularFigures()];
    }

    if (theme == AppThemeOption.cyberpunk2077) {
      return GoogleFonts.shareTechMono(
        fontSize: fontSize - 1,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: 1.0,
        fontFeatures: fontFeatures,
      );
    } else if (theme == AppThemeOption.edgerunners) {
      return GoogleFonts.orbitron(
        fontSize: fontSize > 16 ? fontSize - 3 : fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: 1.0,
        fontFeatures: fontFeatures,
      );
    } else if (theme == AppThemeOption.cleanModernFintech || theme == AppThemeOption.sleekDark || theme == AppThemeOption.minimalistEditorial || theme == AppThemeOption.orixFintech) {
      return GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        fontFeatures: fontFeatures,
      );
    } else {
      return GoogleFonts.patrickHand(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        fontFeatures: fontFeatures,
      );
    }
  }

  static TextStyle getHeaderTextStyle({
    required double fontSize,
    FontWeight fontWeight = FontWeight.bold,
    Color? color,
  }) {
    final theme = currentTheme.value;
    if (theme == AppThemeOption.minimalistEditorial) {
      return GoogleFonts.spaceGrotesk(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
    }
    return getAppTextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color);
  }

  // Big cards (e.g. #F0C38E for orixFintech)
  static Color getBigCardBackgroundColor() {
    final theme = currentTheme.value;
    if (theme == AppThemeOption.orixFintech) {
      return const Color(0xFFF0C38E);
    }
    return isDarkOrCyber ? const Color(0xFF282836) : Colors.white;
  }

  // Small cards / buttons / items (e.g. #312C51 for orixFintech)
  static Color getSmallCardBackgroundColor() {
    final theme = currentTheme.value;
    if (theme == AppThemeOption.orixFintech) {
      return const Color(0xFF312C51);
    }
    return isDarkOrCyber ? const Color(0xFF1E293B) : Colors.white;
  }

  // Returns appropriate text color based on background luminance
  static Color getTextColorForBackground(Color bg) {
    final theme = currentTheme.value;
    if (theme == AppThemeOption.orixFintech) {
      if (bg == const Color(0xFFF0C38E)) {
        return const Color(0xFF312C51);
      }
      return const Color(0xFFF0C38E);
    }
    if (theme == AppThemeOption.cyberpunk2077) {
      return bg.computeLuminance() > 0.4 ? Colors.black : Colors.white;
    }
    if (theme == AppThemeOption.lalaland) {
      return bg.computeLuminance() > 0.4 ? Colors.black : const Color(0xFFFFF3BF);
    }
    if (theme == AppThemeOption.sleekDark) {
      return const Color(0xFFF8FAFC);
    }
    if (theme == AppThemeOption.cleanModernFintech) {
      return bg.computeLuminance() > 0.4 ? const Color(0xFF0F172A) : Colors.white;
    }
    if (theme == AppThemeOption.minimalistEditorial) {
      return const Color(0xFF1E293B);
    }
    return bg.computeLuminance() > 0.4 ? Colors.black : Colors.white;
  }

  static Color getSecondaryTextColorForBackground(Color bg) {
    final theme = currentTheme.value;
    if (theme == AppThemeOption.orixFintech) {
      if (bg == const Color(0xFFF0C38E)) {
        return const Color(0xFF4A4272);
      }
      return const Color(0xFFC4BCDF);
    }
    if (theme == AppThemeOption.cyberpunk2077) {
      return const Color(0xFF00F0FF);
    }
    if (theme == AppThemeOption.lalaland) {
      return const Color(0xFFD3B1A7);
    }
    if (theme == AppThemeOption.sleekDark) {
      return const Color(0xFF94A3B8);
    }
    if (theme == AppThemeOption.cleanModernFintech) {
      return const Color(0xFF64748B);
    }
    if (theme == AppThemeOption.minimalistEditorial) {
      return const Color(0xFF64748B);
    }
    return bg.computeLuminance() > 0.4 ? Colors.black54 : Colors.white70;
  }

  // Returns theme-appropriate card shadow color
  static Color getShadowColor() {
    switch (currentTheme.value) {
      case AppThemeOption.cleanModernFintech:
        return Colors.black.withValues(alpha: 0.04);
      case AppThemeOption.sleekDark:
        return Colors.black.withValues(alpha: 0.4);
      case AppThemeOption.orixFintech:
        return const Color(0xFF1C1833).withValues(alpha: 0.8);
      case AppThemeOption.minimalistEditorial:
        return Colors.transparent;
      case AppThemeOption.cyberpunk2077:
        return const Color(0xFFFF003C).withValues(alpha: 0.8);
      case AppThemeOption.edgerunners:
        return const Color(0xFF00F0FF).withValues(alpha: 0.8);
      case AppThemeOption.lalaland:
        return const Color(0xFFB59424).withValues(alpha: 0.8);
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
      case AppThemeOption.cleanModernFintech:
        return const Color(0xFFE2E8F0);
      case AppThemeOption.sleekDark:
        return const Color(0xFF334155);
      case AppThemeOption.orixFintech:
        return const Color(0xFF5A5285);
      case AppThemeOption.minimalistEditorial:
        return const Color(0xFF1E293B);
      case AppThemeOption.cyberpunk2077:
        return const Color(0xFFFF003C);
      case AppThemeOption.edgerunners:
        return const Color(0xFFFEE715);
      case AppThemeOption.lalaland:
        return const Color(0xFFB59424);
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
      case AppThemeOption.cleanModernFintech:
        return const Color(0xFFFFFFFF);
      case AppThemeOption.sleekDark:
        return const Color(0xFF1E293B);
      case AppThemeOption.orixFintech:
        return const Color(0xFF48426D);
      case AppThemeOption.minimalistEditorial:
        return const Color(0xFFFFFFFF);
      case AppThemeOption.cyberpunk2077:
        return const Color(0xFFFF003C);
      case AppThemeOption.edgerunners:
        return const Color(0xFFFEE715);
      case AppThemeOption.lalaland:
        return const Color(0xFFB59424);
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
      case AppThemeOption.cleanModernFintech:
        return ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF4F46E5),
            secondary: Color(0xFF059669),
            surface: Color(0xFFFFFFFF),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFFFFFFF),
            foregroundColor: Color(0xFF0F172A),
          ),
          useMaterial3: true,
        );

      case AppThemeOption.sleekDark:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF10B981),
            secondary: Color(0xFF38BDF8),
            surface: Color(0xFF1E293B),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E293B),
            foregroundColor: Color(0xFFF8FAFC),
          ),
          useMaterial3: true,
        );

      case AppThemeOption.orixFintech:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF312C51),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFF0C38E),
            secondary: Color(0xFFF1AA9B),
            surface: Color(0xFF48426D),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF48426D),
            foregroundColor: Color(0xFFFFFDF9),
          ),
          useMaterial3: true,
        );

      case AppThemeOption.minimalistEditorial:
        return ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFFAF9F6),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1E293B),
            secondary: Color(0xFFC2410C),
            surface: Color(0xFFFFFFFF),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFFAF9F6),
            foregroundColor: Color(0xFF1E293B),
          ),
          useMaterial3: true,
        );

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
          scaffoldBackgroundColor: Colors.transparent,
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFB59424),
            secondary: Color(0xFF8F93B8),
            surface: Color(0xFF182226),
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
          brightness: Brightness.light,
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
          brightness: Brightness.light,
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
