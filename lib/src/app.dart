import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';

// Placeholder for now, later we use DashboardScreen
class DashboardScreenPlaceholder extends DashboardScreen {
  const DashboardScreenPlaceholder({super.key});
}

class AutoSpendApp extends ConsumerStatefulWidget {
  const AutoSpendApp({super.key});

  @override
  ConsumerState<AutoSpendApp> createState() => _AutoSpendAppState();
}

class _AutoSpendAppState extends ConsumerState<AutoSpendApp> {
  bool? _isOnboarded;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    // Check BOTH storage methods for robustness
    const secureStorage = FlutterSecureStorage();
    final prefs = await SharedPreferences.getInstance();
    
    // Check FlutterSecureStorage (original method)
    final secureValue = await secureStorage.read(key: 'is_onboarded');
    
    // Check SharedPreferences (backup method - more reliable)
    final prefsValue = prefs.getBool('setup_complete') ?? false;
    
    // User is onboarded if EITHER storage says true
    final isOnboarded = secureValue == 'true' || prefsValue;
    
    setState(() {
      _isOnboarded = isOnboarded;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnboarded == null) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'AutoSpend',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      ),
      home: _isOnboarded! ? const DashboardScreenPlaceholder() : const OnboardingScreen(),
    );
  }
}
