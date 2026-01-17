import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../features/budget/data/budget_repository.dart';
import 'local_notification_service.dart';

final budgetAlertServiceProvider = Provider<BudgetAlertService>((ref) {
  final budgetRepo = ref.watch(budgetRepositoryProvider);
  final notificationService = ref.watch(localNotificationServiceProvider);
  return BudgetAlertService(budgetRepo, notificationService);
});

class BudgetAlertService {
  final BudgetRepository _budgetRepo;
  final LocalNotificationService _notificationService;
  
  // Track last alert time per category (in-memory, max 1 alert per day)
  final Map<String, DateTime> _lastAlertTimes = {};

  BudgetAlertService(this._budgetRepo, this._notificationService) {
    _notificationService.initialize();
  }

  /// Check budget violations after a transaction
  Future<void> checkAndNotifyBudgetViolations({
    required double transactionAmount,
    required String category,
  }) async {
    try {
      // Check category budget
      await _checkCategoryBudget(category);

      // Check total monthly budget
      await _checkTotalMonthlyBudget();

      print('✅ Budget check completed for $category');
    } catch (e) {
      print('⚠️ Error checking budget violations: $e');
    }
  }

  Future<void> _checkCategoryBudget(String category) async {
    final budget = await _budgetRepo.getBudgetForCategory(category);
    if (budget == null || !budget.isActive) return;

    final usage = await _budgetRepo.calculateUsage(category);
    
    // Only alert if threshold is crossed
    if (usage.percentage >= budget.alertThreshold) {
      await _sendAlertIfNeeded(
        category: category,
        percentage: usage.percentage,
        spent: usage.spent,
        limit: usage.limit,
      );
    }
  }

  Future<void> _checkTotalMonthlyBudget() async {
    final budget = await _budgetRepo.getBudgetForCategory('TOTAL_MONTHLY');
    if (budget == null || !budget.isActive) return;

    final usage = await _budgetRepo.calculateUsage('TOTAL_MONTHLY');
    
    if (usage.percentage >= budget.alertThreshold) {
      await _sendAlertIfNeeded(
        category: 'TOTAL_MONTHLY',
        percentage: usage.percentage,
        spent: usage.spent,
        limit: usage.limit,
      );
    }
  }

  Future<void> _sendAlertIfNeeded({
    required String category,
    required double percentage,
    required double spent,
    required double limit,
  }) async {
    // Check if we already sent an alert today
    if (_shouldSkipAlert(category)) {
      print('⏭️ Skipping alert for $category (already sent today)');
      return;
    }

    // Format message based on percentage
    final currencyFormat = NumberFormat.simpleCurrency(name: 'INR', decimalDigits: 0);
    final message = _formatAlertMessage(
      category: category,
      percentage: percentage,
      spent: currencyFormat.format(spent),
      limit: currencyFormat.format(limit),
    );

    // Send notification
    await _notificationService.showBudgetAlert(
      category: _formatCategoryName(category),
      percentage: percentage,
      message: message,
    );

    // Record alert time
    _lastAlertTimes[category] = DateTime.now();
    
    print('🔔 Budget alert sent: $category ($percentage%)');
  }

  bool _shouldSkipAlert(String category) {
    final lastAlert = _lastAlertTimes[category];
    if (lastAlert == null) return false;

    final now = DateTime.now();
    final daysSinceLastAlert = now.difference(lastAlert).inHours / 24;
    
    // Allow max 1 alert per day per category
    return daysSinceLastAlert < 1.0;
  }

  String _formatAlertMessage({
    required String category,
    required double percentage,
    required String spent,
    required String limit,
  }) {
    final categoryName = _formatCategoryName(category);
    
    if (percentage >= 100) {
      final overBy = percentage - 100;
      return 'You\'ve exceeded your $categoryName budget by ${overBy.toStringAsFixed(0)}%! Spent $spent of $limit.';
    } else if (percentage >= 90) {
      return 'You\'ve used ${percentage.toStringAsFixed(0)}% of your $categoryName budget. Only ${(100 - percentage).toStringAsFixed(0)}% remaining!';
    } else {
      return 'You\'ve used ${percentage.toStringAsFixed(0)}% of your $categoryName budget. Spent $spent of $limit.';
    }
  }

  String _formatCategoryName(String category) {
    if (category == 'TOTAL_MONTHLY') return 'Monthly';
    if (category == 'CREDIT_CARD') return 'Credit Card';
    return category;
  }

  /// Check all budgets and send alerts (for manual trigger)
  Future<void> checkAllBudgets() async {
    final alerts = await _budgetRepo.checkBudgetAlerts();
    
    for (final alert in alerts) {
      await _sendAlertIfNeeded(
        category: alert.category,
        percentage: alert.percentage,
        spent: alert.spent,
        limit: alert.limit,
      );
    }
    
    print('✅ Checked all budgets: ${alerts.length} alerts found');
  }

  /// Clear alert history (for testing)
  void clearAlertHistory() {
    _lastAlertTimes.clear();
    print('🗑️ Alert history cleared');
  }
}
