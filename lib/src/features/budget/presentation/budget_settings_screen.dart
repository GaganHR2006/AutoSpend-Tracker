import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../data/budget_repository.dart';
import '../../categories/data/categories.dart';
import '../../../core/utils/snackbar_utils.dart';

class BudgetSettingsScreen extends ConsumerStatefulWidget {
  const BudgetSettingsScreen({super.key});

  @override
  ConsumerState<BudgetSettingsScreen> createState() => _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends ConsumerState<BudgetSettingsScreen> {
  final Map<String, double> _budgetAmounts = {};
  final Map<String, int> _budgetThresholds = {};
  final Map<String, bool> _budgetEnabled = {};
  bool _isLoading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    final budgetRepo = ref.read(budgetRepositoryProvider);
    final budgets = await budgetRepo.getBudgets();

    setState(() {
      // Initialize with existing budgets
      for (final budget in budgets) {
        _budgetAmounts[budget.category] = budget.limitAmount;
        _budgetThresholds[budget.category] = budget.alertThreshold;
        _budgetEnabled[budget.category] = budget.isActive;
      }

      // Set defaults for special categories if not exists
      _budgetAmounts.putIfAbsent('TOTAL_MONTHLY', () => 0);
      _budgetThresholds.putIfAbsent('TOTAL_MONTHLY', () => 80);
      _budgetEnabled.putIfAbsent('TOTAL_MONTHLY', () => false);

      _budgetAmounts.putIfAbsent('CREDIT_CARD', () => 0);
      _budgetThresholds.putIfAbsent('CREDIT_CARD', () => 80);
      _budgetEnabled.putIfAbsent('CREDIT_CARD', () => false);

      _isLoading = false;
    });
  }

  Future<void> _saveBudgets() async {
    final budgetRepo = ref.read(budgetRepositoryProvider);

    // Save each enabled budget
    for (final category in _budgetAmounts.keys) {
      final amount = _budgetAmounts[category] ?? 0;
      final threshold = _budgetThresholds[category] ?? 80;
      final enabled = _budgetEnabled[category] ?? false;

      if (enabled && amount > 0) {
        await budgetRepo.setCategoryBudget(
          category: category,
          amount: amount,
          threshold: threshold,
        );
      } else {
        // Delete budget if disabled or zero
        final existing = await budgetRepo.getBudgetForCategory(category);
        if (existing != null) {
          await budgetRepo.deleteBudget(existing.id);
        }
      }
    }

    setState(() => _hasChanges = false);

    if (mounted) {
      SnackBarUtils.showSuccess(context, 'Budgets saved successfully!');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.teal)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Budget & Limits',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal.shade800,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Total Monthly Limit
            _buildSpecialBudgetCard(
              context,
              category: 'TOTAL_MONTHLY',
              title: 'Monthly Budget',
              subtitle: 'Total spending limit for the month',
              icon: Icons.calendar_month,
              color: Colors.teal,
            ),

            // Credit Card Limit
            _buildSpecialBudgetCard(
              context,
              category: 'CREDIT_CARD',
              title: 'Credit Card Limit',
              subtitle: 'Your credit card spending limit',
              icon: Icons.credit_card,
              color: Colors.deepPurple,
            ),

            // Category budgets section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Category Budgets',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            // Category list
            ...defaultCategories
                .where((cat) => cat.name != 'Uncategorized' && 
                               cat.name != 'Salary' && 
                               cat.name != 'Business' && 
                               cat.name != 'Freelance' && 
                               cat.name != 'Investments')
                .map((cat) => _buildCategoryBudgetTile(context, cat)),

            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
      floatingActionButton: _hasChanges
          ? FloatingActionButton.extended(
              onPressed: _saveBudgets,
              backgroundColor: Colors.teal,
              icon: const Icon(Icons.save),
              label: Text('Save Budgets', style: GoogleFonts.poppins()),
            )
          : null,
    );
  }

  Widget _buildSpecialBudgetCard(
    BuildContext context, {
    required String category,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final currencyFormat = NumberFormat.simpleCurrency(name: 'INR', decimalDigits: 0);
    final amount = _budgetAmounts[category] ?? 0;
    final threshold = _budgetThresholds[category] ?? 80;
    final enabled = _budgetEnabled[category] ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.3), Colors.black87],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: (value) {
                  setState(() {
                    _budgetEnabled[category] = value;
                    _hasChanges = true;
                  });
                },
                activeColor: color,
              ),
            ],
          ),

          if (enabled) ...[
            const SizedBox(height: 20),
            Text(
              'Budget Amount',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              currencyFormat.format(amount),
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Slider(
              value: amount.clamp(0, 100000),
              min: 0,
              max: 100000,
              divisions: 100,
              activeColor: color,
              inactiveColor: Colors.white24,
              onChanged: (value) {
                setState(() {
                  _budgetAmounts[category] = value;
                  _hasChanges = true;
                });
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Alert Threshold',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [50, 80, 90].map((value) {
                final isSelected = threshold == value;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('$value%'),
                    selected: isSelected,
                    selectedColor: color,
                    labelStyle: GoogleFonts.poppins(
                      color: isSelected ? Colors.white : Colors.grey,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _budgetThresholds[category] = value;
                          _hasChanges = true;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryBudgetTile(BuildContext context, TransactionCategory category) {
    final amount = _budgetAmounts[category.name] ?? 0;
    final threshold = _budgetThresholds[category.name] ?? 80;
    final enabled = _budgetEnabled[category.name] ?? false;
    final currencyFormat = NumberFormat.simpleCurrency(name: 'INR', decimalDigits: 0);

    return ExpansionTile(
      leading: Text(
        category.emoji,
        style: const TextStyle(fontSize: 24),
      ),
      title: Text(
        category.name,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: enabled
          ? Text(
              currencyFormat.format(amount),
              style: GoogleFonts.poppins(
                color: category.color,
                fontSize: 12,
              ),
            )
          : Text(
              'Not set',
              style: GoogleFonts.poppins(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
      trailing: Switch(
        value: enabled,
        onChanged: (value) {
          setState(() {
            _budgetEnabled[category.name] = value;
            _hasChanges = true;
          });
        },
        activeColor: category.color,
      ),
      children: enabled
          ? [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Budget Amount',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currencyFormat.format(amount),
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: category.color,
                      ),
                    ),
                    Slider(
                      value: amount.clamp(0, 50000),
                      min: 0,
                      max: 50000,
                      divisions: 100,
                      activeColor: category.color,
                      inactiveColor: Colors.white24,
                      onChanged: (value) {
                        setState(() {
                          _budgetAmounts[category.name] = value;
                          _hasChanges = true;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Alert Threshold',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [50, 80, 90].map((value) {
                        final isSelected = threshold == value;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('$value%'),
                            selected: isSelected,
                            selectedColor: category.color,
                            labelStyle: GoogleFonts.poppins(
                              color: isSelected ? Colors.white : Colors.grey,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _budgetThresholds[category.name] = value;
                                  _hasChanges = true;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ]
          : [],
    );
  }
}
