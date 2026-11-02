import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import '../services/lalaland_background.dart';
import 'home_screen.dart';
import 'budgets_screen.dart';
import 'settings_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const BudgetsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeOption>(
      valueListenable: ThemeService.currentTheme,
      builder: (context, currentTheme, _) {
        final scaffold = Scaffold(
          backgroundColor: currentTheme == AppThemeOption.lalaland ? Colors.transparent : null,
          body: _screens[_currentIndex],
          bottomNavigationBar: _buildCustomBottomNavBar(
            context: context,
            currentTheme: currentTheme,
          ),
        );

        if (currentTheme == AppThemeOption.lalaland) {
          return LaLaLandBackground(child: scaffold);
        }
        return scaffold;
      },
    );
  }

  Widget _buildCustomBottomNavBar({
    required BuildContext context,
    required AppThemeOption currentTheme,
  }) {
    final isDark = ThemeService.isDarkOrCyber;
    final shadowColor = ThemeService.getShadowColor();
    final borderColor = ThemeService.getBorderColor();

    Color navBgColor;
    Color selectedColor;
    Color unselectedColor;

    switch (currentTheme) {
      case AppThemeOption.cyberpunk2077:
        navBgColor = const Color(0xFF1C050C);
        selectedColor = const Color(0xFFFF003C); // Cyber Red
        unselectedColor = const Color(0xFF00F0FF); // Cyber Cyan
        break;

      case AppThemeOption.edgerunners:
        navBgColor = const Color(0xFF161625);
        selectedColor = const Color(0xFFFEE715); // Electric Yellow
        unselectedColor = const Color(0xFF00F0FF).withValues(alpha: 0.7); // Neon Cyan
        break;

      case AppThemeOption.lalaland:
        navBgColor = const Color(0xFF182226).withValues(alpha: 0.95); // Twilight Pine translucent
        selectedColor = const Color(0xFFB59424); // Mustard Gold
        unselectedColor = const Color(0xFF8F93B8); // Twilight Lavender
        break;

      case AppThemeOption.dark:
        navBgColor = const Color(0xFF282836);
        selectedColor = const Color(0xFFFF9EAA); // Soft Pink
        unselectedColor = Colors.white54;
        break;

      case AppThemeOption.mint:
        navBgColor = const Color(0xFFBCE6FF);
        selectedColor = Colors.black;
        unselectedColor = Colors.black54;
        break;

      case AppThemeOption.sunset:
        navBgColor = const Color(0xFFFFC6C7);
        selectedColor = Colors.black;
        unselectedColor = Colors.black54;
        break;

      case AppThemeOption.pastel:
        navBgColor = const Color(0xFFFFC6C7);
        selectedColor = Colors.black;
        unselectedColor = Colors.black54;
        break;
    }

    final items = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.account_balance_wallet_rounded, 'label': 'Budgets'},
      {'icon': Icons.settings_rounded, 'label': 'Settings'},
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: navBgColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor, width: 2.2),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: const Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isSelected = _currentIndex == index;
          final iconColor = isSelected ? selectedColor : unselectedColor;

          return InkWell(
            onTap: () {
              setState(() {
                _currentIndex = index;
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: isSelected
                  ? BoxDecoration(
                color: isDark
                    ? (currentTheme == AppThemeOption.cyberpunk2077
                    ? const Color(0xFF2E0914)
                    : (currentTheme == AppThemeOption.edgerunners
                    ? const Color(0xFF26263A)
                    : (currentTheme == AppThemeOption.lalaland
                    ? const Color(0xFF28324C).withValues(alpha: 0.9)
                    : const Color(0xFF3B3B52))))
                    : Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 1.8),
              )
                  : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item['icon'] as IconData,
                    size: 26,
                    color: iconColor,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['label'] as String,
                    style: ThemeService.getAppTextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: iconColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
