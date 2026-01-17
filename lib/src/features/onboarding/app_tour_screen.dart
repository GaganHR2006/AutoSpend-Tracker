import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTourScreen extends StatefulWidget {
  const AppTourScreen({super.key});

  @override
  State<AppTourScreen> createState() => _AppTourScreenState();
}

class _AppTourScreenState extends State<AppTourScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<TourStep> _steps = [
    TourStep(
      icon: Icons.account_balance_wallet,
      iconColor: Colors.teal,
      title: 'Welcome to AutoSpend',
      description:
          'Your offline personal finance tracker. All your data stays on your device, completely private and secure.',
      imageAsset: null,
    ),
    TourStep(
      icon: Icons.trending_up,
      iconColor: Colors.green,
      title: 'Dashboard Overview',
      description:
          'See your Net Savings at a glance. Green means you\'re saving, red means spending more than earning. Use filters to view different time periods.',
      imageAsset: null,
    ),
    TourStep(
      icon: Icons.account_balance,
      iconColor: Colors.purple,
      title: 'Budget & Limits',
      description:
          'Set spending limits for categories and track your progress. Color-coded bars show your budget status: Green (safe), Orange (approaching), Red (exceeded).',
      imageAsset: null,
    ),
    TourStep(
      icon: Icons.sms,
      iconColor: Colors.blue,
      title: 'Auto Transaction Capture',
      description:
          'AutoSpend automatically reads your bank SMS and notifications to capture transactions. Enable permissions for seamless tracking. You can also add transactions manually.',
      imageAsset: null,
    ),
    TourStep(
      icon: Icons.menu,
      iconColor: Colors.orange,
      title: 'Explore Features',
      description:
          'Access Budget & Limits, Time Travel (re-scan SMS), Analytics, and more from the Menu tab. Don\'t forget to check out the settings!',
      imageAsset: null,
    ),
  ];

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  Future<void> _completeTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tour_completed', true);
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _skipTour() {
    _completeTour();
  }

  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeTour();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: _skipTour,
                  child: Text(
                    'Skip',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),

            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  return _buildTourStep(_steps[index]);
                },
              ),
            ),

            // Progress dots
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _steps.length,
                  (index) => _buildDot(index),
                ),
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  if (_currentPage > 0)
                    OutlinedButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      child: Text(
                        'Back',
                        style: GoogleFonts.poppins(fontSize: 16),
                      ),
                    )
                  else
                    const SizedBox(width: 100),

                  // Next/Get Started button
                  FilledButton(
                    onPressed: _nextPage,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      backgroundColor: Colors.teal,
                    ),
                    child: Text(
                      _currentPage == _steps.length - 1
                          ? 'Get Started'
                          : 'Next',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTourStep(TourStep step) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: step.iconColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              step.icon,
              size: 80,
              color: step.iconColor,
            ),
          ),

          const SizedBox(height: 48),

          // Title
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 24),

          // Description
          Text(
            step.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              height: 1.5,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index
            ? Colors.teal
            : Colors.grey.shade700,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class TourStep {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String? imageAsset;

  TourStep({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    this.imageAsset,
  });
}

// Helper function to check if tour is completed
Future<bool> isTourCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('tour_completed') ?? false;
}

// Helper function to reset tour (for testing/replay)
Future<void> resetTour() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('tour_completed', false);
}
