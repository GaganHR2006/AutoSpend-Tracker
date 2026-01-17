import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class BudgetProgressCard extends StatelessWidget {
  final String category;
  final double spent;
  final double limit;
  final double percentage;
  final VoidCallback? onTap;
  final bool isCompact;

  const BudgetProgressCard({
    super.key,
    required this.category,
    required this.spent,
    required this.limit,
    required this.percentage,
    this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.simpleCurrency(name: 'INR', decimalDigits: 0);
    final color = _getColorForPercentage(percentage);
    final icon = _getIconForCategory(category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: isCompact ? 8 : 16,
          vertical: isCompact ? 4 : 8,
        ),
        padding: EdgeInsets.all(isCompact ? 16 : 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.2), Colors.black87],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(isCompact ? 16 : 20),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: isCompact ? 16 : 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatCategoryName(category),
                        style: GoogleFonts.poppins(
                          fontSize: isCompact ? 14 : 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (!isCompact)
                        Text(
                          '${percentage.toStringAsFixed(0)}% used',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),
                if (percentage >= 100)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'EXCEEDED',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Amount display
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  currencyFormat.format(spent),
                  style: GoogleFonts.poppins(
                    fontSize: isCompact ? 18 : 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  'of ${currencyFormat.format(limit)}',
                  style: GoogleFonts.poppins(
                    fontSize: isCompact ? 12 : 14,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (percentage / 100).clamp(0.0, 1.0),
                minHeight: isCompact ? 6 : 8,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),

            // Remaining amount (only if not compact)
            if (!isCompact) ...[
              const SizedBox(height: 8),
              Text(
                _getRemainingText(spent, limit),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white60,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getColorForPercentage(double percentage) {
    if (percentage >= 100) return Colors.red;
    if (percentage >= 80) return Colors.deepOrange;
    if (percentage >= 50) return Colors.orange;
    return Colors.green;
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'TOTAL_MONTHLY':
        return Icons.calendar_month;
      case 'CREDIT_CARD':
        return Icons.credit_card;
      case 'Food':
        return Icons.restaurant;
      case 'Transport':
        return Icons.directions_car;
      case 'Shopping':
        return Icons.shopping_bag;
      case 'Bills':
        return Icons.receipt;
      case 'Entertainment':
        return Icons.movie;
      case 'Health':
        return Icons.medical_services;
      default:
        return Icons.category;
    }
  }

  String _formatCategoryName(String category) {
    if (category == 'TOTAL_MONTHLY') return 'Monthly Budget';
    if (category == 'CREDIT_CARD') return 'Credit Card';
    return category;
  }

  String _getRemainingText(double spent, double limit) {
    final remaining = limit - spent;
    if (remaining > 0) {
      return '${NumberFormat.simpleCurrency(name: 'INR', decimalDigits: 0).format(remaining)} remaining';
    } else {
      return 'Over budget by ${NumberFormat.simpleCurrency(name: 'INR', decimalDigits: 0).format(remaining.abs())}';
    }
  }
}
