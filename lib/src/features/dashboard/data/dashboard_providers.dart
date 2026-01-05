import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../../core/database/database.dart';

part 'dashboard_providers.g.dart';

// ==============================================================================
// FILTER PROVIDERS (NEW - for the Neon Filter Bar)
// ==============================================================================

enum TransactionTimeFilter {
  thisMonth,
  lastMonth,
  last3Months,
  last6Months,
  allTime,
  customRange,
}

// Current selected filter
final transactionFilterProvider = StateProvider<TransactionTimeFilter>((ref) => TransactionTimeFilter.thisMonth);

// Custom date range (used when customRange is selected)
final customDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

// ==============================================================================
// EXISTING PROVIDERS
// ==============================================================================

@riverpod
Stream<double> totalBalance(Ref ref) {
  return ref.watch(transactionRepositoryProvider).watchBalance();
}

@riverpod
Stream<List<Transaction>> recentTransactions(Ref ref) {
  // We want only top 20, but the repo exposes all sorted.
  return ref.watch(transactionRepositoryProvider).watchTransactions().map((list) => list.take(20).toList());
}

// Full transaction list (unfiltered)
final transactionListProvider = StreamProvider<List<Transaction>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchTransactions();
});

// FILTERED transaction list (based on selected filter)
final filteredTransactionListProvider = Provider<AsyncValue<List<Transaction>>>((ref) {
  final filter = ref.watch(transactionFilterProvider);
  final customRange = ref.watch(customDateRangeProvider);
  final transactionsAsync = ref.watch(transactionListProvider);
  
  return transactionsAsync.when(
    data: (transactions) {
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate = now;
      
      switch (filter) {
        case TransactionTimeFilter.thisMonth:
          startDate = DateTime(now.year, now.month, 1);
          break;
        case TransactionTimeFilter.lastMonth:
          startDate = DateTime(now.year, now.month - 1, 1);
          endDate = DateTime(now.year, now.month, 0); // Last day of previous month
          break;
        case TransactionTimeFilter.last3Months:
          startDate = DateTime(now.year, now.month - 3, 1);
          break;
        case TransactionTimeFilter.last6Months:
          startDate = DateTime(now.year, now.month - 6, 1);
          break;
        case TransactionTimeFilter.allTime:
          startDate = DateTime(2000); // Far past
          break;
        case TransactionTimeFilter.customRange:
          if (customRange != null) {
            startDate = customRange.start;
            endDate = customRange.end;
          } else {
            startDate = DateTime(now.year, now.month, 1);
          }
          break;
      }
      
      final filtered = transactions.where((tx) {
        return tx.timestamp.isAfter(startDate.subtract(const Duration(days: 1))) &&
               tx.timestamp.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();
      
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

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

// ⭐ Lending Summary Provider
final lendingSummaryProvider = StreamProvider<Map<String, double>>((ref) {
  return ref.watch(appDatabaseProvider).watchLendingSummary();
});
