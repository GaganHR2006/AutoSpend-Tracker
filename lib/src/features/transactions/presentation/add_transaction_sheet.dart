import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../src/core/database/database.dart';
import '../data/transaction_repository.dart';

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

  final List<String> _categories = [
    'Uncategorized', 'Food', 'Transport', 'Shopping', 'Bills', 'Entertainment', 'Health', 'Salary', 'Investment'
  ];

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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Form(
        key: _formKey,
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

            // Category & Date Row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) => setState(() => _category = val!),
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
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
                      child: Text(DateFormat('MMM d').format(_date)),
                    ),
                  ),
                ),
              ],
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
    );
  }
}
