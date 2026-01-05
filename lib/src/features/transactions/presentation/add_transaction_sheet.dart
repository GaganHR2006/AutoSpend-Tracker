import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import 'package:google_fonts/google_fonts.dart';
import '../../../../src/core/database/database.dart';
import '../data/transaction_repository.dart';
import '../../categories/data/categories.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  final Transaction? transaction;

  const AddTransactionSheet({super.key, this.transaction});

  @override
  ConsumerState<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  
  TransactionType _type = TransactionType.expense;
  String _category = 'Uncategorized';
  DateTime _date = DateTime.now();
  
  // ⭐ Lending fields
  bool _isLending = false;
  LendingType _lendingType = LendingType.none;

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      final tx = widget.transaction!;
      _amountController.text = tx.amount.toString();
      _merchantController.text = tx.merchant ?? '';
      _type = tx.type;
      _category = tx.category;
      _date = tx.timestamp;
      _isLending = tx.isLending;
      _lendingType = tx.lendingType;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final merchant = _merchantController.text.trim();
    final repo = ref.read(transactionRepositoryProvider);

    try {
      if (widget.transaction == null) {
        // Add
        final entry = TransactionsCompanion(
          smsId: drift.Value('manual_${DateTime.now().millisecondsSinceEpoch}'),
          amount: drift.Value(amount),
          merchant: drift.Value(merchant.isEmpty ? null : merchant),
          category: drift.Value(_category),
          type: drift.Value(_type),
          timestamp: drift.Value(_date),
          isManual: const drift.Value(true),
          isLending: drift.Value(_isLending),
          lendingType: drift.Value(_lendingType),
        );
        await repo.addTransaction(entry);
      } else {
        // Update
        final entry = widget.transaction!.copyWith(
          amount: amount,
          merchant: drift.Value(merchant.isEmpty ? null : merchant),
          category: _category,
          type: _type,
          timestamp: _date,
          isLending: _isLending,
          lendingType: _lendingType,
        );
        await repo.updateTransaction(entry);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _delete() async {
    if (widget.transaction == null) return;
    try {
      await ref.read(transactionRepositoryProvider).deleteTransaction(widget.transaction!.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFriendsFamily = _category == 'Friends & Family';
    
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.transaction == null ? 'Add Transaction' : 'Edit Transaction',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || double.tryParse(val) == null ? 'Enter valid amount' : null,
              ),
              const SizedBox(height: 16),

              // Type Segmented Button
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(value: TransactionType.expense, label: Text('Expense'), icon: Icon(Icons.arrow_downward)),
                  ButtonSegment(value: TransactionType.income, label: Text('Income'), icon: Icon(Icons.arrow_upward)),
                ],
                selected: {_type},
                onSelectionChanged: (newSelection) {
                  setState(() => _type = newSelection.first);
                },
              ),
              const SizedBox(height: 16),

              // Merchant
              TextFormField(
                controller: _merchantController,
                decoration: const InputDecoration(
                  labelText: 'Merchant / Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Category Dropdown - Using enhanced categories
              DropdownButtonFormField<String>(
                value: categoryNames.contains(_category) ? _category : 'Uncategorized',
                items: categoryNames.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  setState(() {
                    _category = val!;
                    // Reset lending if not Friends & Family
                    if (_category != 'Friends & Family') {
                      _isLending = false;
                      _lendingType = LendingType.none;
                    }
                  });
                },
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),

              // ⭐ LENDING SECTION - Only for Friends & Family
              if (isFriendsFamily) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade900.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade700.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.handshake, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Lending Tracker',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Is this a lending transaction?',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildLendingButton(
                              icon: Icons.call_made,
                              label: '💸 Lent',
                              isSelected: _lendingType == LendingType.lent,
                              color: Colors.red,
                              onTap: () {
                                setState(() {
                                  _isLending = true;
                                  _lendingType = LendingType.lent;
                                  _type = TransactionType.expense;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildLendingButton(
                              icon: Icons.call_received,
                              label: '💰 Returned',
                              isSelected: _lendingType == LendingType.returned,
                              color: Colors.green,
                              onTap: () {
                                setState(() {
                                  _isLending = true;
                                  _lendingType = LendingType.returned;
                                  _type = TransactionType.income;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildLendingButton(
                              icon: Icons.close,
                              label: 'None',
                              isSelected: _lendingType == LendingType.none,
                              color: Colors.grey,
                              onTap: () {
                                setState(() {
                                  _isLending = false;
                                  _lendingType = LendingType.none;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Date Picker
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()),
                  child: Text(DateFormat('MMM d, yyyy').format(_date)),
                ),
              ),
              const SizedBox(height: 24),

              FilledButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
              
              if (widget.transaction != null)
                TextButton(
                  onPressed: _delete,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete Transaction'),
                ),
                
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLendingButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade700,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
