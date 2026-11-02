import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../services/theme_service.dart';
import 'categories_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _budgetAlertPercentage = 85;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeOption>(
      valueListenable: ThemeService.currentTheme,
      builder: (context, currentTheme, _) {
        final isDark = ThemeService.isDarkOrCyber;
        final shadowColor = ThemeService.getShadowColor();
        final borderColor = ThemeService.getBorderColor();
        final headerPillColor = ThemeService.getHeaderPillColor();

        final Color cardBgColor;
        if (currentTheme == AppThemeOption.cyberpunk2077) {
          cardBgColor = const Color(0xFF1C050C);
        } else if (currentTheme == AppThemeOption.edgerunners) {
          cardBgColor = const Color(0xFF16162A);
        } else if (isDark) {
          cardBgColor = const Color(0xFF282836);
        } else {
          cardBgColor = const Color(0xFFFFC6C7);
        }

        final cardTextColor = ThemeService.getTextColorForBackground(cardBgColor);

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Header Pill Box: App Settings
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      color: headerPillColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor, width: 2.0),
                      boxShadow: [
                        BoxShadow(
                          color: shadowColor,
                          offset: const Offset(3, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.settings,
                          color: ThemeService.getTextColorForBackground(headerPillColor),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'App Settings',
                          style: ThemeService.getAppTextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: ThemeService.getTextColorForBackground(headerPillColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Main Settings Card
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor,
                            offset: const Offset(4, 4),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: ListView(
                        children: [
                          const SizedBox(height: 10),

                          // 1. Dark Mode
                          _buildSettingRow(
                            title: 'Dark Mode',
                            buttonText: isDark ? 'ON' : 'OFF',
                            cardTextColor: cardTextColor,
                            borderColor: borderColor,
                            shadowColor: shadowColor,
                            onTap: () {
                              ThemeService.toggleDarkMode(!isDark);
                            },
                          ),

                          const SizedBox(height: 18),

                          // 2. Themes
                          _buildSettingRow(
                            title: 'Themes',
                            buttonText: currentTheme.displayName,
                            cardTextColor: cardTextColor,
                            borderColor: borderColor,
                            shadowColor: shadowColor,
                            onTap: _showThemeSelectionDialog,
                          ),

                          const SizedBox(height: 18),

                          // 3. Budget Alert
                          _buildSettingRow(
                            title: 'Budget Alert',
                            buttonText: '$_budgetAlertPercentage%',
                            cardTextColor: cardTextColor,
                            borderColor: borderColor,
                            shadowColor: shadowColor,
                            onTap: _showBudgetAlertSelectionDialog,
                          ),

                          const SizedBox(height: 18),

                          // 4. Export Database
                          _buildSettingRow(
                            title: 'Export Database',
                            buttonText: 'Export',
                            cardTextColor: cardTextColor,
                            borderColor: borderColor,
                            shadowColor: shadowColor,
                            onTap: _exportDatabase,
                          ),

                          const SizedBox(height: 18),

                          // 5. Import Backup
                          _buildSettingRow(
                            title: 'Import Backup',
                            buttonText: 'Import',
                            cardTextColor: cardTextColor,
                            borderColor: borderColor,
                            shadowColor: shadowColor,
                            onTap: _importBackup,
                          ),

                          const SizedBox(height: 18),

                          // 6. Categories
                          _buildSettingRow(
                            title: 'Categories',
                            buttonText: 'Manage >',
                            cardTextColor: cardTextColor,
                            borderColor: borderColor,
                            shadowColor: shadowColor,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CategoriesScreen(),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 18),

                          // 7. App Version
                          _buildSettingRow(
                            title: 'App Version',
                            buttonText: 'v1.0.0',
                            cardTextColor: cardTextColor,
                            borderColor: borderColor,
                            shadowColor: shadowColor,
                            onTap: null,
                          ),

                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingRow({
    required String title,
    required String buttonText,
    required Color cardTextColor,
    required Color borderColor,
    required Color shadowColor,
    required VoidCallback? onTap,
  }) {
    final btnBgColor = cardTextColor == Colors.white ? const Color(0xFF1E1E2C) : Colors.white;
    final btnTextColor = ThemeService.getTextColorForBackground(btnBgColor);

    return Row(
      children: [
        Text(
          title,
          style: ThemeService.getAppTextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: cardTextColor,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            ' .....................................................',
            overflow: TextOverflow.clip,
            maxLines: 1,
            style: TextStyle(
              fontSize: 16,
              color: cardTextColor.withValues(alpha: 0.4),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: btnBgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  offset: const Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Text(
              '[ $buttonText ]',
              style: ThemeService.getAppTextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: btnTextColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showThemeSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Select App Theme',
          style: ThemeService.getAppTextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppThemeOption.values.map((themeOption) {
            return ListTile(
              title: Text(
                themeOption.displayName,
                style: ThemeService.getAppTextStyle(fontSize: 20),
              ),
              trailing: ThemeService.currentTheme.value == themeOption
                  ? const Icon(Icons.check_circle, color: Colors.pink)
                  : null,
              onTap: () {
                ThemeService.setTheme(themeOption);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showBudgetAlertSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Set Budget Alert Threshold',
          style: ThemeService.getAppTextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [25, 50, 75, 85, 90].map((pct) {
            return ListTile(
              title: Text(
                '$pct%',
                style: ThemeService.getAppTextStyle(fontSize: 20),
              ),
              trailing: _budgetAlertPercentage == pct ? const Icon(Icons.check, color: Colors.pink) : null,
              onTap: () {
                setState(() => _budgetAlertPercentage = pct);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _exportDatabase() async {
    try {
      final filePath = await DatabaseHelper.instance.exportTransactionsToCSV();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Database exported successfully!\nLocation: $filePath'),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  void _importBackup() {
    final TextEditingController csvInputController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Import Backup Data',
          style: ThemeService.getAppTextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Paste your CSV backup data below:',
              style: ThemeService.getAppTextStyle(fontSize: 18),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: csvInputController,
              maxLines: 4,
              style: ThemeService.getAppTextStyle(fontSize: 18),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'ID,Amount,Type,Date,Merchant,Notes,CategoryID...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: ThemeService.getAppTextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () async {
              final content = csvInputController.text.trim();
              if (content.isNotEmpty) {
                int imported = await DatabaseHelper.instance.importTransactionsFromCSV(content);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Successfully imported $imported transactions!')),
                );
              }
            },
            child: Text('Import', style: ThemeService.getAppTextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}
