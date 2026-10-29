import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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
      version: 1,
      onConfigure: _onConfigure,
      onCreate: _createDB,
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _createDB(Database db, int version) async {
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
        FOREIGN KEY (category_id) REFERENCES categories (category_id)
          ON DELETE SET NULL
      )
    ''');

    // 3. Budgets Constraint Table (3NF Foreign Key to categories)
    await db.execute('''
      CREATE TABLE budgets (
        budget_id INTEGER PRIMARY KEY AUTOINCREMENT,
        monthly_limit_amount REAL NOT NULL,
        category_id INTEGER,
        FOREIGN KEY (category_id) REFERENCES categories (category_id)
          ON DELETE CASCADE
      )
    ''');

    // Insert some default categories to start with
    await db.insert('categories', {'category_name': 'Food & Dining', 'icon': 'fastfood', 'color_tag': '#FFC6C7'});
    await db.insert('categories', {'category_name': 'Transport', 'icon': 'directions_car', 'color_tag': '#BCE6FF'});
    await db.insert('categories', {'category_name': 'Utilities', 'icon': 'bolt', 'color_tag': '#D0F4DE'});
    await db.insert('categories', {'category_name': 'Income', 'icon': 'work', 'color_tag': '#E8A87C'});
  }

  // --- CRUD METHODS FOR TRANSACTIONS ---

  // Insert a transaction
  Future<int> insertTransaction(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('transactions', row);
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

    // Let Dart infer the type automatically—no brackets needed!
    final maps = await db.query('transactions');

    // Build CSV content header
    List<String> rows = [
      'ID,Amount,Type,Date,Merchant,Notes,CategoryID'
    ];

    // Loop through rows and format as CSV text
    for (var row in maps) {
      rows.add(
          '${row['id']},${row['amount']},${row['type']},${row['date']},'
              '"${row['merchant'] ?? ''}","${row['notes'] ?? ''}",${row['category_id']}'
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

  Future<List> getFilteredTransactions({
    String? query,
    String? type,
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

    // Filter by type (e.g., 'Expense' or 'Income')
    if (type != null && type != 'All') {
      conditions.add("type = ?");
      whereArgs.add(type);
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

  // 2. Helper to fetch all categories for the filter row
  Future<List> getCategories() async {
    final db = await database;
    return await db.query('categories');
  }
}
