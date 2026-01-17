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

/// Service to handle real-time incoming notifications
class NotificationService {
  static const _channel = MethodChannel('com.example.autospend/notifications');
  final AppDatabase _db;
  
  // ✅ Cache of recently inserted transactions to prevent duplicates
  static final Map<String, DateTime> _recentInserts = {};
  static const _cacheExpiry = Duration(minutes: 10);
  
  NotificationService(this._db) {
    _setupMethodChannel();
  }
  
  /// Clean expired cache entries
  void _cleanExpiredCache() {
    final now = DateTime.now();
    _recentInserts.removeWhere((key, insertTime) {
      return now.difference(insertTime) > _cacheExpiry;
    });
  }

  /// Set up the method channel to receive notifications from Kotlin
  void _setupMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNotification') {
        final Map<dynamic, dynamic> data = call.arguments;
        await _processNotification(
          merchantName: data['merchantName'] as String,
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
    required String merchantName,
    required String title,
    required String text,
    required int timestamp,
  }) async {
    final now = DateTime.now();
    print('');
    print('✅✅✅ NOTIFICATION RECEIVED [${now.hour}:${now.minute}:${now.second}] ✅✅✅');
    print('   Merchant: $merchantName');
    print('   Title: $title');
    print('   Text: $text');
    print('   Timestamp: ${DateTime.fromMillisecondsSinceEpoch(timestamp)}');
    print('');
    
    // Parse the notification
    final parsed = _parseNotification(title, text);
    if (parsed == null) return;

    final amount = parsed['amount'] as double;
    final type = parsed['type'] as TransactionType;
    // Use the pre-extracted merchant name from Kotlin
    final merchant = merchantName;
    
    print('🔔 NotificationService: Processing notification transaction');
    print('   Merchant: $merchant');
    print('   Amount: ₹$amount');
    print('   Type: $type');
    print('   Timestamp: ${DateTime.fromMillisecondsSinceEpoch(timestamp)}');
    
    final transactionTimestamp = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final smsId = 'notif_${timestamp}_${merchant.replaceAll(' ', '_')}';
    
    // Check if already exists
    try {
      // Clean expired cache entries
      _cleanExpiredCache();
      
      // ✅ CHECK 0: Cache check using exact notifId (fastest, most reliable)
      // This prevents the EXACT same notification from being processed twice
      if (_recentInserts.containsKey(smsId)) {
        final insertTime = _recentInserts[smsId]!;
        final timeSince = DateTime.now().difference(insertTime).inSeconds;
        print('⚠️ NotificationService: BLOCKED by cache - Same notifId inserted ${timeSince}s ago');
        print('   Notif ID: $smsId');
        return;
      }
      
      // ✅ CHECK 2: Exact smsId duplicate (same notification received twice)
      final existingBySmsId = await (_db.select(_db.transactions)
        ..where((t) => t.smsId.equals(smsId)))
        .getSingleOrNull();
      
      if (existingBySmsId != null) {
        print('⚠️ NotificationService: EXACT DUPLICATE - Same smsId already exists');
        print('   Existing ID: ${existingBySmsId.smsId}');
        return;
      }
      
      // ✅ CHECK 3: Fuzzy duplicate (same transaction from SMS source)
      print('🔍 NotificationService: Checking for fuzzy duplicates...');
      final isDuplicate = await _db.isDuplicateTransaction(
        amount: amount,
        type: type,
        timestamp: transactionTimestamp,
        merchant: merchant,  // ✅ Added merchant for smarter duplicate detection
      );
      
      if (isDuplicate) {
        print('⚠️ NotificationService: FUZZY DUPLICATE DETECTED - Transaction blocked!');
        print('   This transaction likely came from SMS');
        return;
      }
      
      print('✅ NotificationService: All checks passed - Proceeding with insert');
      
      // ✅ ADD TO CACHE BEFORE INSERTING (prevents race condition)
      _recentInserts[smsId] = DateTime.now();
      print('📝 NotificationService: Added to cache - Notif ID: $smsId');
      
      print('');
      print('═══════════════════════════════════');
      print('🔔 NOTIFICATION SERVICE: ATTEMPTING INSERT');
      print('═══════════════════════════════════');
      print('SMS ID: $smsId');
      print('Amount: ₹$amount');
      print('Merchant: Uncategorized');
      print('Category: Uncategorized');
      print('Type: $type');
      print('Timestamp: $transactionTimestamp');
      print('═══════════════════════════════════');
      print('');

      // Insert new transaction
      await _db.into(_db.transactions).insert(TransactionsCompanion(
        smsId: Value(smsId),
        amount: Value(amount),
        merchant: Value(merchant),
        category: const Value('Uncategorized'),
        type: Value(type),
        timestamp: Value(transactionTimestamp),
        isManual: const Value(false),
        isLending: const Value(false),
        lendingType: const Value(LendingType.none),
      ));
      
      print('✅ NOTIFICATION SERVICE: INSERT SUCCESSFUL');
      print('');
      
      // ✅ Force stream refresh by querying
      final allTransactions = await _db.select(_db.transactions).get();
      print('🔄 Database now has ${allTransactions.length} total transactions');
      
      // Give time for stream to propagate
      await Future.delayed(const Duration(milliseconds: 300));
      print('🔄 Streams should have updated UI by now');
    } catch (e) {
      // Log error but don't crash
      print('❌ NotificationService: Error processing notification: $e');
    }
  }

  /// Parse notification text to extract transaction details
  Map<String, dynamic>? _parseNotification(String title, String text) {
    final combined = '$title $text';
    
    print('🔍 NotificationService: Parsing notification');
    print('   Title: $title');
    print('   Text: $text');
    print('   Combined: $combined');
    
    // Extract amount with rupee symbol
    final amountRegex = RegExp(r'₹\s*([\d,]+(?:\.\d{2})?)');
    final amountMatch = amountRegex.firstMatch(combined);
    if (amountMatch == null) {
      print('⚠️ No amount found in notification');
      return null;
    }

    final amountStr = amountMatch.group(1)!.replaceAll(',', '');
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      print('⚠️ Invalid amount: $amountStr');
      return null;
    }

    // Determine transaction type
    final lowerText = combined.toLowerCase();
    TransactionType type = TransactionType.expense;
    
    // ✅ CRITICAL: Check income patterns FIRST (they're more specific)
    // "paid you" = income, "sent you" = income
    // "you paid" = expense, "you sent" = expense
    
    // Income indicators (someone sending money TO you)
    if (lowerText.contains('paid you') ||
        lowerText.contains('sent you') ||
        lowerText.contains('received') ||
        lowerText.contains('credited') ||
        lowerText.contains('got') ||
        lowerText.contains('payment from')) {
      type = TransactionType.income;
    }
    // Expense indicators (you sending money TO someone)
    else if (lowerText.contains('you paid') ||
             lowerText.contains('you sent') ||
             lowerText.contains('paid to') ||
             lowerText.contains('sent to') ||
             lowerText.contains('debited') ||
             lowerText.contains('transferred to')) {
      type = TransactionType.expense;
    }
    
    print('✅ Detected amount: ₹$amount');
    print('✅ Detected type: $type');

    return {
      'amount': amount,
      'type': type,
    };
  }
}
