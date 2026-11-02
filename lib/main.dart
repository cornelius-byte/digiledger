import 'package:flutter/material.dart';
import 'database/database_helper.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  await NotificationService.init(); // Initialize local notifications
  await ThemeService.init();        // Load saved theme preference from local SQLite database

  runApp(const DigiledgerApp());
}

class DigiledgerApp extends StatelessWidget {
  const DigiledgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeOption>(
      valueListenable: ThemeService.currentTheme,
      builder: (context, currentTheme, _) {
        return MaterialApp(
          title: 'Digiledger',
          debugShowCheckedModeBanner: false,
          theme: ThemeService.getThemeData(),
          home: const SplashScreen(),
        );
      },
    );
  }
}
