import 'package:flutter/material.dart';
import 'screens/add_transaction_screen.dart';
import 'screens/transaction_history_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/testfile.dart';


void main() {
  runApp(const SmartExpenseTrackerApp());
}

class SmartExpenseTrackerApp extends StatelessWidget {
  const SmartExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFBCE6FF), // Light Blue
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE8A87C), // Peach-Orange
          primary: const Color(0xFFE8A87C),
          secondary: const Color(0xFFFFC6C7), // Pink Cards
          surface: const Color(0xFFD0F4DE), // Mint Green Nav
        ),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // Placeholder views for your core screens
  final List<Widget> _screens = [
    const TransactionHistoryScreen(), // Tab 0: Home / Dashboard View
    const TransactionHistoryScreen(), // Tab 1: Full History
    const AddTransactionScreen(),     // Tab 2: Add Entry (Manual / Scan placeholder)
    const BudgetScreen(),
    const TestFile(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Expense Tracker'),
        backgroundColor: const Color(0xFFFFC6C7),
        elevation: 0,
        actions: const [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Chip(
              label: Text('Offline Mode', style: TextStyle(fontSize: 12)),
              backgroundColor: Color(0xFFD0F4DE),
            ),
          )
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        backgroundColor: const Color(0xFFD0F4DE),
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.add_a_photo), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: 'Budgets'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}