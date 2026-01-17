import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../data/dashboard_providers.dart';
import 'widgets/transaction_tile.dart';
import '../../transactions/presentation/quick_categorize_sheet.dart';
import '../../transactions/presentation/add_transaction_sheet.dart'; // Assumed import
import '../../transactions/data/transaction_repository.dart';
import '../../budget/data/budget_repository.dart';
import '../../budget/presentation/widgets/budget_progress_card.dart';
import '../../budget/presentation/budget_settings_screen.dart';

// --- LOCAL PROVIDERS ---
final displayCountProvider = StateProvider<int>((ref) => 100);

// Provider for uncategorized count
final uncategorizedCountProvider = Provider<int>((ref) {
  final transactionsAsync = ref.watch(filteredTransactionListProvider);
  return transactionsAsync.when(
    data: (list) {
      return list.where((t) => t.category == 'Uncategorized').length;
    },
    loading: () => 0,
    error: (_, __) => 0,
  );
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Invalidate all transaction-related providers
      ref.invalidate(transactionListProvider);
      ref.invalidate(filteredTransactionListProvider);
      ref.invalidate(filteredBalanceProvider);
      ref.invalidate(lendingSummaryProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(filteredBalanceProvider);
    final transactionsAsync = ref.watch(filteredTransactionListProvider);
    final displayCount = ref.watch(displayCountProvider);
    final uncategorizedCount = ref.watch(uncategorizedCountProvider);
    final lendingSummaryAsync = ref.watch(lendingSummaryProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        onRefresh: () async {
          // Invalidate all providers to force refresh
          ref.invalidate(transactionListProvider);
          ref.invalidate(filteredTransactionListProvider);
          ref.invalidate(filteredBalanceProvider);
          ref.invalidate(lendingSummaryProvider);
          
          // Wait for providers to rebuild
          await Future.delayed(const Duration(milliseconds: 500));
        },
        color: Colors.teal,
        backgroundColor: Colors.black,
        child: CustomScrollView(
        slivers: [
          // 1. Balance Card
          SliverToBoxAdapter(
            child: _buildSummaryCard(context, balanceAsync),
          ),
          
          // 2. Lending Summary Card
          SliverToBoxAdapter(
            child: _buildLendingSummaryCard(context, lendingSummaryAsync),
          ),
          
          // 2.5. Budget Overview (if budgets set)
          SliverToBoxAdapter(
            child: _buildBudgetOverview(context, ref),
          ),
          
          // 3. Uncategorized Banner (if any)
          if (uncategorizedCount > 0)
            SliverToBoxAdapter(
              child: _buildUncategorizedBanner(context, ref, uncategorizedCount),
            ),

          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Text(
                    'Recent Transactions',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Spacer(),
                  // ✅ Legend
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSourceBadge(Icons.sms, Colors.blue, 'SMS'),
                      const SizedBox(width: 6),
                      _buildSourceBadge(Icons.notifications, Colors.orange, 'Notif'),
                      const SizedBox(width: 6),
                      _buildSourceBadge(Icons.edit, Colors.grey, 'Manual'),
                    ],
                  ),
                ],
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
      ),  // ✅ RefreshIndicator
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

  // ⭐ Lending Summary Card
  Widget _buildLendingSummaryCard(BuildContext context, AsyncValue<Map<String, double>> lendingAsync) {
    final currencyFormat = NumberFormat.simpleCurrency(name: 'INR', decimalDigits: 0);

    return lendingAsync.when(
      data: (data) {
        final lent = data['lent'] ?? 0.0;
        final returned = data['returned'] ?? 0.0;
        final outstanding = lent - returned;
        
        // Don't show if no lending activity
        if (lent <= 0 && returned <= 0) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade700, Colors.deepOrange.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.handshake, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Money Lent', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                currencyFormat.format(outstanding > 0 ? outstanding : 0),
                style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              if (outstanding > 0)
                Text(
                  'Outstanding from friends',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("💸 Lent", style: TextStyle(color: Colors.white60, fontSize: 11)),
                      Text(currencyFormat.format(lent), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  )),
                  Container(width: 1, height: 30, color: Colors.white24),
                  const SizedBox(width: 16),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("💰 Returned", style: TextStyle(color: Colors.white60, fontSize: 11)),
                      Text(currencyFormat.format(returned), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  )),
                ],
              )
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ⭐ Budget Overview Section
  Widget _buildBudgetOverview(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<BudgetUsage>>(
      future: _getBudgetUsages(ref),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final usages = snapshot.data!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Budget Overview',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BudgetSettingsScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Manage',
                      style: GoogleFonts.poppins(color: Colors.teal),
                    ),
                  ),
                ],
              ),
            ),
            ...usages.take(3).map((usage) => BudgetProgressCard(
              category: usage.category,
              spent: usage.spent,
              limit: usage.limit,
              percentage: usage.percentage,
              isCompact: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BudgetSettingsScreen(),
                  ),
                );
              },
            )),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Future<List<BudgetUsage>> _getBudgetUsages(WidgetRef ref) async {
    final budgetRepo = ref.read(budgetRepositoryProvider);
    final budgets = await budgetRepo.getBudgets();
    
    if (budgets.isEmpty) return [];

    final usages = <BudgetUsage>[];
    
    // Priority order: TOTAL_MONTHLY, CREDIT_CARD, then categories sorted by percentage
    for (final budget in budgets) {
      if (!budget.isActive) continue;
      
      final usage = await budgetRepo.calculateUsage(budget.category);
      usages.add(usage);
    }

    // Sort: Special categories first (TOTAL_MONTHLY, CREDIT_CARD), then by percentage descending
    usages.sort((a, b) {
      // TOTAL_MONTHLY always first
      if (a.category == 'TOTAL_MONTHLY') return -1;
      if (b.category == 'TOTAL_MONTHLY') return 1;
      
      // CREDIT_CARD second
      if (a.category == 'CREDIT_CARD') return -1;
      if (b.category == 'CREDIT_CARD') return 1;
      
      // Others sorted by percentage (highest first)
      return b.percentage.compareTo(a.percentage);
    });

    return usages;
  }

  // ⭐ Uncategorized Banner - Opens Quick Categorize
  Widget _buildUncategorizedBanner(BuildContext context, WidgetRef ref, int count) {
    return GestureDetector(
      onTap: () async {
        print('🔍 Uncategorized banner tapped! Count: $count');
        
        final uncategorized = await ref.read(transactionRepositoryProvider).getUncategorizedTransactions();
        print('📊 Found ${uncategorized.length} uncategorized transactions');
        
        if (uncategorized.isEmpty) {
          print('⚠️ No uncategorized transactions found');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('All transactions are categorized! 🎉'),
                backgroundColor: Colors.green,
              ),
            );
          }
          return;
        }

        if (context.mounted) {
          print('✅ Opening Quick Categorize sheet...');
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (sheetContext) => QuickCategorizeSheet(transactions: uncategorized),
          );
        } else {
          print('❌ Context not mounted!');
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

  // ✅ Helper method for source badge legend
  Widget _buildSourceBadge(IconData icon, Color color, String label) {
    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600),
            ),
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
