import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({Key? key}) : super(key: key);

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  var _transactions = [];
  var _categories = [];
  bool _isLoading = true;

  // Search and filter states
  final TextEditingController _searchController = TextEditingController();
  String _selectedType = 'All'; // 'All', 'Expense', 'Income'
  int _selectedCategoryId = 0;   // 0 means 'All Categories'

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
      type: _selectedType,
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
      type: _selectedType,
      categoryId: _selectedCategoryId,
    );

    setState(() {
      _transactions = data;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        backgroundColor: const Color(0xFFFFC6C7),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export & Share Backup (CSV)',
            onPressed: () async {
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
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Header Container
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                // Search TextField
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search merchant or notes...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _loadTransactions();
                      },
                    )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) => _loadTransactions(),
                ),
                const SizedBox(height: 8),

                // Type Filter Chips (All / Expense / Income)
                Row(
                  children: [
                    const Text('Type: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _selectedType == 'All',
                      onSelected: (selected) {
                        setState(() => _selectedType = 'All');
                        _loadTransactions();
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Expense'),
                      selected: _selectedType == 'Expense',
                      onSelected: (selected) {
                        setState(() => _selectedType = 'Expense');
                        _loadTransactions();
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Income'),
                      selected: _selectedType == 'Income',
                      onSelected: (selected) {
                        setState(() => _selectedType = 'Income');
                        _loadTransactions();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Horizontal Scrollable Category Filter Chips
                SizedBox(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: const Text('All Categories'),
                          selected: _selectedCategoryId == 0,
                          onSelected: (selected) {
                            setState(() => _selectedCategoryId = 0);
                            _loadTransactions();
                          },
                        ),
                      ),
                      ..._categories.map((cat) {
                        // Use 'category_id' and 'category_name' here too
                        final catId = (cat['category_id'] as num?)?.toInt() ?? 0;
                        final catName = (cat['category_name'] as String?) ?? 'General';
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(catName),
                            selected: _selectedCategoryId == catId,
                            onSelected: (selected) {
                              setState(() => _selectedCategoryId = catId);
                              _loadTransactions();
                            },
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Transaction List View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                ? const Center(child: Text('No transactions found.'))
                : ListView.builder(
              itemCount: _transactions.length,
              itemBuilder: (context, index) {
                final tx = _transactions[index];
                final isExpense = tx['type'] == 'Expense';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isExpense ? Colors.red[100] : Colors.green[100],
                    child: Icon(
                      isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isExpense ? Colors.red : Colors.green,
                    ),
                  ),
                  title: Text(tx['merchant'] ?? 'Unknown Merchant'),
                  subtitle: Text('${tx['date']} • ${tx['notes'] ?? ''}'),
                  trailing: Text(
                    '${isExpense ? '-' : '+'}\$${tx['amount']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isExpense ? Colors.red : Colors.green,
                      fontSize: 16,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}