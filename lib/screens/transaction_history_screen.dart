import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import '../services/theme_service.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  int _selectedCategoryId = 0;            // 0 means 'All Categories'
  String _selectedInterval = 'All';       // 'All', 'Weekly', 'Monthly', 'Yearly'

  // Multi-selection state
  bool _isSelectionMode = false;
  final Set<int> _selectedTxIds = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    final categoriesData = await DatabaseHelper.instance.getCategories();
    final transactionsData = await DatabaseHelper.instance.getFilteredTransactions(
      query: _searchController.text,
      categoryId: _selectedCategoryId,
    );

    setState(() {
      _categories = categoriesData;
      _transactions = transactionsData;
      _isLoading = false;
    });
  }

  Future<void> _loadTransactions() async {
    final data = await DatabaseHelper.instance.getFilteredTransactions(
      query: _searchController.text,
      categoryId: _selectedCategoryId,
    );

    setState(() {
      _transactions = data;
    });
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  Map<String, List<Map<String, dynamic>>> _groupTransactions() {
    Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var tx in _transactions) {
      final dateStr = tx['date'] as String? ?? DateTime.now().toIso8601String();
      final date = DateTime.tryParse(dateStr) ?? DateTime.now();

      String key = 'All Transactions';

      if (_selectedInterval == 'Weekly') {
        int weekNum = ((date.day - 1) ~/ 7) + 1;
        key = 'Week $weekNum, ${_getMonthName(date.month)} ${date.year}';
      } else if (_selectedInterval == 'Monthly') {
        key = '${_getMonthName(date.month)} ${date.year}';
      } else if (_selectedInterval == 'Yearly') {
        key = '${date.year}';
      }

      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(tx);
    }

    return grouped;
  }

  void _toggleSelection(int txId) {
    setState(() {
      if (_selectedTxIds.contains(txId)) {
        _selectedTxIds.remove(txId);
        if (_selectedTxIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedTxIds.add(txId);
      }
    });
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

  Future<void> _deleteSelectedTransactions() async {
    if (_selectedTxIds.isEmpty) return;

    final confirmed = await _showDeleteConfirmationDialog(
      title: 'Delete Selected Expenses?',
      content: 'Are you sure you want to delete ${_selectedTxIds.length} selected expense(s)? This action cannot be undone.',
    );

    if (confirmed) {
      await DatabaseHelper.instance.deleteMultipleTransactions(_selectedTxIds.toList());
      setState(() {
        _selectedTxIds.clear();
        _isSelectionMode = false;
      });
      await _loadTransactions();
    }
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
                        await _loadTransactions();
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
                    await _loadTransactions();
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

        final groupedTransactions = _groupTransactions();
        final groupKeys = groupedTransactions.keys.toList();

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // 1. Top Pill Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
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
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _isSelectionMode ? Icons.close : Icons.arrow_back,
                                color: ThemeService.getTextColorForBackground(headerPillColor),
                                size: 26,
                              ),
                              onPressed: () {
                                if (_isSelectionMode) {
                                  setState(() {
                                    _isSelectionMode = false;
                                    _selectedTxIds.clear();
                                  });
                                } else {
                                  Navigator.pop(context);
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isSelectionMode
                                  ? '${_selectedTxIds.length} Selected'
                                  : 'Transaction History',
                              style: ThemeService.getAppTextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: ThemeService.getTextColorForBackground(headerPillColor),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (_isSelectionMode && _selectedTxIds.isNotEmpty)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_forever,
                                  color: Colors.redAccent,
                                  size: 28,
                                ),
                                tooltip: 'Delete Selected',
                                onPressed: _deleteSelectedTransactions,
                              )
                            else if (!_isSelectionMode) ...[
                              IconButton(
                                icon: Icon(
                                  Icons.download,
                                  color: ThemeService.getTextColorForBackground(headerPillColor),
                                  size: 26,
                                ),
                                tooltip: 'Export CSV',
                                onPressed: () async {
                                  try {
                                    String filePath =
                                    await DatabaseHelper.instance.exportTransactionsToCSV();
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
                              ),
                              PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert,
                                  color: ThemeService.getTextColorForBackground(headerPillColor),
                                ),
                                onSelected: (value) {
                                  if (value == 'select') {
                                    setState(() {
                                      _isSelectionMode = true;
                                    });
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'select',
                                    child: Text(
                                      'Select',
                                      style: ThemeService.getAppTextStyle(fontSize: 18),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Search & Filter Bounding Box Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? (currentTheme == AppThemeOption.cyberpunk2077
                          ? const Color(0xFF1C050C)
                          : const Color(0xFF1E1E2C))
                          : Colors.white,
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
                    child: Column(
                      children: [
                        // Search Field
                        TextField(
                          controller: _searchController,
                          style: ThemeService.getAppTextStyle(
                            fontSize: 20,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search merchant or notes...',
                            hintStyle: ThemeService.getAppTextStyle(
                              fontSize: 19,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                            prefixIcon: Icon(Icons.search, color: isDark ? Colors.white70 : Colors.black87),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                              icon: Icon(Icons.clear, color: isDark ? Colors.white70 : Colors.black87),
                              onPressed: () {
                                _searchController.clear();
                                _loadTransactions();
                              },
                            )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: borderColor, width: 1.5),
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF12121E) : const Color(0xFFF7F9FC),
                            isDense: true,
                          ),
                          onChanged: (value) => _loadTransactions(),
                        ),
                        const SizedBox(height: 10),

                        // Interval Filter Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Text(
                                'Interval: ',
                                style: ThemeService.getAppTextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(width: 8),
                              for (var interval in ['All', 'Weekly', 'Monthly', 'Yearly']) ...[
                                ChoiceChip(
                                  label: Text(
                                    interval,
                                    style: ThemeService.getAppTextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedInterval == interval
                                          ? Colors.black
                                          : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                  selected: _selectedInterval == interval,
                                  selectedColor: currentTheme == AppThemeOption.cyberpunk2077
                                      ? const Color(0xFFFF003C)
                                      : (currentTheme == AppThemeOption.edgerunners
                                      ? const Color(0xFF00F0FF)
                                      : const Color(0xFFD0F4DE)),
                                  onSelected: (selected) {
                                    setState(() => _selectedInterval = interval);
                                  },
                                ),
                                const SizedBox(width: 6),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Category Chips
                        SizedBox(
                          height: 44,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: Text(
                                    'All Categories',
                                    style: ThemeService.getAppTextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedCategoryId == 0
                                          ? Colors.black
                                          : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                  selected: _selectedCategoryId == 0,
                                  selectedColor: currentTheme == AppThemeOption.cyberpunk2077
                                      ? const Color(0xFFFF003C)
                                      : (currentTheme == AppThemeOption.edgerunners
                                      ? const Color(0xFFFEE715)
                                      : const Color(0xFFFFC6C7)),
                                  onSelected: (selected) {
                                    setState(() => _selectedCategoryId = 0);
                                    _loadTransactions();
                                  },
                                ),
                              ),
                              ..._categories.map((cat) {
                                final catId = (cat['category_id'] as num?)?.toInt() ?? 0;
                                final catName = (cat['category_name'] as String?) ?? 'General';
                                final isSelected = _selectedCategoryId == catId;

                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ChoiceChip(
                                    label: Text(
                                      catName,
                                      style: ThemeService.getAppTextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.black
                                            : (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                    ),
                                    selected: isSelected,
                                    selectedColor: currentTheme == AppThemeOption.cyberpunk2077
                                        ? const Color(0xFFFF003C)
                                        : (currentTheme == AppThemeOption.edgerunners
                                        ? const Color(0xFFFEE715)
                                        : const Color(0xFFFFC6C7)),
                                    onSelected: (selected) {
                                      setState(() => _selectedCategoryId = catId);
                                      _loadTransactions();
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Grouped Transaction List
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _transactions.isEmpty
                      ? Center(
                    child: Text(
                      'No transactions found.',
                      style: ThemeService.getAppTextStyle(
                        fontSize: 22,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: groupKeys.length,
                    itemBuilder: (context, groupIndex) {
                      final groupKey = groupKeys[groupIndex];
                      final groupItems = groupedTransactions[groupKey]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_selectedInterval != 'All')
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                groupKey,
                                style: ThemeService.getAppTextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: isDark ? const Color(0xFF00F0FF) : Colors.black87,
                                ),
                              ),
                            ),

                          ...groupItems.map((tx) {
                            final int txId = (tx['transaction_id'] as num?)?.toInt() ?? 0;
                            final isItemSelected = _selectedTxIds.contains(txId);

                            final itemBgColor = isDark
                                ? (currentTheme == AppThemeOption.cyberpunk2077
                                ? const Color(0xFF260510)
                                : (currentTheme == AppThemeOption.edgerunners
                                ? const Color(0xFF12121E)
                                : const Color(0xFF2B2B3D)))
                                : Colors.white;

                            final itemTextColor = ThemeService.getTextColorForBackground(itemBgColor);
                            final itemSubTextColor = ThemeService.getSecondaryTextColorForBackground(itemBgColor);
                            final merchant = tx['merchant'] ?? 'Unknown Merchant';
                            final dateStr = tx['date'] != null ? tx['date'].toString().split('T')[0] : '';
                            final notes = tx['notes'] ?? '';
                            final amount = tx['amount'];

                            return InkWell(
                              onTap: () {
                                if (_isSelectionMode) {
                                  _toggleSelection(txId);
                                }
                              },
                              onLongPress: () {
                                if (!_isSelectionMode) {
                                  _showTransactionContextMenu(tx);
                                }
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isItemSelected
                                      ? (isDark ? const Color(0xFF38233C) : const Color(0xFFFFE0E0))
                                      : itemBgColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isItemSelected ? Colors.pinkAccent : borderColor,
                                    width: isItemSelected ? 2.2 : 1.8,
                                  ),
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
                                    if (_isSelectionMode)
                                      Checkbox(
                                        value: isItemSelected,
                                        activeColor: Colors.pinkAccent,
                                        onChanged: (_) => _toggleSelection(txId),
                                      )
                                    else
                                      CircleAvatar(
                                        backgroundColor: const Color(0xFFFFC6C7),
                                        radius: 20,
                                        child: const Icon(Icons.arrow_downward, color: Colors.black, size: 22),
                                      ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            merchant,
                                            style: ThemeService.getAppTextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: itemTextColor,
                                            ),
                                          ),
                                          Text(
                                            '$dateStr${notes.isNotEmpty ? ' • $notes' : ''}',
                                            style: ThemeService.getAppTextStyle(
                                              fontSize: 16,
                                              color: itemSubTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '-\$$amount',
                                      style: ThemeService.getAppTextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: currentTheme == AppThemeOption.cyberpunk2077 ||
                                            currentTheme == AppThemeOption.edgerunners
                                            ? const Color(0xFFFF0055)
                                            : Colors.redAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
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
