import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:drift/drift.dart';
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

  Stream<List<Transaction>> watchTransactions() => _db.watchAllTransactions();
  Stream<double> watchBalance() => _db.watchBalance();

  Future<void> addTransaction(TransactionsCompanion entry) => _db.into(_db.transactions).insert(entry);

  Future<void> updateTransaction(Transaction entry) => _db.update(_db.transactions).replace(entry);

  Future<void> deleteTransaction(int id) => (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();

  // ⭐ NEW: Update just the category of a transaction
  Future<void> updateCategory(int id, String category) async {
    await (_db.update(_db.transactions)..where((t) => t.id.equals(id)))
        .write(TransactionsCompanion(category: Value(category)));
  }

  // ⭐ NEW: Get all uncategorized transactions
  Future<List<Transaction>> getUncategorizedTransactions() async {
    return (_db.select(_db.transactions)
      ..where((t) => t.category.equals('Uncategorized'))
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
      .get();
  }
}
