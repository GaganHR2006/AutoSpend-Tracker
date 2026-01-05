import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../data/dashboard_providers.dart';
import 'widgets/transaction_tile.dart';
import '../../transactions/presentation/quick_categorize_sheet.dart';
import '../../transactions/data/transaction_repository.dart';

// --- LOCAL PROVIDERS ---
final displayCountProvider = StateProvider<int>((ref) => 100);

// Provider for uncategorized count
final uncategorizedCountProvider = Provider<int>((ref) {
  final transactionsAsync = ref.watch(transactionListProvider);
  return transactionsAsync.when(
    data: (list) => list.where((t) => t.category == 'Uncategorized').length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(totalBalanceProvider);
    final transactionsAsync = ref.watch(filteredTransactionListProvider);
    final displayCount = ref.watch(displayCountProvider);
    final uncategorizedCount = ref.watch(uncategorizedCountProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // 1. Balance Card
          SliverToBoxAdapter(
            child: _buildSummaryCard(context, balanceAsync),
          ),
          
          // 2. Uncategorized Banner (if any)
          if (uncategorizedCount > 0)
            SliverToBoxAdapter(
              child: _buildUncategorizedBanner(context, ref, uncategorizedCount),
            ),
          
          // 3. THE FILTER BAR (Neon Style ⚡)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 15.0, bottom: 10.0),
              child: TransactionFilterBar(), 
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Recent Transactions',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),

          // 4. The List
          transactionsAsync.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No transactions found', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                );
              }
              
              final actualDisplayCount = displayCount > transactions.length ? transactions.length : displayCount;
              final hasMore = transactions.length > displayCount;
              
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index < actualDisplayCount) {
                      return TransactionTile(transaction: transactions[index]);
                    } else if (index == actualDisplayCount && hasMore) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: ElevatedButton(
                            onPressed: () => ref.read(displayCountProvider.notifier).state += 100,
                            child: const Text("Load More"),
                          ),
                        ),
                      );
                    }
                    return null;
                  },
                  childCount: hasMore ? actualDisplayCount + 1 : actualDisplayCount,
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: LinearProgressIndicator()),
            error: (err, stack) => SliverToBoxAdapter(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, AsyncValue<double> balanceAsync) {
    final currencyFormat = NumberFormat.simpleCurrency(name: 'INR', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade800, Colors.black87],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          balanceAsync.when(
            data: (balance) {
              final isNegative = balance < 0;
              final isSavings = balance > 0;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isNegative ? 'Net Spending' : 'Net Savings',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        isNegative ? Icons.trending_down : Icons.trending_up,
                        color: isNegative ? Colors.red[300] : Colors.green[300],
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currencyFormat.format(balance.abs()),
                        style: GoogleFonts.poppins(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: isNegative ? Colors.red[300] : Colors.green[300],
                        ),
                      ),
                    ],
                  ),
                  if (isNegative)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('You spent more than you earned', style: GoogleFonts.poppins(color: Colors.red[200], fontSize: 12)),
                    ),
                  if (isSavings)
                     Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('You saved money this period! 🎉', style: GoogleFonts.poppins(color: Colors.green[200], fontSize: 12)),
                    ),
                ],
              );
            },
            loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const Text('---', style: TextStyle(color: Colors.white, fontSize: 40)),
          ),
        ],
      ),
    );
  }

  // ⭐ Uncategorized Banner - Opens Quick Categorize
  Widget _buildUncategorizedBanner(BuildContext context, WidgetRef ref, int count) {
    return GestureDetector(
      onTap: () async {
        final uncategorized = await ref.read(transactionRepositoryProvider).getUncategorizedTransactions();
        
        if (uncategorized.isEmpty) return;

        if (context.mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => QuickCategorizeSheet(transactions: uncategorized),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade700, Colors.deepOrange.shade800],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.category_outlined, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count Uncategorized',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'Tap to categorize quickly',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

// ==============================================================================
// 🚀 THE NEON FILTER BAR
// ==============================================================================

class TransactionFilterBar extends ConsumerWidget {
  const TransactionFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFilter = ref.watch(transactionFilterProvider);
    final isCustomSelected = selectedFilter == TransactionTimeFilter.customRange;

    final filters = [
      {'label': 'This Month', 'value': TransactionTimeFilter.thisMonth},
      {'label': 'Last Month', 'value': TransactionTimeFilter.lastMonth},
      {'label': 'Last 3 Months', 'value': TransactionTimeFilter.last3Months},
      {'label': 'Last 6 Months', 'value': TransactionTimeFilter.last6Months},
      {'label': 'All Time', 'value': TransactionTimeFilter.allTime},
    ];

    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ...filters.map((filter) {
            final isSelected = selectedFilter == filter['value'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filter['label'] as String),
                selected: isSelected,
                showCheckmark: false,
                selectedColor: const Color(0xFF00E5FF), // NEON TEAL
                labelStyle: TextStyle(
                  color: isSelected ? Colors.black : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade800),
                ),
                onSelected: (bool selected) {
                  if (selected) {
                    ref.read(transactionFilterProvider.notifier).state = filter['value'] as TransactionTimeFilter;
                  }
                },
              ),
            );
          }),
          
          // Custom Button
           Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text("Custom Range"),
              selected: isCustomSelected,
              showCheckmark: false,
              selectedColor: const Color(0xFFFF4081), // NEON PINK
              labelStyle: TextStyle(
                color: isCustomSelected ? Colors.black : const Color(0xFFFF4081),
                fontWeight: FontWeight.bold,
              ),
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
                side: BorderSide(color: isCustomSelected ? Colors.transparent : Colors.grey.shade800),
              ),
              onSelected: (bool selected) async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF00E5FF), onPrimary: Colors.black, surface: Color(0xFF1E1E1E))),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  ref.read(customDateRangeProvider.notifier).state = picked;
                  ref.read(transactionFilterProvider.notifier).state = TransactionTimeFilter.customRange;
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
