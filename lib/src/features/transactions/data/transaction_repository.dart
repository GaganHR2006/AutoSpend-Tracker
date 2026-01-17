import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../src/core/database/database.dart';

part 'transaction_repository.g.dart';

@riverpod
AppDatabase appDatabase(Ref ref) {
  return AppDatabase();
}

@riverpod
TransactionRepository transactionRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return TransactionRepository(db);
}

class TransactionRepository {
  final AppDatabase _db;

  TransactionRepository(this._db);

  Stream<List<Transaction>> watchTransactions() {
    print('📡 Repository: Setting up watchTransactions stream');
    final stream = _db.watchAllTransactions();
    
    return stream.map((transactions) {
      print('📡 Repository Stream: Passing ${transactions.length} transactions to providers');
      return transactions;
    });
  }
  Stream<double> watchBalance() => _db.watchBalance();

  Future<void> addTransaction(TransactionsCompanion entry) => _db.into(_db.transactions).insert(entry);

  Future<void> updateTransaction(Transaction entry) => _db.update(_db.transactions).replace(entry);

  Future<void> deleteTransaction(int id) => (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();

  // ⭐ Update just the category of a transaction
  Future<void> updateCategory(int id, String category) async {
    await (_db.update(_db.transactions)..where((t) => t.id.equals(id)))
        .write(TransactionsCompanion(category: Value(category)));
  }

  // ⭐ Get uncategorized transactions - respects saved date range filter
  Future<List<Transaction>> getUncategorizedTransactions() async {
    // Try to get date range from preferences
    final prefs = await SharedPreferences.getInstance();
    final startDateStr = prefs.getString('filter_start_date');
    final endDateStr = prefs.getString('filter_end_date');
    
    if (startDateStr != null && endDateStr != null) {
      final startDate = DateTime.parse(startDateStr);
      final endDate = DateTime.parse(endDateStr);
      
      // Normalize to start of day and end of day
      final normalizedStart = DateTime(startDate.year, startDate.month, startDate.day);
      final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      
      print('🔍 Filtering uncategorized by date: ${normalizedStart.toLocal()} to ${normalizedEnd.toLocal()}');
      
      return (_db.select(_db.transactions)
        ..where((t) => t.category.equals('Uncategorized'))
        ..where((t) => t.timestamp.isBiggerOrEqualValue(normalizedStart))
        ..where((t) => t.timestamp.isSmallerOrEqualValue(normalizedEnd))
        ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .get();
    }
    
    // Fallback: return all uncategorized if no date range set
    print('📊 No date filter - returning all uncategorized');
    return (_db.select(_db.transactions)
      ..where((t) => t.category.equals('Uncategorized'))
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
      .get();
  }

  // ⭐ Get uncategorized in specific date range
  Future<List<Transaction>> getUncategorizedInRange(DateTime startDate, DateTime endDate) async {
    // Normalize dates
    final normalizedStart = DateTime(startDate.year, startDate.month, startDate.day);
    final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    
    return (_db.select(_db.transactions)
      ..where((t) => t.category.equals('Uncategorized'))
      ..where((t) => t.timestamp.isBiggerOrEqualValue(normalizedStart))
      ..where((t) => t.timestamp.isSmallerOrEqualValue(normalizedEnd))
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
      .get();
  }
}
