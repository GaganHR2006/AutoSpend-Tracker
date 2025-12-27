import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'analytics_screen.dart';
import '../../transactions/presentation/add_transaction_sheet.dart';



class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = const [
    HomeScreen(),
    AnalyticsScreen(),
  ];



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AutoSpend'),
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (index < _screens.length) {
            setState(() => _currentIndex = index);
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.menu), label: 'Menu'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => const AddTransactionSheet(),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

