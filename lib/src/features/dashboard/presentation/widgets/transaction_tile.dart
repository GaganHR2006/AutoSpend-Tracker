import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database.dart';
import '../../../transactions/presentation/add_transaction_sheet.dart';

class TransactionTile extends StatelessWidget {
  final Transaction transaction;

  const TransactionTile({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.simpleCurrency(name: 'INR', decimalDigits: 0);
    final dateFormat = DateFormat('MMM d, h:mm a');
    final isIncome = transaction.type == TransactionType.income;
    final merchantName = transaction.merchant ?? 'Unknown';
    final firstLetter = merchantName.isNotEmpty ? merchantName[0].toUpperCase() : '?';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(77),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => AddTransactionSheet(transaction: transaction),
          );
        },
        leading: CircleAvatar(
          backgroundColor: isIncome ? Colors.teal.withAlpha(51) : Colors.red.withAlpha(51),
          child: Text(
            firstLetter,
            style: TextStyle(
              color: isIncome ? Colors.teal : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          merchantName,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          dateFormat.format(transaction.timestamp),
          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        ),
        trailing: Text(
          currencyFormat.format(transaction.amount),
          style: TextStyle(
            color: isIncome ? Colors.greenAccent : Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
