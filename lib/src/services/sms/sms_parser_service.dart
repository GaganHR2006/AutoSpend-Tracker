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

  /// Infer category from merchant name - used for re-categorization
  String inferCategory(String merchant) {
    return _SmsParserHelpers().inferCategoryPublic(merchant);
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
        smsId: 'sms_${msg.id}_${msg.date?.millisecondsSinceEpoch}',  // ✅ Fixed: Added sms_ prefix
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
  // --- Allow Loose Sender IDs (like VK-SBIUPI-S, JD-HDFCBK) ---
  // ✅ CRITICAL: Made more permissive to accept all bank sender formats
  static final RegExp _senderIdRegex = RegExp(r'^[A-Z]{2,3}-[A-Z0-9\-\.]+$');
  
  static final List<String> _blocklist = [
    'OTP', 'Code', 'Login', 'Rummy', 'Win', 'Betting', 'Loan', 'Verification', 'Auth'
  ];
  
  // ⭐ ENHANCED: Multiple amount patterns
  static final List<RegExp> _amountPatterns = [
    // Original pattern: "debited Rs.1000" etc.
    RegExp(
      r'(debited|credited|spent|paid|received|sent)\s+(?:by|to|for|from)?\s*(?:Rs\.?|INR)?\s*(\d+(?:,\d+)*(?:\.\d+)?)',
      caseSensitive: false,
    ),
    // Rupee symbol pattern "₹1,000"
    RegExp(
      r'₹\s*(\d+(?:,\d+)*(?:\.\d+)?)',
      caseSensitive: false,
    ),
    // Rs without dot "Rs 1000" or "Rs1000"
    RegExp(
      r'Rs\s*(\d+(?:,\d+)*(?:\.\d+)?)',
      caseSensitive: false,
    ),
    // "Amount of Rs/INR"
    RegExp(
      r'(?:amount of|amt)\s*(?:Rs\.?|INR|₹)\s*(\d+(?:,\d+)*(?:\.\d+)?)',
      caseSensitive: false,
    ),
    // "charged Rs/INR"
    RegExp(
      r'charged\s*(?:Rs\.?|INR|₹)\s*(\d+(?:,\d+)*(?:\.\d+)?)',
      caseSensitive: false,
    ),
    // "INR 1000"
    RegExp(
      r'INR\s*(\d+(?:,\d+)*(?:\.\d+)?)',
      caseSensitive: false,
    ),
  ];

  // ⭐ MERCHANT PATTERNS - Specifically for Karnataka Bank & SBI formats
  // Based on actual user SMS samples:
  // Karnataka: "trf to INNOVATIVE RETAIL CO.", "from PRAHLAD J R SO J B R on 29-12-25"
  // SBI: "trf to Muheed Khan so a Refno", "transfer from RANGASWAMY"
  static final List<RegExp> _merchantPatterns = [
    // Pattern 1: Karnataka Bank & SBI "trf to NAME"
    // Example: "trf to INNOVATIVE RETAIL CO."
    // Example: "trf to Karukuri Badrinath"
    RegExp(r'trf\s+to\s+([A-Z][A-Za-z0-9\s\-&.]+?)(?:\.|$|(?:\s+UPI))', caseSensitive: false),
    
    // Pattern 2: SBI "trf to NAME so a Refno" or "trf to NAME Refno"
    // Example: "trf to Muheed Khan so a Refno 536050840882"
    // Example: "trf to Dominos Pizza Refno 568064926070"
    // Example: "trf to KAMRUL HUSSAIN Refno 572839056974"
    // Example: "trf to PREETHAM H M Refno 394818323959"
    RegExp(r'trf\s+to\s+([A-Z][A-Za-z0-9\s\-&.]+?)(?:\s+so\s+a)?\s+Refno', caseSensitive: false),
    
    // Pattern 3: SBI "transfer from NAME" or "credited...transfer from NAME"
    // Example: "transfer from RANGASWAMY"
    // Example: "transfer from GOOGLE INDIA DIGITAL SERVICES PVT LTD"
    // Example: "credited by Rs.1 on 17Jan26 transfer from PREETHAM H M Ref No"
    RegExp(r'transfer\s+from\s+([A-Z][A-Za-z0-9\s\-&.]+?)(?:\s+Ref|\s+on|\.|,|$)', caseSensitive: false),
    
    // Pattern 4: Karnataka Bank "from NAME on DATE"
    // Example: "from PRAHLAD J R SO J B R on 29-12-25"
    RegExp(r'from\s+([A-Z][A-Za-z\s]+?)\s+on\s+\d', caseSensitive: false),
    
    // Pattern 5: Karnataka Bank "debited for Rs.X on DATE trf to NAME"
    // Example: "debited for Rs.39.00 on 28-12-25 trf to INNOVATIVE RETAIL CO."
    RegExp(r'(?:debited|credited)\s+for\s+Rs\.?\s*[\d.,]+\s+on\s+[\d\-]+\s+trf\s+to\s+([A-Z][A-Za-z0-9\s\-&.]+?)(?:\.|$)', caseSensitive: false),
    
    // Pattern 6: Generic "to NAME" followed by date or ref
    RegExp(r'to\s+([A-Z][A-Z\s]{2,}[A-Za-z\s]*?)(?:\s+on\s+\d|\s+Ref|\.|$)', caseSensitive: false),
    
    // Pattern 7: Generic "from NAME" followed by date or ref
    RegExp(r'from\s+([A-Z][A-Z\s]{2,}[A-Za-z\s]*?)(?:\s+on\s+\d|\s+Ref|\.|$)', caseSensitive: false),
    
    // Pattern 8: "received from PERSON"
    RegExp(r'received from\s+([A-Z][A-Za-z0-9\s\-]+?)(?:\s+on|\s+Ref|\.|,|$)', caseSensitive: false),
  ];

  ParsedData? parseSms(String sender, String body) {
    print('✅✅✅ SMS PARSER CALLED ✅✅✅');
    print('   Sender: $sender');
    print('   Body: $body');
    
    // 1. Filter Sender ID
    if (!_senderIdRegex.hasMatch(sender)) {
      print('❌ REJECTED: Sender ID "$sender" does not match pattern');
      print('   Expected: 2-3 uppercase letters, dash, then alphanumeric');
      return null;
    }
    print('✅ Sender ID valid');

    // 2. Blocklist Check
    for (final word in _blocklist) {
      if (body.contains(word)) {
        print('❌ REJECTED: Contains blocklisted word "$word"');
        return null;
      }
    }
    print('✅ No blocklisted words found');

    // 3. Extract Amount (try multiple patterns)
    double? amount;
    String? keyword;
    
    for (final pattern in _amountPatterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        // First pattern has keyword in group 1, amount in group 2
        // Other patterns just have amount in group 1
        if (match.groupCount >= 2) {
          keyword = match.group(1)?.toLowerCase();
          final rawAmount = match.group(2)!.replaceAll(',', '');
          amount = double.tryParse(rawAmount);
        } else {
          final rawAmount = match.group(1)!.replaceAll(',', '');
          amount = double.tryParse(rawAmount);
        }
        if (amount != null && amount > 0) break;
      }
    }

    if (amount == null) return null;

    // 4. Determine Type based on keyword or body content
    TransactionType type = TransactionType.expense;
    
    if (keyword != null) {
      if (['credited', 'received'].contains(keyword)) {
        type = TransactionType.income;
      }
    } else {
      // Fallback: check body for income keywords
      final lowerBody = body.toLowerCase();
      if (lowerBody.contains('credited') || lowerBody.contains('received') || lowerBody.contains('deposit')) {
        type = TransactionType.income;
      }
    }

    // 5. ⭐ ENHANCED Merchant Extraction (try all patterns)
    String merchant = 'Unknown';
    bool foundMerchant = false;
    
    for (final pattern in _merchantPatterns) {
      final match = pattern.firstMatch(body);
      if (match != null && match.group(1) != null) {
        String extracted = match.group(1)!.trim();
        
        // Clean up extracted name
        extracted = extracted
            .replaceAll(RegExp(r'\s+'), ' ') // Multiple spaces to single
            .replaceAll(RegExp(r'[^\w\s@\.\-&]'), '') // Remove special chars except @.-&
            .trim();
        
        // Validate: not too short, not numbers only
        if (extracted.length >= 3 && !RegExp(r'^\d+$').hasMatch(extracted)) {
          merchant = extracted;
          foundMerchant = true;
          break;
        }
      }
    }
    
    // ❌ REMOVED: Sender address fallback - this was causing "Sbi S" from "VK-SBIUPI"!
    // IMPORTANT: Only extract merchant from message BODY, never from sender address
    // Sender addresses like "VK-SBIUPI", "AD-HDFCBK" are bank names, not merchants!
    
    // If no merchant found from body, keep as 'Unknown' - better than wrong name!
    if (!foundMerchant) {
      print('⚠️ No merchant found in body: ${body.length > 60 ? body.substring(0, 60) : body}...');
    }

    // Clean up merchant name further
    merchant = merchant.replaceAll(RegExp(r'(Dear|UPI|user|A\/C|info|UPI-|Ref|No|IMPS|\d{4,})', caseSensitive: false), '').trim();
    merchant = merchant.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Remove SBI "so a" suffix: "Muheed Khan so a" → "Muheed Khan"
    merchant = merchant.replaceAll(RegExp(r'\s+so\s+a\s*$', caseSensitive: false), '').trim();
    
    // Remove common noise words at the end
    final noiseSuffixes = ['On', 'For', 'Via', 'Thru', 'Upi', 'Ref', 'No', 'Refno', 'If Not', 'Call', 'Services'];
    for (final suffix in noiseSuffixes) {
      if (merchant.toLowerCase().endsWith(' ${suffix.toLowerCase()}')) {
        merchant = merchant.substring(0, merchant.length - suffix.length - 1).trim();
      }
    }

    // Capitalize first letter of each word (Title Case)
    if (merchant.isNotEmpty && merchant != 'Unknown') {
      merchant = merchant.split(' ')
          .where((word) => word.isNotEmpty)
          .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
          .join(' ');
    }

    if (merchant.isEmpty) merchant = 'Unknown';
    if (merchant.length > 50) merchant = merchant.substring(0, 50);

    // 6. ⭐ ENHANCED Categorization with comprehensive keywords
    final category = _inferCategory(merchant, body);

    return ParsedData(
      amount: amount,
      merchant: merchant,
      category: category,
      type: type,
    );
  }

  // ⭐ ENHANCED: Comprehensive category inference with Friends & Family detection
  String _inferCategory(String merchant, String body) {
    final lowerMerchant = merchant.toLowerCase();
    final lowerBody = body.toLowerCase();
    
    // Food & Dining
    if (lowerMerchant.contains('swiggy') || 
        lowerMerchant.contains('zomato') || 
        lowerMerchant.contains('uber eats') ||
        lowerMerchant.contains('dominos') ||
        lowerMerchant.contains('mcdonald') ||
        lowerMerchant.contains('kfc') ||
        lowerMerchant.contains('restaurant') ||
        lowerMerchant.contains('cafe') ||
        lowerMerchant.contains('food') ||
        lowerMerchant.contains('kitchen') ||
        lowerMerchant.contains('hotel') ||
        lowerBody.contains('food order')) {
      return 'Food';
    }
    
    // Transport
    if (lowerMerchant.contains('uber') || 
        lowerMerchant.contains('ola') || 
        lowerMerchant.contains('rapido') ||
        lowerMerchant.contains('metro') ||
        lowerMerchant.contains('petrol') ||
        lowerMerchant.contains('diesel') ||
        lowerMerchant.contains('fuel') ||
        lowerMerchant.contains('parking') ||
        lowerMerchant.contains('hp ') ||
        lowerMerchant.contains('iocl') ||
        lowerMerchant.contains('bpcl') ||
        lowerBody.contains('transport') ||
        lowerBody.contains('taxi')) {
      return 'Transport';
    }
    
    // Shopping
    if (lowerMerchant.contains('amazon') || 
        lowerMerchant.contains('flipkart') || 
        lowerMerchant.contains('myntra') ||
        lowerMerchant.contains('ajio') ||
        lowerMerchant.contains('meesho') ||
        lowerMerchant.contains('shopping') ||
        lowerMerchant.contains('mart') ||
        lowerMerchant.contains('mall') ||
        lowerMerchant.contains('store') ||
        lowerMerchant.contains('retail')) {
      return 'Shopping';
    }
    
    // Entertainment
    if (lowerMerchant.contains('netflix') || 
        lowerMerchant.contains('prime') || 
        lowerMerchant.contains('hotstar') ||
        lowerMerchant.contains('spotify') ||
        lowerMerchant.contains('movie') ||
        lowerMerchant.contains('cinema') ||
        lowerMerchant.contains('pvr') ||
        lowerMerchant.contains('inox') ||
        lowerMerchant.contains('bookmyshow') ||
        lowerBody.contains('entertainment') ||
        lowerBody.contains('subscription')) {
      return 'Entertainment';
    }
    
    // Health & Medical
    if (lowerMerchant.contains('pharma') || 
        lowerMerchant.contains('medical') || 
        lowerMerchant.contains('hospital') ||
        lowerMerchant.contains('clinic') ||
        lowerMerchant.contains('doctor') ||
        lowerMerchant.contains('medicine') ||
        lowerMerchant.contains('apollo') ||
        lowerMerchant.contains('medplus') ||
        lowerMerchant.contains('health') ||
        lowerBody.contains('pharmacy')) {
      return 'Health';
    }
    
    // Bills & Utilities
    if (lowerMerchant.contains('electricity') || 
        lowerMerchant.contains('water') || 
        lowerMerchant.contains('gas') ||
        lowerMerchant.contains('broadband') ||
        lowerMerchant.contains('wifi') ||
        lowerMerchant.contains('recharge') ||
        lowerMerchant.contains('bill') ||
        lowerMerchant.contains('payment') ||
        lowerMerchant.contains('jio') ||
        lowerMerchant.contains('airtel') ||
        lowerMerchant.contains('vodafone') ||
        lowerMerchant.contains('bsnl') ||
        lowerBody.contains('bill payment')) {
      return 'Bills';
    }
    
    // Rent
    if (lowerMerchant.contains('rent') || lowerBody.contains('rent')) {
      return 'Rent';
    }
    
    // Education
    if (lowerMerchant.contains('course') || 
        lowerMerchant.contains('tuition') || 
        lowerMerchant.contains('udemy') ||
        lowerMerchant.contains('coursera') ||
        lowerMerchant.contains('education') ||
        lowerMerchant.contains('school') ||
        lowerMerchant.contains('college') ||
        lowerMerchant.contains('university')) {
      return 'Education';
    }
    
    // Gym & Fitness
    if (lowerMerchant.contains('gym') || 
        lowerMerchant.contains('fitness') || 
        lowerMerchant.contains('cult') ||
        lowerMerchant.contains('yoga')) {
      return 'Gym';
    }
    
    // Personal Care
    if (lowerMerchant.contains('salon') || 
        lowerMerchant.contains('spa') || 
        lowerMerchant.contains('barber') ||
        lowerMerchant.contains('grooming') ||
        lowerMerchant.contains('parlour') ||
        lowerMerchant.contains('parlor')) {
      return 'Personal Care';
    }
    
    // Insurance
    if (lowerMerchant.contains('insurance') || lowerMerchant.contains('policy')) {
      return 'Insurance';
    }
    
    // Travel
    if (lowerMerchant.contains('makemytrip') || 
        lowerMerchant.contains('goibibo') || 
        lowerMerchant.contains('irctc') ||
        lowerMerchant.contains('flight') ||
        lowerMerchant.contains('airline') ||
        lowerMerchant.contains('hotel') ||
        lowerBody.contains('booking')) {
      return 'Travel';
    }
    
    // ⭐ Friends & Family - Person name detection (MUST BE LAST!)
    // Only match if it looks like a real person name, not a business
    // Pattern: "FirstName LastName" with proper capitalization
    
    // First, exclude common non-person patterns
    final nonPersonPatterns = [
      'unknown', 'sbi', 'hdfc', 'icici', 'axis', 'kotak', 'bank', 'upi',
      'retail', 'store', 'shop', 'mart', 'services', 'pvt', 'ltd', 'inc',
      'corp', 'enterprise', 'solution', 'tech', 'digital', 'payment'
    ];
    
    final isLikelyBusiness = nonPersonPatterns.any((p) => lowerMerchant.contains(p));
    
    if (!isLikelyBusiness && merchant != 'Unknown') {
      // Pattern: "Firstname Lastname" - proper capitalized names
      // e.g., "Rajesh Kumar", "Priya Sharma", "Mohammad Ali"
      if (RegExp(r'^[A-Z][a-z]{2,}\s+[A-Z][a-z]{2,}(?:\s+[A-Z][a-z]+)?$').hasMatch(merchant)) {
        return 'Friends & Family';
      }
      
      // Pattern: "Firstname M" or "Firstname H M" (Indian name style with initials)
      // e.g., "Preetham H M", "Kamrul H"
      if (RegExp(r'^[A-Z][a-z]{2,}\s+[A-Z](?:\s+[A-Z])?$').hasMatch(merchant)) {
        return 'Friends & Family';
      }
    }
    
    // Default - if nothing matched, keep as Uncategorized (NOT Friends & Family!)
    return 'Uncategorized';
  }

  /// Public method for re-categorization (merchant only, no body)
  String inferCategoryPublic(String merchant) {
    return _inferCategory(merchant, '');
  }
}