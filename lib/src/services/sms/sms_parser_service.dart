import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:drift/drift.dart';
import '../../core/database/database.dart';
import '../../features/transactions/data/transaction_repository.dart';

part 'sms_parser_service.g.dart';

class ParsedData {
  final double amount;
  final String? merchant;
  final String category;
  final TransactionType type;

  ParsedData({
    required this.amount,
    this.merchant,
    required this.category,
    required this.type,
  });
}

@riverpod
SmsParserService smsParserService(Ref ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return SmsParserService(repo);
}

class SmsParserService {
  final TransactionRepository _repo;
  final SmsQuery _query = SmsQuery();

  SmsParserService(this._repo);

  ParsedData? parseSms(String sender, String body) {
    return _SmsParserHelpers().parseSms(sender, body);
  }

  Future<void> scanMessages(int months) async {
    // 1. Permission
    final status = await Permission.sms.request();
    if (!status.isGranted) return;

    // 2. Fetch
    final date = DateTime.now().subtract(Duration(days: 30 * months));
    final messages = await _query.querySms(
      kinds: [SmsQueryKind.inbox],
      count: 1000, 
    ); 

    // 3. Process in Isolate
    final validTransactions = await compute(_parseMessagesInIsolate, messages);

    // 4. Insert
    for (final tx in validTransactions) {
      if (tx.timestamp.value.isAfter(date)) {
        try {
          await _repo.addTransaction(tx);
        } catch (e) {
          // Ignore duplicates
        }
      }
    }
  }
}

// Top-level function for isolate
List<TransactionsCompanion> _parseMessagesInIsolate(List<SmsMessage> messages) {
  final helpers = _SmsParserHelpers();
  final results = <TransactionsCompanion>[];

  for (final msg in messages) {
    if (msg.sender == null || msg.body == null) continue;
    
    final parsed = helpers.parseSms(msg.sender!, msg.body!);
    if (parsed != null) {
      results.add(TransactionsCompanion.insert(
        smsId: '${msg.id}_${msg.date?.millisecondsSinceEpoch}',
        amount: parsed.amount,
        merchant: Value(parsed.merchant),
        category: Value(parsed.category),
        type: parsed.type,
        timestamp: msg.date ?? DateTime.now(),
        isManual: false,
      ));
    }
  }
  return results;
}

class _SmsParserHelpers {
  // --- FIX IS HERE: Allow Loose Sender IDs (like JD-SBIUPI-S) ---
  static final RegExp _senderIdRegex = RegExp(r'^[A-Z]{2}-[A-Z0-9\-\.]+$');
  
  static final List<String> _blocklist = [
    'OTP', 'Code', 'Login', 'Rummy', 'Win', 'Betting', 'Loan', 'Verification', 'Auth'
  ];
  
  static final RegExp _amountRegex = RegExp(
    r'(debited|credited|spent|paid|received|sent)\s+(?:by|to|for|from)?\s*(?:Rs\.?|INR)?\s*(\d+(?:,\d+)*(?:\.\d+)?)',
    caseSensitive: false,
  );

  ParsedData? parseSms(String sender, String body) {
    // 1. Filter Sender ID
    if (!_senderIdRegex.hasMatch(sender)) return null;

    // 2. Blocklist Check
    for (final word in _blocklist) {
      if (body.contains(word)) return null;
    }

    // 3. Extract Amount
    final amountMatch = _amountRegex.firstMatch(body);
    if (amountMatch == null) return null;

    final keyword = amountMatch.group(1)!.toLowerCase();
    final rawAmount = amountMatch.group(2)!.replaceAll(',', '');
    final amount = double.tryParse(rawAmount);

    if (amount == null) return null;

    // 4. Determine Type
    TransactionType type;
    if (['credited', 'received'].contains(keyword)) {
      type = TransactionType.income;
    } else {
      type = TransactionType.expense;
    }

    // 5. Merchant Extraction
    String merchant = 'Unknown';
    final merchantRegex = RegExp(r'(?:\b(?:to|at|sent to|trf to)\s+)([a-zA-Z0-9\s]+)', caseSensitive: false);
    final merchantMatch = merchantRegex.firstMatch(body);
    
    if (merchantMatch != null) {
      merchant = merchantMatch.group(1)!.trim();
    }

    merchant = merchant.replaceAll(RegExp(r'(Dear|UPI|user|A\/C|info|UPI-|\d{4,})', caseSensitive: false), '').trim();
    merchant = merchant.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (merchant.isEmpty) merchant = 'Unknown';
    if (merchant.length > 20) merchant = '${merchant.substring(0, 20)}...';

    // 6. Categorization
    final lowerBody = body.toLowerCase();
    String category = 'Uncategorized';
    if (lowerBody.contains('zomato') || lowerBody.contains('swiggy') || lowerBody.contains('dominos')) {
      category = 'Food';
    } else if (lowerBody.contains('uber') || lowerBody.contains('ola') || lowerBody.contains('petrol') || lowerBody.contains('fuel')) {
      category = 'Transport';
    } else if (lowerBody.contains('amazon') || lowerBody.contains('flipkart') || lowerBody.contains('myntra')) {
      category = 'Shopping';
    } else if (lowerBody.contains('jio') || lowerBody.contains('airtel') || lowerBody.contains('wifi') || lowerBody.contains('bill')) {
      category = 'Bills';
    }

    return ParsedData(
      amount: amount,
      merchant: merchant,
      category: category,
      type: type,
    );
  }
}