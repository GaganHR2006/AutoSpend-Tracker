import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../../core/database/database.dart';

part 'dashboard_providers.g.dart';

@riverpod
Stream<double> totalBalance(Ref ref) {
  return ref.watch(transactionRepositoryProvider).watchBalance();
}

@riverpod
Stream<List<Transaction>> recentTransactions(Ref ref) {
  // We want only top 20, but the repo exposes all sorted.
  return ref.watch(transactionRepositoryProvider).watchTransactions().map((list) => list.take(20).toList());
}

@riverpod
Stream<Map<String, double>> spendingByCategory(Ref ref) {
  return ref.watch(transactionRepositoryProvider).watchTransactions().map((transactions) {
    final Map<String, double> map = {};
    for (final tx in transactions) {
      if (tx.type == TransactionType.expense) {
        map.update(tx.category, (value) => value + tx.amount, ifAbsent: () => tx.amount);
      }
    }
    return map;
  });
}
