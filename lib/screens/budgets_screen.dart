import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../services/notification_service.dart';
import '../services/theme_service.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  bool _isLoading = true;
  String _selectedBudgetInterval = 'Monthly'; // Weekly, Monthly, Yearly
  double _budgetLimit = 500.0;
  int _warningThresholdPercentage = 50;
  double _totalSpent = 0.0;

  final TextEditingController _budgetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBudgetFromDatabase();
  }

  Future<void> _loadBudgetFromDatabase() async {
    setState(() => _isLoading = true);
    try {
      final savedBudget = await DatabaseHelper.instance.getBudget(_selectedBudgetInterval);

      if (savedBudget != null) {
        _budgetLimit = (savedBudget['amount'] as num?)?.toDouble() ?? 500.0;
        _warningThresholdPercentage = (savedBudget['threshold_percentage'] as num?)?.toInt() ?? 50;
      } else {
        _budgetLimit = 500.0;
        _warningThresholdPercentage = 50;
      }

      final transactions = await DatabaseHelper.instance.getFilteredTransactions();
      double spent = 0.0;
      final now = DateTime.now();

      for (var tx in transactions) {
        final type = (tx['type'] as String? ?? 'Expense').toLowerCase();
        if (type == 'income') continue;

        final dateStr = tx['date'] as String?;
        if (dateStr == null) continue;
        final dateParsed = DateTime.tryParse(dateStr);
        if (dateParsed == null) continue;
        final date = dateParsed.toLocal();

        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;

        if (_selectedBudgetInterval == 'Weekly') {
          int daysSinceSunday = now.weekday % 7;
          DateTime startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysSinceSunday));
          DateTime endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
          if (date.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
              date.isBefore(endOfWeek.add(const Duration(seconds: 1)))) {
            spent += amount;
          }
        } else if (_selectedBudgetInterval == 'Monthly') {
          if (date.year == now.year && date.month == now.month) {
            spent += amount;
          }
        } else if (_selectedBudgetInterval == 'Yearly') {
          if (date.year == now.year) {
            spent += amount;
          }
        }
      }

      setState(() {
        _totalSpent = spent;
        _isLoading = false;
      });

      double thresholdAmount = _budgetLimit * (_warningThresholdPercentage / 100.0);
      if (_totalSpent > _budgetLimit) {
        NotificationService.showBudgetNotification(
          id: 1,
          title: '🚨 Budget Exceeded!',
          body: 'You have spent \$${_totalSpent.toStringAsFixed(2)}, exceeding your $_selectedBudgetInterval budget limit of \$${_budgetLimit.toStringAsFixed(2)}.',
        );
      } else if (_totalSpent >= thresholdAmount && _totalSpent > 0) {
        NotificationService.showBudgetNotification(
          id: 2,
          title: '⚠️ Budget Threshold Reached',
          body: 'You have spent $_warningThresholdPercentage% of your $_selectedBudgetInterval budget (\$${_totalSpent.toStringAsFixed(2)} spent of \$${_budgetLimit.toStringAsFixed(2)}).',
        );
      }
    } catch (e, stack) {
      debugPrint('Error loading budget: $e\n$stack');
      setState(() => _isLoading = false);
    }
  }

  void _showSetBudgetDialog() {
    _budgetController.text = _budgetLimit.toStringAsFixed(0);
    int tempThreshold = _warningThresholdPercentage;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            'Configure $_selectedBudgetInterval Budget',
            style: ThemeService.getAppTextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _budgetController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: ThemeService.getAppTextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    labelText: 'Budget Limit (\$)',
                    labelStyle: ThemeService.getAppTextStyle(fontSize: 16),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Warning Threshold:', style: ThemeService.getAppTextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [25, 50, 75, 90].map((pct) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                          label: Text('$pct%', style: ThemeService.getAppTextStyle(fontSize: 14)),
                          selected: tempThreshold == pct,
                          onSelected: (selected) {
                            setDialogState(() {
                              tempThreshold = pct;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: ThemeService.getAppTextStyle(fontSize: 16)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC6C7)),
              onPressed: () async {
                final newLimit = double.tryParse(_budgetController.text);
                if (newLimit != null && newLimit > 0) {
                  try {
                    await DatabaseHelper.instance.saveOrUpdateBudget(
                      _selectedBudgetInterval,
                      newLimit,
                      tempThreshold,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$_selectedBudgetInterval budget updated!')),
                      );
                    }
                  } catch (e) {
                    debugPrint('Error saving budget: $e');
                  }
                }
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                await _loadBudgetFromDatabase();
              },
              child: Text('Save', style: ThemeService.getAppTextStyle(fontSize: 16, color: Colors.black)),
            ),
          ],
        ),
      ),
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

        double progress = _budgetLimit > 0 ? (_totalSpent / _budgetLimit).clamp(0.0, 1.0) : 0.0;
        double thresholdAmount = _budgetLimit * (_warningThresholdPercentage / 100.0);
        bool isOverBudget = _totalSpent > _budgetLimit;
        bool isThresholdCrossed = _totalSpent >= thresholdAmount;

        Color cardColor = isDark
            ? (currentTheme == AppThemeOption.cyberpunk2077
            ? const Color(0xFF1C050C)
            : (currentTheme == AppThemeOption.edgerunners
            ? const Color(0xFF16162A)
            : const Color(0xFF282836)))
            : const Color(0xFFD0F4DE);

        if (isOverBudget) {
          cardColor = isDark ? const Color(0xFF3D1F24) : Colors.red.shade50;
        } else if (isThresholdCrossed) {
          cardColor = isDark ? const Color(0xFF3D321F) : Colors.amber.shade50;
        }

        final cardTextColor = ThemeService.getTextColorForBackground(cardColor);
        final secondaryTextColor = ThemeService.getSecondaryTextColorForBackground(cardColor);

        return Scaffold(
          body: SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
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
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Budget Management',
                      style: ThemeService.getAppTextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: ThemeService.getTextColorForBackground(headerPillColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Interval Selector Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text(
                        'Budget Type: ',
                        style: ThemeService.getAppTextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      for (var interval in ['Weekly', 'Monthly', 'Yearly']) ...[
                        ChoiceChip(
                          label: Text(
                            interval,
                            style: ThemeService.getAppTextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _selectedBudgetInterval == interval
                                  ? Colors.black
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                          selected: _selectedBudgetInterval == interval,
                          selectedColor: currentTheme == AppThemeOption.cyberpunk2077
                              ? const Color(0xFFFF003C)
                              : (currentTheme == AppThemeOption.edgerunners
                              ? const Color(0xFF00F0FF)
                              : const Color(0xFFD0F4DE)),
                          onSelected: (selected) async {
                            if (!selected) return;
                            setState(() => _selectedBudgetInterval = interval);
                            await _loadBudgetFromDatabase();
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Main Budget Overview Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '$_selectedBudgetInterval Budget Limit ($_warningThresholdPercentage% Alert)',
                              style: ThemeService.getAppTextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: secondaryTextColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit, size: 22, color: cardTextColor),
                            onPressed: _showSetBudgetDialog,
                            tooltip: 'Edit Budget & Threshold',
                          ),
                        ],
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '\$${_budgetLimit.toStringAsFixed(2)}',
                          style: ThemeService.getAppTextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: cardTextColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Spent: -\$${_totalSpent.toStringAsFixed(2)}',
                            style: ThemeService.getAppTextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isOverBudget ? Colors.redAccent : cardTextColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Remaining: \$${(_budgetLimit - _totalSpent).toStringAsFixed(2)}',
                            style: ThemeService.getAppTextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: cardTextColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                          color: isOverBudget
                              ? Colors.redAccent
                              : (isThresholdCrossed ? Colors.orange : Colors.green),
                          minHeight: 12,
                        ),
                      ),
                      if (isOverBudget) ...[
                        const SizedBox(height: 12),
                        Text(
                          '⚠️ You have exceeded your budget limit for this period!',
                          style: ThemeService.getAppTextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ] else if (isThresholdCrossed) ...[
                        const SizedBox(height: 12),
                        Text(
                          '⚠️ $_warningThresholdPercentage% of your budget has been spent!',
                          style: ThemeService.getAppTextStyle(
                            color: isDark ? Colors.amberAccent : Colors.orange[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // 4. Tips Section Title
                Text(
                  'Tips for Budgeting',
                  style: ThemeService.getAppTextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 10),

                // 5. Tips Bounding Box Card
                Container(
                  padding: const EdgeInsets.all(18.0),
                  decoration: BoxDecoration(
                    color: isDark
                        ? (currentTheme == AppThemeOption.cyberpunk2077
                        ? const Color(0xFF1A040A)
                        : (currentTheme == AppThemeOption.edgerunners
                        ? const Color(0xFF1F1F35)
                        : const Color(0xFF222230)))
                        : const Color(0xFFFFF3BF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor, width: 2.0),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
                        offset: const Offset(3, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    '• Budgets are stored securely in your local SQLite database table.\n• Each interval maintains its own independent limit and warning threshold.',
                    style: ThemeService.getAppTextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
