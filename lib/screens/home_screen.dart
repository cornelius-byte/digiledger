import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import '../services/theme_service.dart';
import 'add_transaction_screen.dart';
import 'transaction_history_screen.dart';
import 'analytics.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  double _totalExpenses = 0.0;
  List<Map<String, dynamic>> _recentTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final transactions = await DatabaseHelper.instance.getFilteredTransactions();

      double sum = 0.0;
      for (var tx in transactions) {
        final type = (tx['type'] as String? ?? 'Expense').toLowerCase();
        if (type == 'income') continue;
        sum += (tx['amount'] as num?)?.toDouble() ?? 0.0;
      }

      setState(() {
        _totalExpenses = sum;
        _recentTransactions = transactions.take(5).map((e) => Map<String, dynamic>.from(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showDeleteConfirmationDialog({required String title, required String content}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return ValueListenableBuilder<AppThemeOption>(
          valueListenable: ThemeService.currentTheme,
          builder: (dialogContext, currentTheme, _) {
            final isDark = ThemeService.isDarkOrCyber;
            final borderColor = ThemeService.getBorderColor();
            final cardBgColor = isDark
                ? (currentTheme == AppThemeOption.cyberpunk2077
                ? const Color(0xFF1C050C)
                : const Color(0xFF282836))
                : Colors.white;

            final textColor = ThemeService.getTextColorForBackground(cardBgColor);

            return AlertDialog(
              backgroundColor: cardBgColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: borderColor, width: 2.0),
              ),
              title: Text(
                title,
                style: ThemeService.getAppTextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              content: Text(
                content,
                style: ThemeService.getAppTextStyle(
                  fontSize: 17,
                  color: textColor.withValues(alpha: 0.9),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text('Cancel', style: ThemeService.getAppTextStyle(fontSize: 17)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(
                    'Delete',
                    style: ThemeService.getAppTextStyle(fontSize: 17, color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    return result ?? false;
  }

  void _showTransactionContextMenu(Map<String, dynamic> tx) {
    final int txId = (tx['transaction_id'] as num?)?.toInt() ?? 0;
    final String currentMerchant = tx['merchant'] ?? 'Unknown';
    final double currentAmount = (tx['amount'] as num?)?.toDouble() ?? 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return ValueListenableBuilder<AppThemeOption>(
          valueListenable: ThemeService.currentTheme,
          builder: (modalContext, currentTheme, _) {
            final isDark = ThemeService.isDarkOrCyber;
            final borderColor = ThemeService.getBorderColor();
            final shadowColor = ThemeService.getShadowColor();
            final cardBgColor = isDark
                ? (currentTheme == AppThemeOption.cyberpunk2077
                ? const Color(0xFF1C050C)
                : const Color(0xFF282836))
                : const Color(0xFFFFC6C7);

            final textColor = ThemeService.getTextColorForBackground(cardBgColor);

            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor, width: 2.0),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    offset: const Offset(4, 4),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Expense Options',
                    style: ThemeService.getAppTextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.edit, color: Colors.blueAccent),
                    title: Text(
                      'Edit Expense',
                      style: ThemeService.getAppTextStyle(
                        fontSize: 20,
                        color: textColor,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(modalContext);
                      _showEditExpenseDialog(txId, currentMerchant, currentAmount);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.redAccent),
                    title: Text(
                      'Delete Expense',
                      style: ThemeService.getAppTextStyle(
                        fontSize: 20,
                        color: textColor,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(modalContext);
                      final confirmed = await _showDeleteConfirmationDialog(
                        title: 'Delete Expense?',
                        content: 'Are you sure you want to delete this expense for "$currentMerchant"? This action cannot be undone.',
                      );
                      if (confirmed) {
                        await DatabaseHelper.instance.deleteTransaction(txId);
                        await _loadDashboardData();
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditExpenseDialog(int txId, String merchant, double amount) {
    final TextEditingController amountController =
    TextEditingController(text: amount.toStringAsFixed(2));
    final TextEditingController merchantController =
    TextEditingController(text: merchant);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return ValueListenableBuilder<AppThemeOption>(
          valueListenable: ThemeService.currentTheme,
          builder: (dialogContext, currentTheme, _) {
            final isDark = ThemeService.isDarkOrCyber;
            final borderColor = ThemeService.getBorderColor();
            final cardBgColor = isDark
                ? (currentTheme == AppThemeOption.cyberpunk2077
                ? const Color(0xFF1C050C)
                : const Color(0xFF282836))
                : Colors.white;

            final textColor = ThemeService.getTextColorForBackground(cardBgColor);

            return AlertDialog(
              backgroundColor: cardBgColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: borderColor, width: 2.0),
              ),
              title: Text(
                'Edit Expense',
                style: ThemeService.getAppTextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: ThemeService.getAppTextStyle(fontSize: 20, color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Amount (\$)',
                      labelStyle: ThemeService.getAppTextStyle(fontSize: 18, color: textColor),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: merchantController,
                    style: ThemeService.getAppTextStyle(fontSize: 20, color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Merchant Name',
                      labelStyle: ThemeService.getAppTextStyle(fontSize: 18, color: textColor),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('Cancel', style: ThemeService.getAppTextStyle(fontSize: 18)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC6C7)),
                  onPressed: () async {
                    final newAmount = double.tryParse(amountController.text) ?? amount;
                    final newMerchant = merchantController.text.trim().isEmpty
                        ? merchant
                        : merchantController.text.trim();

                    await DatabaseHelper.instance.updateTransaction(
                      txId,
                      newAmount,
                      newMerchant,
                    );
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                    await _loadDashboardData();
                  },
                  child: Text('Save', style: ThemeService.getAppTextStyle(fontSize: 18, color: Colors.black)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeOption>(
      valueListenable: ThemeService.currentTheme,
      builder: (context, currentTheme, _) {
        final isDark = ThemeService.isDarkOrCyber;
        final shadowColor = ThemeService.getShadowColor();
        final borderColor = ThemeService.getBorderColor();
        final headerPillColor = ThemeService.getHeaderPillColor();

        final cardBgColor = isDark
            ? (currentTheme == AppThemeOption.cyberpunk2077
            ? const Color(0xFF1C050C)
            : (currentTheme == AppThemeOption.edgerunners
            ? const Color(0xFF161625)
            : (currentTheme == AppThemeOption.lalaland
            ? const Color(0xFF182226).withValues(alpha: 0.9)
            : const Color(0xFF282836))))
            : const Color(0xFFD0F4DE);

        final cardTextColor = ThemeService.getTextColorForBackground(cardBgColor);
        final secondaryTextColor = ThemeService.getSecondaryTextColorForBackground(cardBgColor);

        return Scaffold(
          backgroundColor: currentTheme == AppThemeOption.lalaland ? Colors.transparent : null,
          body: SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // 1. Header Pill Bar
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Digiledger Dashboard',
                            overflow: TextOverflow.ellipsis,
                            style: ThemeService.getAppTextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: ThemeService.getTextColorForBackground(headerPillColor),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.refresh,
                            color: ThemeService.getTextColorForBackground(headerPillColor),
                            size: 26,
                          ),
                          tooltip: 'Refresh Dashboard',
                          onPressed: _loadDashboardData,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Total Tracked Expenses Summary Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: borderColor, width: 2.0),
                      boxShadow: [
                        BoxShadow(
                          color: shadowColor,
                          offset: const Offset(4, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Tracked Expenses',
                          style: ThemeService.getAppTextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '-\$${_totalExpenses.toStringAsFixed(2)}',
                            style: ThemeService.getAppTextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: currentTheme == AppThemeOption.cyberpunk2077 ||
                                  currentTheme == AppThemeOption.edgerunners
                                  ? const Color(0xFFFF0055)
                                  : (currentTheme == AppThemeOption.lalaland
                                  ? const Color(0xFFFFD166)
                                  : Colors.redAccent),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('🔒 ', style: TextStyle(fontSize: 14)),
                            Expanded(
                              child: Text(
                                'Offline-first & local SQLite storage',
                                style: ThemeService.getAppTextStyle(
                                  fontSize: 15,
                                  color: cardTextColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. Quick Access Bounding Box Container
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? (currentTheme == AppThemeOption.cyberpunk2077
                          ? const Color(0xFF1A040A)
                          : (currentTheme == AppThemeOption.edgerunners
                          ? const Color(0xFF1F1F35)
                          : (currentTheme == AppThemeOption.lalaland
                          ? const Color(0xFF151B2B).withValues(alpha: 0.85)
                          : const Color(0xFF222230))))
                          : const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: borderColor, width: 2.0),
                      boxShadow: [
                        BoxShadow(
                          color: shadowColor,
                          offset: const Offset(4, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Access',
                          style: ThemeService.getAppTextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? (currentTheme == AppThemeOption.cyberpunk2077
                                ? const Color(0xFFFF003C)
                                : (currentTheme == AppThemeOption.lalaland
                                ? const Color(0xFFFFF3BF)
                                : Colors.white))
                                : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 14),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 2.2,
                          children: [
                            _buildNavButton(
                              context,
                              title: 'Add Expense',
                              icon: Icons.add_circle_outline,
                              color: isDark
                                  ? (currentTheme == AppThemeOption.cyberpunk2077
                                  ? const Color(0xFF2E0914)
                                  : (currentTheme == AppThemeOption.lalaland
                                  ? const Color(0xFF232D45)
                                  : const Color(0xFF324B66)))
                                  : const Color(0xFFBCE6FF),
                              destination: const AddTransactionScreen(),
                              borderColor: borderColor,
                              shadowColor: shadowColor,
                            ),
                            _buildNavButton(
                              context,
                              title: 'History',
                              icon: Icons.history,
                              color: isDark
                                  ? (currentTheme == AppThemeOption.cyberpunk2077
                                  ? const Color(0xFF2E0914)
                                  : (currentTheme == AppThemeOption.lalaland
                                  ? const Color(0xFF232D45)
                                  : const Color(0xFF663E48)))
                                  : const Color(0xFFFFC6C7),
                              destination: const TransactionHistoryScreen(),
                              borderColor: borderColor,
                              shadowColor: shadowColor,
                            ),
                            _buildNavButton(
                              context,
                              title: 'Analytics',
                              icon: Icons.bar_chart,
                              color: isDark
                                  ? (currentTheme == AppThemeOption.cyberpunk2077
                                  ? const Color(0xFF2E0914)
                                  : (currentTheme == AppThemeOption.lalaland
                                  ? const Color(0xFF232D45)
                                  : const Color(0xFF665E38)))
                                  : const Color(0xFFFFF1BA),
                              destination: const AnalyticsScreen(),
                              borderColor: borderColor,
                              shadowColor: shadowColor,
                            ),
                            _buildExportButton(
                              context,
                              borderColor: borderColor,
                              shadowColor: shadowColor,
                              isDark: isDark,
                              currentTheme: currentTheme,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4. Recent Expenses Bounding Box Container
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? (currentTheme == AppThemeOption.cyberpunk2077
                          ? const Color(0xFF1A040A)
                          : (currentTheme == AppThemeOption.edgerunners
                          ? const Color(0xFF1F1F35)
                          : (currentTheme == AppThemeOption.lalaland
                          ? const Color(0xFF151B2B).withValues(alpha: 0.85)
                          : const Color(0xFF222230))))
                          : const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: borderColor, width: 2.0),
                      boxShadow: [
                        BoxShadow(
                          color: shadowColor,
                          offset: const Offset(4, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Recent Expenses',
                                overflow: TextOverflow.ellipsis,
                                style: ThemeService.getAppTextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? (currentTheme == AppThemeOption.cyberpunk2077
                                      ? const Color(0xFFFF003C)
                                      : (currentTheme == AppThemeOption.lalaland
                                      ? const Color(0xFFFFF3BF)
                                      : Colors.white))
                                      : Colors.black,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const TransactionHistoryScreen(),
                                  ),
                                ).then((_) => _loadDashboardData());
                              },
                              child: Text(
                                'View All',
                                style: ThemeService.getAppTextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: currentTheme == AppThemeOption.cyberpunk2077 ||
                                      currentTheme == AppThemeOption.edgerunners
                                      ? const Color(0xFF00F0FF)
                                      : (currentTheme == AppThemeOption.lalaland
                                      ? const Color(0xFF8F93B8)
                                      : Colors.pinkAccent),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        _recentTransactions.isEmpty
                            ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(
                            child: Text(
                              'No expenses recorded yet.\nTap "Add Expense" to get started!',
                              textAlign: TextAlign.center,
                              style: ThemeService.getAppTextStyle(
                                fontSize: 16,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ),
                        )
                            : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _recentTransactions.length,
                          itemBuilder: (context, index) {
                            final tx = _recentTransactions[index];
                            final itemBgColor = isDark
                                ? (currentTheme == AppThemeOption.cyberpunk2077
                                ? const Color(0xFF260510)
                                : (currentTheme == AppThemeOption.edgerunners
                                ? const Color(0xFF12121E)
                                : (currentTheme == AppThemeOption.lalaland
                                ? const Color(0xFF232D45).withValues(alpha: 0.9)
                                : const Color(0xFF2B2B3D))))
                                : Colors.white;

                            final itemTextColor = ThemeService.getTextColorForBackground(itemBgColor);
                            final itemSubTextColor = ThemeService.getSecondaryTextColorForBackground(itemBgColor);
                            final merchant = tx['merchant'] ?? 'Unknown';
                            final dateStr = tx['date'] != null ? tx['date'].toString().split('T')[0] : '';
                            final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;

                            return InkWell(
                              onTap: () {},
                              onLongPress: () => _showTransactionContextMenu(tx),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: itemBgColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: borderColor, width: 1.8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: shadowColor,
                                      offset: const Offset(2, 2),
                                      blurRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: currentTheme == AppThemeOption.lalaland
                                          ? const Color(0xFFB59424)
                                          : const Color(0xFFFFC6C7),
                                      radius: 20,
                                      child: Icon(
                                        Icons.arrow_downward,
                                        color: currentTheme == AppThemeOption.lalaland ? Colors.white : Colors.black,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            merchant,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style: ThemeService.getAppTextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: itemTextColor,
                                            ),
                                          ),
                                          Text(
                                            dateStr,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style: ThemeService.getAppTextStyle(
                                              fontSize: 14,
                                              color: itemSubTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '-\$${amount.toStringAsFixed(2)}',
                                      style: ThemeService.getAppTextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.bold,
                                        color: currentTheme == AppThemeOption.cyberpunk2077 ||
                                            currentTheme == AppThemeOption.edgerunners
                                            ? const Color(0xFFFF0055)
                                            : (currentTheme == AppThemeOption.lalaland
                                            ? const Color(0xFFFFD166)
                                            : Colors.redAccent),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
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

  Widget _buildNavButton(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Color color,
        required Widget destination,
        required Color borderColor,
        required Color shadowColor,
      }) {
    final textColor = ThemeService.getTextColorForBackground(color);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destination),
        ).then((_) => _loadDashboardData());
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
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
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: textColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: ThemeService.getAppTextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton(
      BuildContext context, {
        required Color borderColor,
        required Color shadowColor,
        required bool isDark,
        required AppThemeOption currentTheme,
      }) {
    final color = isDark
        ? (currentTheme == AppThemeOption.cyberpunk2077
        ? const Color(0xFF2E0914)
        : (currentTheme == AppThemeOption.lalaland
        ? const Color(0xFF232D45)
        : const Color(0xFF4A4A60)))
        : Colors.grey[200]!;
    final textColor = ThemeService.getTextColorForBackground(color);

    return InkWell(
      onTap: () async {
        try {
          String filePath = await DatabaseHelper.instance.exportTransactionsToCSV();
          await Share.shareXFiles(
            [XFile(filePath)],
            text: 'Here is my offline-first Digiledger backup CSV file.',
          );
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Export failed: $e')),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
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
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download, size: 20, color: textColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Export CSV',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: ThemeService.getAppTextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
