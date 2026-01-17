import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database.dart';
import '../../categories/data/categories.dart';
import '../../categories/data/category_service.dart';
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
  
  // ✅ Dynamic categories loaded from CategoryService
  List<TransactionCategory> _sortedCategories = [];
  bool _categoriesLoaded = false;
  
  @override
  void initState() {
    super.initState();
    _loadCategories();
  }
  
  Future<void> _loadCategories() async {
    final categoryService = ref.read(categoryServiceProvider);
    final allCategoryNames = await categoryService.getAllCategoryNames();
    
    // Convert names to TransactionCategory objects
    final categories = allCategoryNames
        .where((name) => name != 'Uncategorized')
        .map((name) {
          final predefined = getCategoryByName(name);
          return predefined ?? TransactionCategory(name, '📁', Colors.grey);
        })
        .toList();
    
    setState(() {
      _sortedCategories = categories;
      _categoriesLoaded = true;
    });
  }
  
  List<TransactionCategory> get sortedCategories => _sortedCategories;
  
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
            
            
            // Category List (single column for better scannability)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Category:',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Single column list with larger touch targets
                  if (!_categoriesLoaded)
                    const Center(child: CircularProgressIndicator(color: Colors.teal))
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sortedCategories.length + 1,
                      itemBuilder: (context, index) {
                        // Custom button at the end
                        if (index == sortedCategories.length) {
                          return _buildCustomCategoryButtonList();
                        }
                        final category = sortedCategories[index];
                        return _buildCategoryButtonList(category);
                      },
                    ),
                ],
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
  
  Widget _buildCustomCategoryButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showCustomCategoryDialog(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_circle_outline, color: Colors.purple, size: 28),
              const SizedBox(height: 4),
              Text(
                'Custom',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.purple,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // New list-style category button
  Widget _buildCategoryButtonList(TransactionCategory category) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _categorize(category.name),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: category.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: category.color.withOpacity(0.3), width: 1.5),
            ),
            child: Row(
              children: [
                // Emoji in a circle
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: category.color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      category.emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Category name
                Expanded(
                  child: Text(
                    category.name,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Arrow icon
                Icon(
                  Icons.arrow_forward_ios,
                  color: category.color.withOpacity(0.6),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // New list-style custom category button
  Widget _buildCustomCategoryButtonList() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showCustomCategoryDialog(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.withOpacity(0.4), width: 2),
            ),
            child: Row(
              children: [
                // Plus icon in a circle
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.add_circle_outline,
                      color: Colors.purple,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Label
                Expanded(
                  child: Text(
                    'Custom Category',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple,
                    ),
                  ),
                ),
                // Arrow icon
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.purple.withOpacity(0.6),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _showCustomCategoryDialog() {
    final TextEditingController categoryController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Custom Category',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter a custom category name for this transaction',
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: categoryController,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g., Car Maintenance',
                hintStyle: GoogleFonts.poppins(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF2E2E2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.purple, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final customCategory = categoryController.text.trim();
              if (customCategory.isNotEmpty) {
                Navigator.pop(dialogContext);
                _categorize(customCategory);
              }
            },
            child: Text('Save', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
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
