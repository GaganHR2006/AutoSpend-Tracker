import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'database.g.dart';

enum TransactionType { income, expense }

// Lending type enum
enum LendingType { none, lent, returned }

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get smsId => text().unique()();
  RealColumn get amount => real()();
  TextColumn get merchant => text().nullable()();
  TextColumn get category => text().withDefault(const Constant('Uncategorized'))();
  IntColumn get type => intEnum<TransactionType>()();
  DateTimeColumn get timestamp => dateTime()();
  BoolColumn get isManual => boolean()();
  
  // ⭐ Lending Tracker fields
  BoolColumn get isLending => boolean().withDefault(const Constant(false))();
  IntColumn get lendingType => intEnum<LendingType>().withDefault(const Constant(0))();
  IntColumn get linkedLendingId => integer().nullable()();
}

// Budget table for tracking spending limits
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get category => text()(); // e.g., "Food", "TOTAL_MONTHLY", "CREDIT_CARD"
  RealColumn get limitAmount => real()();
  IntColumn get alertThreshold => integer().withDefault(const Constant(80))(); // Percentage (0-100)
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Transactions, Budgets])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3; // ⭐ Bumped for budgets table

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Add lending columns for existing databases
          await m.addColumn(transactions, transactions.isLending);
          await m.addColumn(transactions, transactions.lendingType);
          await m.addColumn(transactions, transactions.linkedLendingId);
        }
        if (from < 3) {
          // Add budgets table
          await m.createTable(budgets);
        }
      },
    );
  }

  Stream<List<Transaction>> watchAllTransactions() {
    return (select(transactions)
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
      .watch();
  }

  Stream<double> watchBalance() {
    // Custom query to subtract expense from income, EXCLUDING lending transactions
    return customSelect(
      '''SELECT (
        COALESCE((SELECT SUM(amount) FROM transactions WHERE type = 0 AND is_lending = 0), 0) - 
        COALESCE((SELECT SUM(amount) FROM transactions WHERE type = 1 AND is_lending = 0), 0)
      ) AS balance,
      COALESCE((SELECT SUM(amount) FROM transactions WHERE type = 0 AND is_lending = 0), 0) AS total_income,
      COALESCE((SELECT SUM(amount) FROM transactions WHERE type = 1 AND is_lending = 0), 0) AS total_expense,
      (SELECT COUNT(*) FROM transactions) AS tx_count
      ''',
      readsFrom: {transactions}
    ).watch().map((rows) {
      if (rows.isEmpty) return 0.0;
      
      final balance = rows.first.read<double>('balance');
      return balance;
    });
  }

  // ⭐ Watch lending summary (total lent, total returned)
  Stream<Map<String, double>> watchLendingSummary() {
    return customSelect(
      '''SELECT 
        COALESCE((SELECT SUM(amount) FROM transactions WHERE lending_type = 1), 0) AS lent,
        COALESCE((SELECT SUM(amount) FROM transactions WHERE lending_type = 2), 0) AS returned
      ''',
      readsFrom: {transactions}
    ).watch().map((rows) {
      if (rows.isEmpty) return {'lent': 0.0, 'returned': 0.0};
      return {
        'lent': rows.first.read<double>('lent'),
        'returned': rows.first.read<double>('returned'),
      };
    });
  }

  /// Check if a similar transaction already exists (fuzzy duplicate detection)
  /// Returns true if a transaction with matching amount, type, merchant, and timestamp (±5 minutes) exists
  /// 
  /// Why 5 minutes? SMS can be delayed due to:
  /// - Network congestion
  /// - Poor signal strength  
  /// - Carrier processing delays
  /// - Notification delivery lag
  /// 
  /// ✅ CRITICAL: Now includes merchant name to avoid blocking different transactions with same amount
  Future<bool> isDuplicateTransaction({
    required double amount,
    required TransactionType type,
    required DateTime timestamp,
    String? merchant,  // ✅ Added merchant parameter
  }) async {
    // Define time window (±5 minutes = ±300 seconds)
    final startWindow = timestamp.subtract(const Duration(minutes: 5));
    final endWindow = timestamp.add(const Duration(minutes: 5));
    
    // Query for transactions with matching amount, type, merchant within time window
    // ✅ CRITICAL: Merchant matching prevents false duplicates (e.g., two ₹1 payments from different people)
    final query = select(transactions)
      ..where((t) {
        var condition = t.amount.equals(amount) & 
                        t.type.equalsValue(type) &
                        t.timestamp.isBiggerOrEqualValue(startWindow) &
                        t.timestamp.isSmallerOrEqualValue(endWindow);
        
        // ✅ Add merchant matching if merchant name provided
        if (merchant != null && merchant.isNotEmpty) {
          condition = condition & t.merchant.equals(merchant);
        }
        
        return condition;
      });
    
    final results = await query.get();
    return results.isNotEmpty;
  }

  /// Watch the total transaction count (for debugging)
  Stream<int> watchTransactionCount() {
    final query = selectOnly(transactions)..addColumns([transactions.id.count()]);
    return query.map((row) => row.read(transactions.id.count()) ?? 0).watchSingle();
  }

  // ⭐ Clear all transactions before new scan
  Future<void> clearAllTransactions() async {
    await delete(transactions).go();
  }

  // ================== BUDGET METHODS ==================

  /// Watch all active budgets
  Stream<List<Budget>> watchBudgets() {
    return (select(budgets)..where((b) => b.isActive.equals(true))).watch();
  }

  /// Get all budgets (including inactive)
  Future<List<Budget>> getAllBudgets() async {
    return select(budgets).get();
  }

  /// Get budget for specific category
  Future<Budget?> getBudgetForCategory(String category) async {
    final query = select(budgets)..where((b) => b.category.equals(category) & b.isActive.equals(true));
    final results = await query.get();
    return results.isEmpty ? null : results.first;
  }

  /// Insert a new budget
  Future<int> insertBudget(BudgetsCompanion budget) async {
    return await into(budgets).insert(budget);
  }

  /// Update an existing budget
  Future<bool> updateBudget(Budget budget) async {
    return await update(budgets).replace(budget);
  }

  /// Delete a budget
  Future<int> deleteBudget(int id) async {
    return await (delete(budgets)..where((b) => b.id.equals(id))).go();
  }

  /// Calculate spending for a category in a date range
  Future<double> calculateCategorySpending(String category, DateTime startDate, DateTime endDate) async {
    // Normalize dates
    final normalizedStart = DateTime(startDate.year, startDate.month, startDate.day);
    final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    final query = selectOnly(transactions)
      ..addColumns([transactions.amount.sum()])
      ..where(transactions.type.equalsValue(TransactionType.expense) &
              transactions.category.equals(category) &
              transactions.isLending.equals(false) &
              transactions.timestamp.isBiggerOrEqualValue(normalizedStart) &
              transactions.timestamp.isSmallerOrEqualValue(normalizedEnd));
    
    final result = await query.getSingle();
    return result.read(transactions.amount.sum()) ?? 0.0;
  }

  /// Calculate total monthly spending (excluding lending)
  Future<double> calculateTotalMonthlySpending(DateTime startDate, DateTime endDate) async {
    final normalizedStart = DateTime(startDate.year, startDate.month, startDate.day);
    final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    final query = selectOnly(transactions)
      ..addColumns([transactions.amount.sum()])
      ..where(transactions.type.equalsValue(TransactionType.expense) &
              transactions.isLending.equals(false) &
              transactions.timestamp.isBiggerOrEqualValue(normalizedStart) &
              transactions.timestamp.isSmallerOrEqualValue(normalizedEnd));
    
    final result = await query.getSingle();
    return result.read(transactions.amount.sum()) ?? 0.0;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(file);
  });
}
