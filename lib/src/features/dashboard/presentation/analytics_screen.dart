import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;
import '../data/dashboard_providers.dart';
import '../../../core/database/database.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../categories/data/categories.dart';
import '../../categories/data/category_service.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int? touchedIndex;

  @override
  Widget build(BuildContext context) {
    final spendingAsync = ref.watch(spendingByCategoryProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Spending Breakdown',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: spendingAsync.when(
                  data: (data) {
                    if (data.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.pie_chart_outline, size: 64, color: Colors.grey.shade600),
                            const SizedBox(height: 16),
                            Text(
                              'No expense data available',
                              style: GoogleFonts.poppins(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }
                    return _buildChart(context, data);
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: Colors.teal)),
                  error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context, Map<String, double> data) {
    final total = data.values.fold(0.0, (sum, item) => sum + item);
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        SizedBox(
          height: 250,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 50,
              pieTouchData: PieTouchData(
                enabled: true,
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });

                  // Handle tap events
                  if (event is FlTapUpEvent && pieTouchResponse != null) {
                    final touchedSection = pieTouchResponse.touchedSection;
                    if (touchedSection != null && touchedSection.touchedSectionIndex >= 0) {
                      final index = touchedSection.touchedSectionIndex;
                      if (index < sortedEntries.length) {
                        final categoryName = sortedEntries[index].key;
                        _showCategoryTransactions(context, categoryName);
                      }
                    }
                  }
                },
              ),
              sections: sortedEntries.asMap().entries.map((entry) {
                final index = entry.key;
                final e = entry.value;
                final percentage = (e.value / total) * 100;
                final isTouched = index == touchedIndex;
                final radius = isTouched ? 110.0 : 100.0;

                return PieChartSectionData(
                  color: _getColor(e.key),
                  value: e.value,
                  title: '${percentage.toStringAsFixed(0)}%',
                  radius: radius,
                  titleStyle: TextStyle(
                    fontSize: isTouched ? 16 : 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Legend text
        Text(
          'Tap a category to see transactions',
          style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 12),
        ),
        
        const SizedBox(height: 16),
        
        // Category List (also clickable)
        Expanded(
          child: ListView.builder(
            itemCount: sortedEntries.length,
            itemBuilder: (context, index) {
              final entry = sortedEntries[index];
              final currency = NumberFormat.simpleCurrency(name: 'INR', decimalDigits: 0);
              final percentage = (entry.value / total) * 100;
              
              return Card(
                color: Colors.grey.shade900,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getColor(entry.key),
                    radius: 12,
                  ),
                  title: Text(
                    entry.key,
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '${percentage.toStringAsFixed(1)}% of spending',
                    style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  trailing: Text(
                    currency.format(entry.value),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  onTap: () => _showCategoryTransactions(context, entry.key),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCategoryTransactions(BuildContext context, String category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CategoryTransactionsSheet(category: category),
    );
  }

  Color _getColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Colors.orange;
      case 'transport':
        return Colors.blue;
      case 'shopping':
        return Colors.purple;
      case 'fuel':
        return Colors.red;
      case 'health':
        return Colors.green;
      case 'bills':
        return Colors.cyan;
      case 'entertainment':
        return Colors.pink;
      case 'friends & family':
        return Colors.amber;
      case 'uncategorized':
        return Colors.grey;
      default:
        return Colors.grey.shade600;
    }
  }
}

// ============================================================================
// Category Transactions Bottom Sheet
// ============================================================================

class CategoryTransactionsSheet extends ConsumerStatefulWidget {
  final String category;

  const CategoryTransactionsSheet({super.key, required this.category});

  @override
  ConsumerState<CategoryTransactionsSheet> createState() => _CategoryTransactionsSheetState();
}

class _CategoryTransactionsSheetState extends ConsumerState<CategoryTransactionsSheet> {
  final currencyFormat = NumberFormat.simpleCurrency(name: 'INR', decimalDigits: 0);
  final dateFormat = DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    // ⭐ Use FILTERED transactions (respects saved date range)
    final transactionsAsync = ref.watch(filteredTransactionListProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getCategoryColor(widget.category).withOpacity(0.2),
                  child: Text(
                    _getCategoryEmoji(widget.category),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.category} Transactions',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Tap to edit • Swipe to close',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          Divider(color: Colors.grey.shade800),
          
          // Transactions List
          Expanded(
            child: transactionsAsync.when(
              data: (transactions) {
                final filtered = transactions
                    .where((t) => t.category.toLowerCase() == widget.category.toLowerCase())
                    .toList();
                
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade600),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions found',
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                
                // Calculate total
                final total = filtered.fold(0.0, (sum, t) => sum + t.amount);
                
                return Column(
                  children: [
                    // Total banner
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(widget.category).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _getCategoryColor(widget.category).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${filtered.length} transactions',
                            style: GoogleFonts.poppins(color: Colors.white70),
                          ),
                          Text(
                            'Total: ${currencyFormat.format(total)}',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final tx = filtered[index];
                          return Card(
                            color: Colors.grey.shade900,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: tx.type == TransactionType.income
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.red.withOpacity(0.2),
                                child: Icon(
                                  tx.type == TransactionType.income
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  color: tx.type == TransactionType.income
                                      ? Colors.green
                                      : Colors.red,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                tx.merchant ?? 'Unknown',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                dateFormat.format(tx.timestamp),
                                style: GoogleFonts.poppins(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    currencyFormat.format(tx.amount),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: tx.type == TransactionType.income
                                          ? Colors.green
                                          : Colors.redAccent,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.edit, size: 16, color: Colors.grey.shade500),
                                ],
                              ),
                              onTap: () => _showEditDialog(context, ref, tx),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Colors.teal)),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Transaction tx) async {
    // ✅ Load categories first
    final categoryService = ref.read(categoryServiceProvider);
    final allCategories = await categoryService.getAllCategoryNames();
    
    final amountController = TextEditingController(text: tx.amount.toStringAsFixed(0));
    final merchantController = TextEditingController(text: tx.merchant ?? '');
    
    // Ensure current category is in list
    final categories = <String>{
      ...allCategories,
      tx.category,
    }.toList()..sort();
    
    String selectedCategory = tx.category;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Edit Transaction',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _confirmDelete(dialogContext, ref, tx),
                tooltip: 'Delete',
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Transaction info header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          tx.type == TransactionType.income ? Icons.arrow_downward : Icons.arrow_upward,
                          color: tx.type == TransactionType.income ? Colors.green : Colors.redAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tx.merchant ?? 'Unknown',
                            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Amount field
                  Text('Amount', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      prefixStyle: GoogleFonts.poppins(color: Colors.teal, fontSize: 16),
                      filled: true,
                      fillColor: const Color(0xFF2E2E2E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.teal, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Description field
                  Text('Description', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: merchantController,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                    maxLines: 2,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF2E2E2E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.teal, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Category dropdown
                  Text('Category', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E2E2E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCategory,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF2E2E2E),
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
                        items: categories.map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        )).toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedCategory = value!);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // ⭐ Lending Options Card (show only for Friends & Family)
                  if (selectedCategory == 'Friends & Family') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange, width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.handshake, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Lending Options',
                                style: GoogleFonts.poppins(
                                  color: Colors.orange,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Track money lent to friends',
                            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // Lent Button
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Text('💸', style: TextStyle(fontSize: 16)),
                                  label: Text('Lent', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: tx.lendingType == LendingType.lent 
                                        ? Colors.orange 
                                        : Colors.orange.withOpacity(0.3),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final updated = tx.copyWith(
                                      isLending: true,
                                      lendingType: LendingType.lent,
                                      category: 'Friends & Family',
                                    );
                                    await ref.read(appDatabaseProvider).update(ref.read(appDatabaseProvider).transactions).replace(updated);
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Marked as lent 💸'), backgroundColor: Colors.orange),
                                      );
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Returned Button
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Text('💰', style: TextStyle(fontSize: 16)),
                                  label: Text('Returned', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: tx.lendingType == LendingType.returned 
                                        ? Colors.green 
                                        : Colors.green.withOpacity(0.3),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final updated = tx.copyWith(
                                      isLending: true,
                                      lendingType: LendingType.returned,
                                      category: 'Friends & Family',
                                    );
                                    await ref.read(appDatabaseProvider).update(ref.read(appDatabaseProvider).transactions).replace(updated);
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Marked as returned 💰'), backgroundColor: Colors.green),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            // Cancel button
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            // Save button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid amount')),
                  );
                  return;
                }
                
                // Create updated transaction
                final updated = tx.copyWith(
                  amount: amount,
                  merchant: Value(merchantController.text.trim().isEmpty ? null : merchantController.text.trim()),
                  category: selectedCategory,
                );
                
                await ref.read(appDatabaseProvider).update(ref.read(appDatabaseProvider).transactions).replace(updated);
                
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Transaction updated ✓')),
                  );
                }
              },
              child: Text('Save', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext dialogContext, WidgetRef ref, Transaction tx) {
    showDialog(
      context: dialogContext,
      builder: (confirmContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Delete Transaction?', style: GoogleFonts.poppins(color: Colors.white)),
        content: Text(
          'This action cannot be undone.',
          style: GoogleFonts.poppins(color: Colors.grey.shade400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmContext),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              await (ref.read(appDatabaseProvider).delete(ref.read(appDatabaseProvider).transactions)
                ..where((t) => t.id.equals(tx.id))).go();
              
              if (confirmContext.mounted) Navigator.pop(confirmContext);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Transaction deleted')),
              );
            },
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Colors.orange;
      case 'transport':
        return Colors.blue;
      case 'shopping':
        return Colors.purple;
      case 'fuel':
        return Colors.red;
      case 'health':
        return Colors.green;
      case 'bills':
        return Colors.cyan;
      case 'entertainment':
        return Colors.pink;
      case 'friends & family':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _getCategoryEmoji(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return '🍔';
      case 'transport':
        return '🚗';
      case 'shopping':
        return '🛒';
      case 'fuel':
        return '⛽';
      case 'health':
        return '💊';
      case 'bills':
        return '📄';
      case 'entertainment':
        return '🎬';
      case 'friends & family':
        return '👥';
      case 'uncategorized':
        return '❓';
      default:
        return '💰';
    }
  }
}

