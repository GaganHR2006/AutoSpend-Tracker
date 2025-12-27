import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../data/dashboard_providers.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spendingAsync = ref.watch(spendingByCategoryProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Spending Breakdown', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              Expanded(
                child: spendingAsync.when(
                  data: (data) {
                    if (data.isEmpty) {
                      return const Center(child: Text('No expense data available'));
                    }
                    return _buildChart(data);
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChart(Map<String, double> data) {
    final total = data.values.fold(0.0, (sum, item) => sum + item);
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Sort descending

    return Column(
      children: [
        SizedBox(
          height: 250,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: sortedEntries.map((e) {
                final percentage = (e.value / total) * 100;
                return PieChartSectionData(
                  color: _getColor(e.key),
                  value: e.value,
                  title: '${percentage.toStringAsFixed(0)}%',
                  radius: 100,
                  titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: ListView.builder(
            itemCount: sortedEntries.length,
            itemBuilder: (context, index) {
              final entry = sortedEntries[index];
              final currency = NumberFormat.simpleCurrency(name: 'INR', decimalDigits: 0);
              return ListTile(
                leading: CircleAvatar(backgroundColor: _getColor(entry.key), radius: 8),
                title: Text(entry.key),
                trailing: Text(currency.format(entry.value), style: const TextStyle(fontWeight: FontWeight.bold)),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getColor(String category) {
    switch (category.toLowerCase()) {
      case 'food': return Colors.orange;
      case 'transport': return Colors.blue;
      case 'shopping': return Colors.purple;
      case 'fuel': return Colors.red;
      case 'health': return Colors.green;
      default: return Colors.grey;
    }
  }
}
