import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../../core/database/database.dart';
import '../../transactions/data/transaction_repository.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BudgetRepository(db);
});

class BudgetRepository {
  final AppDatabase _db;

  BudgetRepository(this._db);

  /// Watch all active budgets
  Stream<List<Budget>> watchBudgets() {
    return _db.watchBudgets();
  }

  /// Get all budgets
  Future<List<Budget>> getBudgets() async {
    return _db.getAllBudgets();
  }

  /// Get budget for specific category
  Future<Budget?> getBudgetForCategory(String category) async {
    return _db.getBudgetForCategory(category);
  }

  /// Set or update budget for a category
  Future<void> setCategoryBudget({
    required String category,
    required double amount,
    int threshold = 80,
  }) async {
    final existing = await _db.getBudgetForCategory(category);

    if (existing != null) {
      // Update existing budget
      final updated = existing.copyWith(
        limitAmount: amount,
        alertThreshold: threshold,
      );
      await _db.updateBudget(updated);
    } else {
      // Create new budget
      await _db.insertBudget(
        BudgetsCompanion.insert(
          category: category,
          limitAmount: amount,
          alertThreshold: Value(threshold),
        ),
      );
    }
  }

  /// Delete a budget
  Future<void> deleteBudget(int id) async {
    await _db.deleteBudget(id);
  }

  /// Calculate usage for a specific category in current month
  Future<BudgetUsage> calculateUsage(String category) async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, 1);
    final endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final budget = await getBudgetForCategory(category);
    if (budget == null) {
      return BudgetUsage(
        category: category,
        spent: 0,
        limit: 0,
        threshold: 80,
        percentage: 0,
      );
    }

    double spent;
    if (category == 'TOTAL_MONTHLY') {
      spent = await _db.calculateTotalMonthlySpending(startDate, endDate);
    } else {
      spent = await _db.calculateCategorySpending(category, startDate, endDate);
    }

    final percentage = budget.limitAmount > 0 ? (spent / budget.limitAmount * 100).toDouble() : 0.0;

    return BudgetUsage(
      category: category,
      spent: spent,
      limit: budget.limitAmount,
      threshold: budget.alertThreshold,
      percentage: percentage,
    );
  }

  /// Calculate usage for date range
  Future<BudgetUsage> calculateUsageForDateRange({
    required String category,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final budget = await getBudgetForCategory(category);
    if (budget == null) {
      return BudgetUsage(
        category: category,
        spent: 0,
        limit: 0,
        threshold: 80,
        percentage: 0,
      );
    }

    double spent;
    if (category == 'TOTAL_MONTHLY') {
      spent = await _db.calculateTotalMonthlySpending(startDate, endDate);
    } else {
      spent = await _db.calculateCategorySpending(category, startDate, endDate);
    }

    final percentage = budget.limitAmount > 0 ? (spent / budget.limitAmount * 100).toDouble() : 0.0;

    return BudgetUsage(
      category: category,
      spent: spent,
      limit: budget.limitAmount,
      threshold: budget.alertThreshold,
      percentage: percentage,
    );
  }

  /// Check all budgets and return violations
  Future<List<BudgetAlert>> checkBudgetAlerts() async {
    final budgets = await getBudgets();
    final alerts = <BudgetAlert>[];

    for (final budget in budgets) {
      if (!budget.isActive) continue;

      final usage = await calculateUsage(budget.category);
      
      if (usage.percentage >= budget.alertThreshold) {
        final alertType = _getAlertType(usage.percentage);
        alerts.add(BudgetAlert(
          category: budget.category,
          spent: usage.spent,
          limit: usage.limit,
          percentage: usage.percentage,
          threshold: budget.alertThreshold,
          type: alertType,
        ));
      }
    }

    return alerts;
  }

  BudgetAlertType _getAlertType(double percentage) {
    if (percentage >= 100) return BudgetAlertType.exceeded;
    if (percentage >= 90) return BudgetAlertType.danger;
    return BudgetAlertType.warning;
  }
}

/// Budget usage data model
class BudgetUsage {
  final String category;
  final double spent;
  final double limit;
  final int threshold;
  final double percentage;

  BudgetUsage({
    required this.category,
    required this.spent,
    required this.limit,
    required this.threshold,
    required this.percentage,
  });

  bool get isOverBudget => percentage >= 100;
  bool get isNearLimit => percentage >= threshold;
}

/// Budget alert data model
class BudgetAlert {
  final String category;
  final double spent;
  final double limit;
  final double percentage;
  final int threshold;
  final BudgetAlertType type;

  BudgetAlert({
    required this.category,
    required this.spent,
    required this.limit,
    required this.percentage,
    required this.threshold,
    required this.type,
  });
}

enum BudgetAlertType {
  warning,  // 80-90%
  danger,   // 90-100%
  exceeded, // >100%
}
