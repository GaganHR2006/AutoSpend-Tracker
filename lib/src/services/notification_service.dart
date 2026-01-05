import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../core/database/database.dart';
import '../features/transactions/data/transaction_repository.dart';

/// Provider for NotificationService
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return NotificationService(db);
});

/// Service to handle notification listener for UPI transactions
class NotificationService {
  static const _channel = MethodChannel('com.example.autospend/notifications');
  final AppDatabase _db;
  
  NotificationService(this._db) {
    _setupMethodChannel();
  }

  /// Set up the method channel to receive notifications from Kotlin
  void _setupMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNotification') {
        final Map<dynamic, dynamic> data = call.arguments;
        await _processNotification(
          packageName: data['packageName'] as String,
          title: data['title'] as String,
          text: data['text'] as String,
          timestamp: data['timestamp'] as int,
        );
      }
    });
  }

  /// Check if notification permission is granted
  Future<bool> isPermissionGranted() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkPermission');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Request notification permission (opens settings)
  Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestPermission');
    } catch (e) {
      // Ignore errors
    }
  }

  /// Process incoming UPI notification
  Future<void> _processNotification({
    required String packageName,
    required String title,
    required String text,
    required int timestamp,
  }) async {
    // Parse the notification
    final parsed = _parseNotification(packageName, title, text);
    if (parsed == null) return;

    final amount = parsed['amount'] as double;
    final merchant = parsed['merchant'] as String?;
    final type = parsed['type'] as TransactionType;
    final smsId = 'notif_${packageName}_$timestamp';

    // Check if already exists
    try {
      final existing = await (_db.select(_db.transactions)
        ..where((t) => t.smsId.equals(smsId)))
        .getSingleOrNull();
      
      if (existing != null) return; // Already processed

      // Insert new transaction
      await _db.into(_db.transactions).insert(TransactionsCompanion(
        smsId: Value(smsId),
        amount: Value(amount),
        merchant: Value(merchant),
        category: const Value('Uncategorized'),
        type: Value(type),
        timestamp: Value(DateTime.fromMillisecondsSinceEpoch(timestamp)),
        isManual: const Value(false),
        isLending: const Value(false),
        lendingType: const Value(LendingType.none),
      ));
    } catch (e) {
      // Log error but don't crash
    }
  }

  /// Parse notification text to extract transaction details
  Map<String, dynamic>? _parseNotification(String packageName, String title, String text) {
    final combined = '$title $text';
    
    // Extract amount with rupee symbol
    final amountRegex = RegExp(r'₹\s*([\d,]+(?:\.\d{2})?)');
    final amountMatch = amountRegex.firstMatch(combined);
    if (amountMatch == null) return null;

    final amountStr = amountMatch.group(1)!.replaceAll(',', '');
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) return null;

    // Determine transaction type
    TransactionType type = TransactionType.expense;
    
    // Keywords for income
    final incomeKeywords = ['received', 'credited', 'got', 'from'];
    // Keywords for expense
    final expenseKeywords = ['paid', 'sent', 'debited', 'to', 'transferred'];

    final lowerText = combined.toLowerCase();
    
    for (final keyword in incomeKeywords) {
      if (lowerText.contains(keyword)) {
        type = TransactionType.income;
        break;
      }
    }
    
    for (final keyword in expenseKeywords) {
      if (lowerText.contains(keyword)) {
        type = TransactionType.expense;
        break;
      }
    }

    // Extract merchant name (person/business name)
    String? merchant;
    
    // Common patterns: "paid to <name>", "received from <name>", "sent to <name>"
    final merchantPatterns = [
      RegExp(r'(?:paid|sent|transferred) to ([A-Za-z\s]+)', caseSensitive: false),
      RegExp(r'(?:received|credited) from ([A-Za-z\s]+)', caseSensitive: false),
      RegExp(r'to ([A-Za-z\s]+) on', caseSensitive: false),
      RegExp(r'from ([A-Za-z\s]+) on', caseSensitive: false),
    ];

    for (final pattern in merchantPatterns) {
      final match = pattern.firstMatch(combined);
      if (match != null) {
        merchant = match.group(1)?.trim();
        if (merchant != null && merchant.length > 2) break;
        merchant = null;
      }
    }

    // If no merchant found, use app name
    merchant ??= _appNameFromPackage(packageName);

    return {
      'amount': amount,
      'merchant': merchant,
      'type': type,
    };
  }

  String _appNameFromPackage(String packageName) {
    return switch (packageName) {
      'net.one97.paytm' => 'Paytm',
      'com.phonepe.app' => 'PhonePe',
      'com.google.android.apps.nbu.paisa.user' => 'Google Pay',
      'in.org.npci.upiapp' => 'BHIM',
      'com.whatsapp' => 'WhatsApp Pay',
      'com.amazon.mShop.android.shopping' => 'Amazon Pay',
      'com.mobikwik_new' => 'MobiKwik',
      'com.freecharge.android' => 'FreeCharge',
      _ => 'UPI Payment',
    };
  }
}
