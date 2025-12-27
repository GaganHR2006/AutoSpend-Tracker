import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/sms/sms_parser_service.dart';
import '../../app.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  bool _isBioEnabled = false;
  bool _isSmsGranted = false;
  double _scanMonths = 1;
  bool _isScanning = false;
  
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
                children: [
                  _buildStep1Biometrics(),
                  _buildStep2Permissions(),
                  _buildStep3History(),
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
                final canCheck = await _auth.canCheckBiometrics;
                if (canCheck) {
                  final didAuthenticate = await _auth.authenticate(
                    localizedReason: 'Authenticate to access AutoSpend',
                    options: const AuthenticationOptions(stickyAuth: true),
                  );
                  setState(() => _isBioEnabled = didAuthenticate);
                } else {
                  // Fallback or skip
                  setState(() => _isBioEnabled = true); // Mock success if no hardware
                }
                _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
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

  Widget _buildStep2Permissions() {
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
                }
              },
              child: const Text('Grant SMS Permission'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3History() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history, size: 80, color: Colors.teal),
          const SizedBox(height: 24),
          Text(
            'Time Travel',
            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Scan past messages to build your spending history.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          Text('Scan past ${_scanMonths.round()} months'),
          Slider(
            value: _scanMonths,
            min: 0,
            max: 3,
            divisions: 3,
            label: '${_scanMonths.round()} Months',
            onChanged: (val) => setState(() => _scanMonths = val),
          ),
          const Spacer(),
          if (_isScanning)
            const CircularProgressIndicator()
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  setState(() => _isScanning = true);
                  await ref.read(smsParserServiceProvider).scanMessages(_scanMonths.round());
                  
                  // Save onboarding state
                  await _storage.write(key: 'is_onboarded', value: 'true');
                  
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const DashboardScreenPlaceholder()), 
                    );
                  }
                },
                child: const Text('Finish Setup'),
              ),
            ),
        ],
      ),
    );
  }
}
