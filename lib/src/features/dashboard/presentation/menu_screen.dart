import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../onboarding/onboarding_screen.dart';
import '../../../services/notification_service.dart';
import '../../../services/sms/sms_parser_service.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../budget/presentation/budget_settings_screen.dart';
import '../../settings/app_settings_screen.dart';
import '../../onboarding/app_tour_screen.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
        children: [
          const SizedBox(height: 16),
          
          // === BUDGET & SPENDING SECTION ===
          _buildSectionHeader('Budget & Spending'),
          
          _buildMenuTile(
            context,
            icon: Icons.account_balance,
            iconColor: Colors.teal,
            title: 'Budget & Limits',
            subtitle: 'Set spending limits and track budgets',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BudgetSettingsScreen()),
              );
            },
          ),
          
          const Divider(color: Colors.grey, height: 1),
          
          _buildMenuTile(
            context,
            icon: Icons.auto_fix_high,
            iconColor: Colors.purple,
            title: 'Re-Categorize Transactions',
            subtitle: 'Auto-assign categories to uncategorized',
            onTap: () => _showReCategorizeDialog(context, ref),
          ),
          
          const SizedBox(height: 16),
          
          // === DATA MANAGEMENT SECTION ===
          _buildSectionHeader('Data Management'),
          
          _buildMenuTile(
            context,
            icon: Icons.history,
            iconColor: Colors.orange,
            title: 'Time Travel',
            subtitle: 'Re-scan SMS from a specific date range',
            showBeta: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OnboardingScreen()),
              );
            },
          ),
          
          const Divider(color: Colors.grey, height: 1),
          
          _buildMenuTile(
            context,
            icon: Icons.backup,
            iconColor: Colors.blue,
            title: 'Backup & Restore',
            subtitle: 'Export or import your data',
            showBeta: true,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backup feature coming soon!')),
              );
            },
          ),
          
          const Divider(color: Colors.grey, height: 1),
          
          _buildMenuTile(
            context,
            icon: Icons.delete_forever,
            iconColor: Colors.red,
            title: 'Reset App',
            subtitle: 'Clear all data and start fresh',
            onTap: () {
              _showResetDialog(context);
            },
          ),
          
          const SizedBox(height: 16),
          
          // === PERMISSIONS SECTION ===
          _buildSectionHeader('Permissions'),
          
          _buildMenuTile(
            context,
            icon: Icons.notifications,
            iconColor: Colors.amber,
            title: 'Notification Settings',
            subtitle: 'Enable UPI transaction capture',
            onTap: () async {
              final notificationService = ref.read(notificationServiceProvider);
              await notificationService.requestPermission();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening notification settings...')),
                );
              }
            },
          ),
          
          const SizedBox(height: 16),
          
          // === ABOUT SECTION ===
          _buildSectionHeader('About'),
          
          _buildMenuTile(
            context,
            icon: Icons.settings,
            iconColor: Colors.blueGrey,
            title: 'App Settings',
            subtitle: 'Theme, date format, currency',
            showBeta: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AppSettingsScreen()),
              );
            },
          ),
          
          const Divider(color: Colors.grey, height: 1),
          
          _buildMenuTile(
            context,
            icon: Icons.help,
            iconColor: Colors.green,
            title: 'Help & Tutorial',
            subtitle: 'Learn how to use AutoSpend',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AppTourScreen(),
                  fullscreenDialog: true,
                ),
              );
            },
          ),
          
          const Divider(color: Colors.grey, height: 1),
          
          _buildMenuTile(
            context,
            icon: Icons.info,
            iconColor: Colors.grey,
            title: 'About AutoSpend',
            subtitle: 'Version 2.0',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'AutoSpend',
                applicationVersion: '2.0',
                applicationIcon: const Icon(Icons.account_balance_wallet, size: 48, color: Colors.teal),
                children: [
                  const Text('Offline Personal Finance Tracker'),
                  const SizedBox(height: 8),
                  const Text('Built with Flutter'),
                  const SizedBox(height: 8),
                  const Text('© 2026 AutoSpend'),
                ],
              );
            },
          ),
          
          const SizedBox(height: 16),
        ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.teal,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showBeta = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 28),
      title: Row(
        children: [
          Flexible(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (showBeta)
            const SizedBox(width: 8),
          if (showBeta)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange, width: 1),
              ),
              child: Text(
                'BETA',
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.poppins(
          color: Colors.grey.shade500,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Reset App?',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will delete all transactions and reset the app. This action cannot be undone!',
          style: GoogleFonts.poppins(color: Colors.grey.shade300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                  (route) => false,
                );
              }
            },
            child: Text('Reset', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showReCategorizeDialog(BuildContext context, WidgetRef ref) async {
    // Get count of uncategorized transactions
    final uncategorized = await ref.read(transactionRepositoryProvider).getUncategorizedTransactions();
    final count = uncategorized.length;
    
    if (count == 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No uncategorized transactions found! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }
    
    if (!context.mounted) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Re-Categorize Transactions',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Found $count uncategorized transactions.',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              'This will automatically assign categories based on merchant names using smart detection.',
              style: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Re-Categorize', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    
    if (confirm != true || !context.mounted) return;
    
    // Show progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (progressContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.purple),
            const SizedBox(height: 16),
            Text(
              'Processing $count transactions...',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ],
        ),
      ),
    );
    
    // Process re-categorization
    final parser = ref.read(smsParserServiceProvider);
    final repo = ref.read(transactionRepositoryProvider);
    int reCategorized = 0;
    
    for (final tx in uncategorized) {
      final merchant = tx.merchant ?? '';
      final newCategory = parser.inferCategory(merchant);
      
      if (newCategory != 'Uncategorized') {
        await repo.updateCategory(tx.id, newCategory);
        reCategorized++;
      }
    }
    
    // Close progress dialog
    if (context.mounted) {
      Navigator.pop(context);
    }
    
    // Show result
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Re-categorized $reCategorized of $count transactions! 🎉'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
