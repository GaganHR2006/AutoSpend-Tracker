import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../../core/database/database.dart';

part 'dashboard_providers.g.dart';

// ==============================================================================
// FILTER PROVIDERS
// ==============================================================================

enum TransactionTimeFilter {
  thisMonth,
  lastMonth,
  last3Months,
  last6Months,
  allTime,
  customRange, // ⭐ Used for Time Travel date range
}

// Current selected filter - Default to customRange to use saved Time Travel dates
final transactionFilterProvider = StateProvider<TransactionTimeFilter>((ref) => TransactionTimeFilter.customRange);

// ⭐ Load saved date range from SharedPreferences (set during Time Travel)
final savedDateRangeProvider = FutureProvider<DateTimeRange?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final startStr = prefs.getString('filter_start_date');
  final endStr = prefs.getString('filter_end_date');
  
  if (startStr != null && endStr != null) {
    return DateTimeRange(
      start: DateTime.parse(startStr),
      end: DateTime.parse(endStr),
    );
  }
  return null;
});

// Custom date range - uses saved range or falls back to null
final customDateRangeProvider = StateProvider<DateTimeRange?>((ref) {
  final savedRange = ref.watch(savedDateRangeProvider);
  return savedRange.valueOrNull;
});

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
      
      // Normalize dates to start of day (00:00:00) and end of day (23:59:59)
      final normalizedStartDate = DateTime(startDate.year, startDate.month, startDate.day);
      final normalizedEndDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      final filtered = transactions.where((tx) {
        // Transaction must be >= start date AND <= end date (inclusive)
        return !tx.timestamp.isBefore(normalizedStartDate) && 
               !tx.timestamp.isAfter(normalizedEndDate);
      }).toList();
      
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

// ⭐ FILTERED balance (based on selected filter, excludes lending)
final filteredBalanceProvider = Provider<AsyncValue<double>>((ref) {
  final filteredAsync = ref.watch(filteredTransactionListProvider);
  
  return filteredAsync.when(
    data: (transactions) {
      double totalIncome = 0;
      double totalExpense = 0;
      
      for (final tx in transactions) {
        // Skip lending transactions
        if (tx.isLending) continue;
        
        if (tx.type == TransactionType.income) {
          totalIncome += tx.amount;
        } else {
          totalExpense += tx.amount;
        }
      }
      
      final balance = totalIncome - totalExpense;
      return AsyncValue.data(balance);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

@riverpod
Stream<Map<String, double>> spendingByCategory(Ref ref) {
  // ⭐ Use FILTERED transactions (respects saved date range)
  return ref.watch(transactionRepositoryProvider).watchTransactions().map((allTransactions) {
    // Get date range from savedDateRangeProvider
    final savedRange = ref.read(savedDateRangeProvider).valueOrNull;
    
    List<Transaction> transactions = allTransactions;
    
    // Apply date filter if available
    if (savedRange != null) {
      final normalizedStart = DateTime(savedRange.start.year, savedRange.start.month, savedRange.start.day);
      final normalizedEnd = DateTime(savedRange.end.year, savedRange.end.month, savedRange.end.day, 23, 59, 59);

      transactions = allTransactions.where((tx) {
        return !tx.timestamp.isBefore(normalizedStart) && 
               !tx.timestamp.isAfter(normalizedEnd);
      }).toList();
    }
    
    final Map<String, double> map = {};
    
    for (final tx in transactions) {
      // Include ALL expense transactions (not just specific categories)
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
