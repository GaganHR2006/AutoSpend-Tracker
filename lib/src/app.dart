import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/app_tour_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/transactions/presentation/add_transaction_sheet.dart';
import 'features/dashboard/data/dashboard_providers.dart';
import 'services/sms_service.dart';

// Placeholder for now, later we use DashboardScreen
class DashboardScreenPlaceholder extends DashboardScreen {
  const DashboardScreenPlaceholder({super.key});
}

class AutoSpendApp extends ConsumerStatefulWidget {
  const AutoSpendApp({super.key});

  @override
  ConsumerState<AutoSpendApp> createState() => _AutoSpendAppState();
}

class _AutoSpendAppState extends ConsumerState<AutoSpendApp> with WidgetsBindingObserver {
  bool? _isOnboarded;
  bool _isAuthenticated = false;  // Track biometric authentication status
  bool _isBiometricEnabled = false;  // Track if biometric is enabled
  final LocalAuthentication _auth = LocalAuthentication();

  // Define the channel
  static const platform = MethodChannel('com.example.autospend/quick_actions');
  
  // We need a GlobalKey to access the Navigator even if we aren't inside a child widget yet
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);  // ✅ Register lifecycle observer
    _checkOnboarding();
    _setupQuickActions();
    _initializeSmsService();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    print('🔄 App Lifecycle Changed: $state');
    
    if (state == AppLifecycleState.resumed) {
      print('✅ App resumed - refreshing data');
      
      // Invalidate providers to force refresh
      ref.invalidate(transactionListProvider);
      ref.invalidate(filteredTransactionListProvider);
      ref.invalidate(filteredBalanceProvider);
      ref.invalidate(lendingSummaryProvider);
      
      print('🔄 Providers invalidated - UI should refresh');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);  // ✅ Unregister lifecycle observer
    super.dispose();
  }

  void _initializeSmsService() {
    // Initialize SMS service to start listening for incoming SMS
    // We need to get it from the ref, but we can't use ref in initState
    // So we'll do it after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(smsServiceProvider);
      print('✅ SMS Service initialized in app.dart');
    });
  }

  void _setupQuickActions() {
    // 1. LISTEN for live events (Background -> Foreground)
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onQuickActionReceived') {
         // Received push notification from Native
        _showQuickAddSheet();
      }
    });

    // 2. CHECK STORAGE (Cold Start / Terminated)
    // We wait 500ms to ensure the UI is built and ready
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        // Check if there's a pending quick action
        final prefs = await SharedPreferences.getInstance();
        final String? action = await platform.invokeMethod('checkAndConsumeQuickAction');
        final skipBiometric = prefs.getBool('skip_biometric') ?? false;
        
        if (action == 'QUICK_ADD_EXPENSE') {
          // Clear the skip_biometric flag
          await prefs.remove('skip_biometric');
          
          // If we should skip biometric, show sheet immediately
          if (skipBiometric) {
            _showQuickAddSheet();
          } else {
            // Normal flow - biometric will be checked if enabled
            _showQuickAddSheet();
          }
        }
      } catch (e) {
        debugPrint("QuickAction Error: $e");
      }
    });
  }

  void _showQuickAddSheet() {
    // 1. Get the context from the navigator key
    final context = navigatorKey.currentContext;
    if (context == null) return;

    // 2. Open the EXACT SAME sheet your main app uses
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const AddTransactionSheet(),
    );
  }

  Future<void> _checkOnboarding() async {
    // Check BOTH storage methods for robustness
    const secureStorage = FlutterSecureStorage();
    final prefs = await SharedPreferences.getInstance();
    
    // ✅ CRITICAL: Check quick action flag FIRST, before it gets consumed
    final hasPendingQuickAction = prefs.getBool('quick_add_pending') ?? false;
    
    // Check FlutterSecureStorage (original method)
    final secureValue = await secureStorage.read(key: 'is_onboarded');
    
    // Check SharedPreferences (backup method - more reliable)
    final prefsValue = prefs.getBool('setup_complete') ?? false;
    
    // User is onboarded if EITHER storage says true
    final isOnboarded = secureValue == 'true' || prefsValue;
    
    // ✅ Check if biometric authentication is enabled
    final biometricEnabled = await secureStorage.read(key: 'biometric_enabled');
    final isBioEnabled = biometricEnabled == 'true';
    
    setState(() {
      _isOnboarded = isOnboarded;
      _isBiometricEnabled = isBioEnabled;
    });
    
    // ✅ If onboarded AND biometric is enabled AND no quick action pending, require authentication
    if (isOnboarded && isBioEnabled && !hasPendingQuickAction) {
      print('🔒 Biometric enabled - requiring authentication');
      await _performBiometricAuth();
    } else {
      // If no biometric, or quick action pending, user is authenticated by default
      setState(() {
        _isAuthenticated = true;
      });
      
      // Log why we're skipping biometric
      if (hasPendingQuickAction) {
        print('⚡ Quick Add pending - SKIPPING biometric auth');
      }
    }
  }
  
  Future<void> _performBiometricAuth() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      
      if (canCheck) {
        final didAuthenticate = await _auth.authenticate(
          localizedReason: 'Authenticate to access AutoSpend',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: false,  // Allow PIN/Pattern as fallback
          ),
        );
        
        setState(() {
          _isAuthenticated = didAuthenticate;
        });
        
        if (!didAuthenticate) {
          // User failed authentication - exit app
          SystemNavigator.pop();
        }
      } else {
        // Biometrics not available, allow access
        setState(() {
          _isAuthenticated = true;
        });
      }
    } catch (e) {
      print('⚠️ Biometric authentication error: $e');
      // On error, deny access
      setState(() {
        _isAuthenticated = false;
      });
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while checking onboarding/authentication
    if (_isOnboarded == null) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // ✅ If biometric is enabled but user hasn't authenticated yet, show loading
    if (_isBiometricEnabled && !_isAuthenticated) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Authenticating...'),
              ],
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      navigatorKey: navigatorKey,
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


