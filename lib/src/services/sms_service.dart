import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../core/database/database.dart';
import '../features/transactions/data/transaction_repository.dart';
import 'sms/sms_parser_service.dart';

/// Provider for SmsService
final smsServiceProvider = Provider<SmsService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final parser = ref.watch(smsParserServiceProvider);
  return SmsService(db, parser);
});

/// Service to handle real-time incoming SMS messages
class SmsService {
  static const _channel = MethodChannel('com.example.autospend/sms');
  final AppDatabase _db;
  final SmsParserService _parser;
  
  // ✅ Cache of recently inserted transactions to prevent duplicates
  static final Map<String, DateTime> _recentInserts = {};
  static const _cacheExpiry = Duration(minutes: 10);
  
  SmsService(this._db, this._parser) {
    _setupMethodChannel();
  }
  
  /// Clean expired cache entries
  void _cleanExpiredCache() {
    final now = DateTime.now();
    _recentInserts.removeWhere((key, insertTime) {
      return now.difference(insertTime) > _cacheExpiry;
    });
  }

  /// Set up the method channel to receive SMS from Kotlin
  void _setupMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSmsReceived') {
        final Map<dynamic, dynamic> data = call.arguments;
        await _processSms(
          sender: data['sender'] as String,
          body: data['body'] as String,
          timestamp: data['timestamp'] as int,
        );
      }
    });
  }

  /// Process incoming SMS
  Future<void> _processSms({
    required String sender,
    required String body,
    required int timestamp,
  }) async {
    try {
      // Parse the SMS
      final parsed = _parser.parseSms(sender, body);
      if (parsed == null) {
        return;
      }
      
      final transactionTimestamp = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final smsId = 'sms_${sender}_$timestamp';
      
      // ✅ CHECK 0: Cache check using exact smsId (fastest, most reliable)
      // This prevents the EXACT same SMS from being processed twice
      _cleanExpiredCache();
      
      if (_recentInserts.containsKey(smsId)) {
        return;
      }
      
      // ✅ CHECK 2: Exact smsId duplicate (same SMS received twice)
      final existingBySmsId = await (_db.select(_db.transactions)
        ..where((t) => t.smsId.equals(smsId)))
        .getSingleOrNull();
      
      if (existingBySmsId != null) {
        return;
      }
      
      // ✅ CHECK 3: Fuzzy duplicate (same transaction from different source)
      final isDuplicate = await _db.isDuplicateTransaction(
        amount: parsed.amount,
        type: parsed.type,
        timestamp: transactionTimestamp,
        merchant: parsed.merchant,  // ✅ Added merchant for smarter duplicate detection
      );
      
      if (isDuplicate) {
        return;
      }
      
      // ✅ ADD TO CACHE BEFORE INSERTING (prevents race condition)
      _recentInserts[smsId] = DateTime.now();
      
      // Insert new transaction
      await _db.into(_db.transactions).insert(TransactionsCompanion(
        smsId: Value(smsId),
        amount: Value(parsed.amount),
        merchant: Value(parsed.merchant),
        category: Value(parsed.category),
        type: Value(parsed.type),
        timestamp: Value(transactionTimestamp),
        isManual: const Value(false),
        isLending: const Value(false),
        lendingType: const Value(LendingType.none),
      ));
    } catch (e) {
      // Silent failure - SMS processing errors should not crash the app
    }
  }
}
