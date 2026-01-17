import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/sms/sms_parser_service.dart';
import '../../core/database/database.dart';
import '../transactions/data/transaction_repository.dart';
import '../../services/notification_service.dart';
import '../../app.dart';
import '../../core/utils/snackbar_utils.dart';
import 'sms_permission_help_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  bool _isSmsGranted = false;
  bool _isNotificationGranted = false;
  bool _isScanning = false;
  
  // Time Travel date range
  DateTime? _fromDate;
  DateTime? _toDate;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);  // ✅ Add lifecycle observer
    // Default to last 3 months
    _toDate = DateTime.now();
    _fromDate = DateTime(_toDate!.year, _toDate!.month - 3, _toDate!.day);
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);  // ✅ Remove lifecycle observer
    super.dispose();
  }
  
  // ✅ Detect when app resumes from settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      print('🔄 App resumed - checking notification permission');
      _checkNotificationPermissionAndAdvance();
    }
  }
  
  // ✅ Check and auto-advance if permission granted
  Future<void> _checkNotificationPermissionAndAdvance() async {
    try {
      final notificationService = ref.read(notificationServiceProvider);
      final isGranted = await notificationService.isPermissionGranted();
      
      if (isGranted && !_isNotificationGranted) {
        print('✅ Permission detected! Auto-advancing...');
        
        setState(() {
          _isNotificationGranted = true;
        });
        
        // Show success message
        if (mounted) {
          SnackBarUtils.showSuccess(
            context,
            'Notification permission granted!',
          );
        }
        
        // Auto-advance to next step after a short delay
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    } catch (e) {
      print('⚠️ Error checking permission: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  // ✅ Check notification permission when reaching step 3 (notification step)
                  if (index == 2) {  // Notification step is index 2 (0-indexed)
                    Future.delayed(const Duration(milliseconds: 500), () {
                      _checkNotificationPermissionAndAdvance();
                    });
                  }
                },
                children: [
                  _buildStep1Biometrics(),
                  _buildStep2SmsPermission(),
                  _buildStep3NotificationPermission(),
                  _buildStep4History(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1Biometrics() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fingerprint, size: 80, color: Colors.teal),
          const SizedBox(height: 24),
          Text(
            'Secure your data',
            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Enable biometric authentication to keep your financial data private.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                try {
                  // Check if biometrics are available
                  final auth = LocalAuthentication();
                  final canCheck = await auth.canCheckBiometrics;
                  
                  if (canCheck) {
                    // Attempt to authenticate
                    final didAuthenticate = await auth.authenticate(
                      localizedReason: 'Authenticate to secure AutoSpend',
                      options: const AuthenticationOptions(
                        stickyAuth: true,
                        biometricOnly: false, // Allow PIN/Pattern as fallback
                      ),
                    );
                    
                    if (didAuthenticate) {
                      // ✅ SAVE biometric preference to secure storage
                      await _storage.write(key: 'biometric_enabled', value: 'true');
                      print('✅ Biometric preference saved to storage');
                      
                      if (mounted) {
                        SnackBarUtils.showSuccess(
                          context,
                          'Biometric authentication enabled!',
                        );
                        await Future.delayed(const Duration(milliseconds: 300));
                      }
                    }
                  } else {
                    // Device doesn't support biometrics
                    if (mounted) {
                      SnackBarUtils.showInfo(
                        context,
                        'Biometric authentication not available on this device',
                      );
                    }
                  }
                  
                  // Always advance to next step
                  if (mounted) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                } catch (e) {
                  // Handle errors (user cancelled, etc.)
                  print('⚠️ Biometric error: $e');
                  
                  if (mounted) {
                    // Still advance - biometric is optional
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                }
              },
              child: const Text('Enable Biometrics'),
            ),
          ),
          TextButton(
            onPressed: () {
              _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            },
            child: const Text('Skip for now'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2SmsPermission() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sms_outlined, size: 80, color: Colors.teal),
          const SizedBox(height: 24),
          Text(
            'Automate tracking',
            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'AutoSpend parses your bank SMS locally to track expenses automatically. No data leaves this device.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final status = await Permission.sms.request();
                setState(() => _isSmsGranted = status.isGranted);
                if (status.isGranted) {
                  _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                } else if (status.isPermanentlyDenied) {
                  // Show help screen for restricted settings
                  if (mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SmsPermissionHelpScreen(),
                      ),
                    );
                  }
                }
              },
              child: const Text('Grant SMS Permission'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SmsPermissionHelpScreen(),
                ),
              );
            },
            icon: const Icon(Icons.help_outline, size: 18),
            label: Text(
              'Need help with restricted settings?',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.orange),
            ),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3NotificationPermission() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with animation effect
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.deepOrange.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_active, size: 50, color: Colors.deepOrange),
          ),
          const SizedBox(height: 24),
          Text(
            'Track Payment Notifications',
            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'AutoSpend can also read payment notifications from PhonePe, Google Pay, and other UPI apps.\n\nThis ensures no transaction is missed, even if your bank doesn\'t send SMS.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey, height: 1.5),
            ),
          ),
          const SizedBox(height: 24),
          
          // Feature highlights
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepOrange.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                _buildFeatureRow(Icons.check_circle, 'Instant transaction capture', Colors.green),
                const SizedBox(height: 12),
                _buildFeatureRow(Icons.security, 'All data stays on your device', Colors.blue),
                const SizedBox(height: 12),
                _buildFeatureRow(Icons.backup, 'Backup for missing SMS', Colors.orange),
              ],
            ),
          ),
          
          const Spacer(),
          
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final notificationService = ref.read(notificationServiceProvider);
                
                // Check if already granted
                final isGranted = await notificationService.isPermissionGranted();
                
                if (isGranted) {
                  print('✅ Permission already granted');
                  setState(() => _isNotificationGranted = true);
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                  return;
                }
                
                print('⚠️ Permission not granted - opening settings');
                
                // ✅ Open settings - when user returns, didChangeAppLifecycleState will auto-detect
                await notificationService.requestPermission();
                
                // ✅ Show brief info message that auto-detection is enabled
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '👆 Grant permission in Settings. When you return, the app will automatically detect it!',
                        style: GoogleFonts.poppins(fontSize: 13),
                      ),
                      backgroundColor: Colors.deepOrange,
                      duration: const Duration(seconds: 4),
                      behavior: SnackBarBehavior.floating,
                      action: SnackBarAction(
                        label: 'Got it',
                        textColor: Colors.white,
                        onPressed: () {},
                      ),
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Enable Notification Access'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Text(
              'Skip (Not Recommended)',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.deepOrange.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.poppins(
                  color: Colors.deepOrange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4History() {
    final daysDifference = _fromDate != null && _toDate != null
        ? _toDate!.difference(_fromDate!).inDays + 1
        : 0;
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history, size: 50, color: Colors.teal),
          ),
          const SizedBox(height: 24),
          Text(
            'Time Travel',
            style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan past messages to build your spending history.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          
          // From Date Card
          _buildDateCard(
            label: 'From Date',
            date: _fromDate,
            onTap: () => _selectFromDate(),
          ),
          const SizedBox(height: 12),
          
          // To Date Card
          _buildDateCard(
            label: 'To Date',
            date: _toDate,
            onTap: () => _selectToDate(),
          ),
          
          // Days info
          if (_fromDate != null && _toDate != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '📅 Scanning $daysDifference days',
                style: GoogleFonts.poppins(color: Colors.teal, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          
          const Spacer(),
          if (_isScanning)
            Column(
              children: [
                const CircularProgressIndicator(color: Colors.teal),
                const SizedBox(height: 12),
                Text('Scanning messages...', style: GoogleFonts.poppins(color: Colors.grey)),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () async {
                  if (_fromDate == null || _toDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select both dates')),
                    );
                    return;
                  }
                  
                  setState(() => _isScanning = true);
                  
                  // 🗑️ CRITICAL: Clear ALL old transactions before fresh scan
                  await ref.read(appDatabaseProvider).clearAllTransactions();
                  print('🗑️ Old transactions cleared - starting fresh scan!');
                  
                  // Calculate months from date range
                  final months = ((_toDate!.year - _fromDate!.year) * 12 + _toDate!.month - _fromDate!.month).abs();
                  await ref.read(smsParserServiceProvider).scanMessages(months > 0 ? months : 1);
                  
                  // ⭐ CRITICAL: Save date range for filtering
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('filter_start_date', _fromDate!.toIso8601String());
                  await prefs.setString('filter_end_date', _toDate!.toIso8601String());
                  
                  // Save to BOTH storage methods
                  await _storage.write(key: 'is_onboarded', value: 'true');
                  await prefs.setBool('setup_complete', true);
                  await prefs.setBool('onboarding_complete', true);
                  
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const DashboardScreenPlaceholder()), 
                    );
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Finish Setup', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildDateCard({required String label, DateTime? date, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.teal, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calendar_today, color: Colors.teal, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    date != null
                        ? '${date.day} ${_monthName(date.month)} ${date.year}'
                        : 'Select date',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.teal, size: 18),
          ],
        ),
      ),
    );
  }
  
  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
  
  Future<void> _selectFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime(DateTime.now().year, DateTime.now().month - 3),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Colors.teal, surface: Color(0xFF1E1E1E)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(_fromDate!)) _toDate = _fromDate;
      });
    }
  }
  
  Future<void> _selectToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: _fromDate ?? DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Colors.teal, surface: Color(0xFF1E1E1E)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _toDate = picked);
  }
}

