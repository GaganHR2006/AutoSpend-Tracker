import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database.dart';
import '../../categories/data/categories.dart';
import '../data/transaction_repository.dart';

class QuickCategorizeSheet extends ConsumerStatefulWidget {
  final List<Transaction> transactions;
  
  const QuickCategorizeSheet({
    super.key,
    required this.transactions,
  });

  @override
  ConsumerState<QuickCategorizeSheet> createState() => _QuickCategorizeSheetState();
}

class _QuickCategorizeSheetState extends ConsumerState<QuickCategorizeSheet> {
  int currentIndex = 0;
  final ScrollController _scrollController = ScrollController();
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (currentIndex >= widget.transactions.length) {
      return _buildCompletionScreen();
    }
    
    final transaction = widget.transactions[currentIndex];
    final progress = (currentIndex + 1) / widget.transactions.length;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Drag Handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade600,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quick Categorize',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${currentIndex + 1} / ${widget.transactions.length}',
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade400,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.shade800,
                      color: Colors.teal,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(progress * 100).toInt()}% complete',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            
            Divider(color: Colors.grey.shade800),
            
            // Transaction Card
            _buildTransactionCard(transaction),
            
            const SizedBox(height: 16),
            
            Text(
              'Select Category:',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade300,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Category Grid (2 columns)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.8,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: forQuickCategorize.length,
                itemBuilder: (context, index) {
                  final category = forQuickCategorize[index];
                  return _buildCategoryButton(category);
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Skip button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _skip,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.grey.shade600),
                    foregroundColor: Colors.grey.shade400,
                  ),
                  child: Text('Skip', style: GoogleFonts.poppins(fontSize: 16)),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTransactionCard(Transaction transaction) {
    final currencyFormat = NumberFormat.simpleCurrency(name: 'INR', decimalDigits: 0);
    final isIncome = transaction.type == TransactionType.income;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Column(
        children: [
          // Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.orange.shade900.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.help_outline,
              size: 40,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 16),
          // Merchant
          Text(
            transaction.merchant ?? 'Unknown',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Amount
          Text(
            currencyFormat.format(transaction.amount),
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: isIncome ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
          const SizedBox(height: 4),
          // Date
          Text(
            _formatDate(transaction.timestamp),
            style: GoogleFonts.poppins(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCategoryButton(TransactionCategory category) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _categorize(category.name),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: category.color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: category.color.withOpacity(0.4)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                category.emoji,
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(height: 4),
              Text(
                category.name,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildCompletionScreen() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 100, color: Colors.green),
          const SizedBox(height: 24),
          Text(
            'All Done!',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'All transactions have been categorized',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: Text('Close', style: GoogleFonts.poppins(fontSize: 16)),
          ),
        ],
      ),
    );
  }
  
  Future<void> _categorize(String category) async {
    try {
      final transaction = widget.transactions[currentIndex];
      await ref.read(transactionRepositoryProvider).updateCategory(
        transaction.id,
        category,
      );
      
      setState(() {
        currentIndex++;
      });
      
      // ⭐ AUTO-SCROLL TO TOP
      if (currentIndex < widget.transactions.length) {
        await Future.delayed(const Duration(milliseconds: 100));
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to categorize: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _skip() {
    setState(() {
      currentIndex++;
    });
    
    // ⭐ AUTO-SCROLL TO TOP
    if (currentIndex < widget.transactions.length) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }
  
  String _formatDate(DateTime date) {
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    return dateFormat.format(date);
  }
}
