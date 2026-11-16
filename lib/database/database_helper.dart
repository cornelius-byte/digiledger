import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('expense_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final fullPath = join(dbPath, filePath);

    return await openDatabase(
      fullPath,
      version: 4,
      onConfigure: _onConfigure,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        // Migration safeguard: check if budgets table exists and has the new interval_type column
        try {
          var tableInfo = await db.rawQuery("PRAGMA table_info(budgets)");
          bool hasIntervalType = tableInfo.any((column) => column['name'] == 'interval_type');
          if (tableInfo.isNotEmpty && !hasIntervalType) {
            await db.execute('DROP TABLE IF EXISTS budgets');
          }
        } catch (_) {}

        // Safeguard: check if transactions table has transaction_name column
        try {
          var txTableInfo = await db.rawQuery("PRAGMA table_info(transactions)");
          bool hasTxName = txTableInfo.any((column) => column['name'] == 'transaction_name');
          if (txTableInfo.isNotEmpty && !hasTxName) {
            await db.execute('ALTER TABLE transactions ADD COLUMN transaction_name TEXT');
          }
        } catch (_) {}

        await db.execute('''
          CREATE TABLE IF NOT EXISTS budgets (
            budget_id INTEGER PRIMARY KEY AUTOINCREMENT,
            interval_type TEXT UNIQUE NOT NULL,
            amount REAL NOT NULL,
            threshold_percentage INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Categories Master Table
    await db.execute('''
      CREATE TABLE categories (
        category_id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_name TEXT NOT NULL UNIQUE,
        icon TEXT,
        color_tag TEXT
      )
    ''');

    // 2. Transactions Operational Table (3NF Foreign Key to categories)
    await db.execute('''
      CREATE TABLE transactions (
        transaction_id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        merchant TEXT,
        notes TEXT,
        receipt_image_path TEXT,
        category_id INTEGER,
        transaction_name TEXT,
        FOREIGN KEY (category_id) REFERENCES categories (category_id)
          ON DELETE SET NULL
      )
    ''');

    // 3. Budgets Constraint Table
    await db.execute('''
      CREATE TABLE budgets (
        budget_id INTEGER PRIMARY KEY AUTOINCREMENT,
        interval_type TEXT UNIQUE NOT NULL,
        amount REAL NOT NULL,
        threshold_percentage INTEGER NOT NULL
      )
    ''');

    // 4. Settings Key-Value Table for Persistence
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Insert default categories
    await db.insert('categories', {'category_name': 'Food', 'icon': 'fastfood', 'color_tag': '#FFC6C7'});
    await db.insert('categories', {'category_name': 'Transport', 'icon': 'directions_car', 'color_tag': '#BCE6FF'});
    await db.insert('categories', {'category_name': 'Stationery', 'icon': 'edit', 'color_tag': '#D0F4DE'});
    await db.insert('categories', {'category_name': 'Clothes', 'icon': 'checkroom', 'color_tag': '#E8A87C'});
    await db.insert('categories', {'category_name': 'Electronics', 'icon': 'devices', 'color_tag': '#FFF3BF'});
    await db.insert('categories', {'category_name': 'Health', 'icon': 'medical_services', 'color_tag': '#FFC6C7'});
    await db.insert('categories', {'category_name': 'Groceries', 'icon': 'shopping_cart', 'color_tag': '#BCE6FF'});
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('DROP TABLE IF EXISTS budgets');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS budgets (
          budget_id INTEGER PRIMARY KEY AUTOINCREMENT,
          interval_type TEXT UNIQUE NOT NULL,
          amount REAL NOT NULL,
          threshold_percentage INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      try {
        var txTableInfo = await db.rawQuery("PRAGMA table_info(transactions)");
        bool hasTxName = txTableInfo.any((column) => column['name'] == 'transaction_name');
        if (txTableInfo.isNotEmpty && !hasTxName) {
          await db.execute('ALTER TABLE transactions ADD COLUMN transaction_name TEXT');
        }
      } catch (_) {}
    }
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // --- SETTINGS PREFERENCES & BUDGET INTERVAL ---
  static final ValueNotifier<String> activeBudgetInterval = ValueNotifier<String>('Monthly');

  /// Checks whether a given transaction date falls within the specified budget interval period (Weekly, Monthly, Yearly).
  static bool isDateInBudgetInterval(DateTime date, String interval, {DateTime? refDate}) {
    final now = refDate ?? DateTime.now();

    DateTime startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

    if (interval == 'Weekly') {
      int daysSinceSunday = now.weekday % 7;
      DateTime startOfWeek = startOfDay(now).subtract(Duration(days: daysSinceSunday));
      DateTime endOfWeek = startOfWeek.add(const Duration(days: 7));
      DateTime txDateOnly = startOfDay(date);
      return !txDateOnly.isBefore(startOfWeek) && txDateOnly.isBefore(endOfWeek);
    } else if (interval == 'Yearly') {
      return date.year == now.year;
    } else {
      // Default: 'Monthly'
      return date.year == now.year && date.month == now.month;
    }
  }

  /// Initializes active budget interval notifier from database settings.
  Future<void> initActiveBudgetInterval() async {
    final saved = await getSetting('active_budget_interval');
    if (saved != null && ['Weekly', 'Monthly', 'Yearly'].contains(saved)) {
      activeBudgetInterval.value = saved;
    } else {
      activeBudgetInterval.value = 'Monthly';
    }
  }

  /// Updates active budget interval in setting and triggers listeners.
  Future<void> setActiveBudgetInterval(String interval) async {
    await saveSetting('active_budget_interval', interval);
    activeBudgetInterval.value = interval;
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final results = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (results.isNotEmpty) {
      return results.first['value'] as String?;
    }
    return null;
  }

  // --- CRUD METHODS FOR TRANSACTIONS ---

  // Insert a transaction
  Future<int> insertTransaction(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('transactions', row);
  }

  // Update transaction amount, merchant, transaction_name, notes, and optional category_id
  Future<int> updateTransaction(
    int id,
    double amount,
    String merchant,
    String transactionName,
    String notes, {
    int? categoryId,
  }) async {
    final db = await database;
    final Map<String, dynamic> row = {
      'amount': amount,
      'merchant': merchant,
      'transaction_name': transactionName,
      'notes': notes,
    };
    if (categoryId != null) {
      row['category_id'] = categoryId;
    }
    return await db.update(
      'transactions',
      row,
      where: 'transaction_id = ?',
      whereArgs: [id],
    );
  }

  // Check if a transaction is already recorded (prevents duplicate imports from SMS)
  // When referenceId (Refno) is present, uniqueness is strictly determined by Refno to allow multiple valid payments on the same date/amount.
  Future<bool> isTransactionDuplicate({
    required double amount,
    required String date,
    required String merchant,
    String? referenceId,
  }) async {
    final db = await database;
    if (referenceId != null && referenceId.trim().isNotEmpty) {
      final refCheck = await db.query(
        'transactions',
        where: 'notes LIKE ?',
        whereArgs: ['%${referenceId.trim()}%'],
      );
      if (refCheck.isNotEmpty) return true;
      return false;
    }

    final existing = await db.query(
      'transactions',
      where: 'amount = ? AND date = ? AND merchant = ?',
      whereArgs: [amount, date, merchant],
    );
    return existing.isNotEmpty;
  }

  // Delete single transaction
  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete(
      'transactions',
      where: 'transaction_id = ?',
      whereArgs: [id],
    );
  }

  // Delete multiple transactions simultaneously
  Future<int> deleteMultipleTransactions(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    return await db.delete(
      'transactions',
      where: 'transaction_id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  // Get all transactions
  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    final db = await instance.database;
    return await db.query('transactions', orderBy: 'date DESC');
  }

  // Get total spent in current month for budget calculations
  Future<double> getMonthlySpending() async {
    final db = await instance.database;
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1).toIso8601String();

    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE type = "Expense" AND date >= ?',
      [firstDayOfMonth],
    );

    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  // Close database
  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }

  Future<String> exportTransactionsToCSV() async {
    final db = await database;

    final maps = await db.query('transactions');

    // Build CSV content header
    List<String> rows = [
      'ID,Amount,Type,Date,Merchant,Notes,CategoryID,TransactionName'
    ];

    // Loop through rows and format as CSV text
    for (var row in maps) {
      rows.add(
        '${row['transaction_id']},${row['amount']},${row['type']},${row['date']},'
        '"${row['merchant'] ?? ''}","${row['notes'] ?? ''}",${row['category_id']},'
        '"${row['transaction_name'] ?? ''}"'
      );
    }

    String csvContent = rows.join('\n');

    // Save to temporary directory for system sharing
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/digiledger_backup_${DateTime.now().millisecondsSinceEpoch}.csv';

    final file = File(path);
    await file.writeAsString(csvContent);

    return path;
  }

  Future<int> importTransactionsFromCSV(String csvContent) async {
    final db = await database;
    final lines = csvContent.split('\n');
    int importedCount = 0;

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = line.split(',');
      if (parts.length >= 4) {
        try {
          final amount = double.tryParse(parts[1]) ?? 0.0;
          final type = parts[2];
          final date = parts[3];
          final merchant = parts.length > 4 ? parts[4].replaceAll('"', '') : '';
          final notes = parts.length > 5 ? parts[5].replaceAll('"', '') : '';
          final categoryId = parts.length > 6 ? int.tryParse(parts[6]) : null;
          final transactionName = parts.length > 7 ? parts[7].replaceAll('"', '') : '';

          await db.insert('transactions', {
            'amount': amount,
            'type': type,
            'date': date,
            'merchant': merchant,
            'notes': notes,
            'category_id': categoryId,
            'transaction_name': transactionName,
          });
          importedCount++;
        } catch (_) {}
      }
    }
    return importedCount;
  }

  Future<List<Map<String, dynamic>>> getFilteredTransactions({
    String? query,
    int? categoryId,
  }) async {
    final db = await database;

    List<String> conditions = [];
    List<Object?> whereArgs = [];

    // Search by merchant name or notes keyword
    if (query != null && query.trim().isNotEmpty) {
      conditions.add("(merchant LIKE ? OR notes LIKE ?)");
      whereArgs.add('%${query.trim()}%');
      whereArgs.add('%${query.trim()}%');
    }

    // Filter by category if a specific category is selected (non-zero)
    if (categoryId != null && categoryId != 0) {
      conditions.add("category_id = ?");
      whereArgs.add(categoryId);
    }

    String? whereClause = conditions.isNotEmpty ? conditions.join(' AND ') : null;

    final maps = await db.query(
      'transactions',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'date DESC',
    );

    return maps;
  }

  // Helper to fetch all categories for the filter row
  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return await db.query('categories');
  }

  Future<int> insertCategory(String categoryName, {String icon = 'label', String colorTag = '#D0F4DE'}) async {
    final db = await database;
    return await db.insert('categories', {
      'category_name': categoryName,
      'icon': icon,
      'color_tag': colorTag,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> deleteCategory(int categoryId) async {
    final db = await database;
    return await db.delete(
      'categories',
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );
  }

  // Save or update a budget for a given interval ('Weekly', 'Monthly', 'Yearly')
  Future<void> saveOrUpdateBudget(String interval, double amount, int threshold) async {
    final db = await database;
    await db.insert(
      'budgets',
      {
        'interval_type': interval,
        'amount': amount,
        'threshold_percentage': threshold,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Retrieve budget details for a specific interval
  Future<Map<String, dynamic>?> getBudget(String interval) async {
    final db = await database;
    final results = await db.query(
      'budgets',
      where: 'interval_type = ?',
      whereArgs: [interval],
    );
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }
}
