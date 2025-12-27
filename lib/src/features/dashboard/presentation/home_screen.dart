import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../data/dashboard_providers.dart';
import 'widgets/transaction_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(totalBalanceProvider);
    final transactionsAsync = ref.watch(recentTransactionsProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildSummaryCard(context, balanceAsync),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Recent Transactions',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
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
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => TransactionTile(transaction: transactions[index]),
                childCount: transactions.length,
              ),
            );
          },
          loading: () => const SliverToBoxAdapter(child: LinearProgressIndicator()),
          error: (err, stack) => SliverToBoxAdapter(child: Text('Error: $err')),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 80)), // Fab/Nav spacing
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, AsyncValue<double> balanceMethods) {
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
          BoxShadow(color: Colors.teal.withAlpha(77), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Balance', style: GoogleFonts.poppins(color: Colors.white70)),
          const SizedBox(height: 8),
          balanceMethods.when(
            data: (balance) => Text(
              currencyFormat.format(balance),
              style: GoogleFonts.poppins(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(color: Colors.white))),
            error: (_, __) => const Text('---', style: TextStyle(color: Colors.white, fontSize: 40)),
          ),
        ],
      ),
    );
  }
}
