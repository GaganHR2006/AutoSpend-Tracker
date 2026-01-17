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

    // ✅ Determine source from smsId
    String source = 'Manual';
    Color sourceColor = Colors.grey;
    IconData sourceIcon = Icons.edit;
    
    if (transaction.smsId != null) {
      if (transaction.smsId!.startsWith('sms_')) {
        source = 'SMS';
        sourceColor = Colors.blue;
        sourceIcon = Icons.sms;
      } else if (transaction.smsId!.startsWith('notif_')) {
        source = 'Notification';
        sourceColor = Colors.orange;
        sourceIcon = Icons.notifications;
      } else if (transaction.smsId!.startsWith('manual_')) {
        source = 'Manual';
        sourceColor = Colors.grey;
        sourceIcon = Icons.edit;
      }
    }

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
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: isIncome ? Colors.teal.withAlpha(51) : Colors.red.withAlpha(51),
              child: Text(
                firstLetter,
                style: TextStyle(
                  color: isIncome ? Colors.teal : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // ✅ Source badge
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: sourceColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1),
                ),
                child: Icon(
                  sourceIcon,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
          ],
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
