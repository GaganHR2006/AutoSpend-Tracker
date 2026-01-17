import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class SmsPermissionHelpScreen extends StatelessWidget {
  const SmsPermissionHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'SMS Permission Help',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal.shade800,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning Icon
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 48,
                  color: Colors.orange,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Title
            Text(
              'Android Security Restriction',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 12),
            
            // Explanation
            Text(
              'Android 13+ has added extra security for SMS permissions. You need to enable "Restricted Settings" to allow AutoSpend to read your bank SMS.',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade300,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 32),
            
            // Why it's safe
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.security, color: Colors.teal, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Why it\'s safe:',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSafetyPoint('100% Offline - No data transmission'),
                  const SizedBox(height: 8),
                  _buildSafetyPoint('Only reads bank transaction SMS'),
                  const SizedBox(height: 8),
                  _buildSafetyPoint('Ignores personal messages & OTPs'),
                  const SizedBox(height: 8),
                  _buildSafetyPoint('Open source - code is auditable'),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Step-by-step instructions
            Text(
              'How to Enable (3 Steps):',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 16),
            
            _buildStep(
              stepNumber: 1,
              title: 'Open App Settings',
              description: 'Tap the button below to open AutoSpend\'s app info page',
              icon: Icons.settings,
              iconColor: Colors.blue,
            ),
            
            const SizedBox(height: 16),
            
            _buildStep(
              stepNumber: 2,
              title: 'Tap "Permissions"',
              description: 'Look for the "Permissions" option and tap it',
              icon: Icons.lock_open,
              iconColor: Colors.orange,
            ),
            
            const SizedBox(height: 16),
            
            _buildStep(
              stepNumber: 3,
              title: 'Enable "Allow restricted settings"',
              description: 'You\'ll see a toggle or option to enable restricted settings. Turn it ON, then grant SMS permission',
              icon: Icons.check_circle,
              iconColor: Colors.green,
            ),
            
            const SizedBox(height: 32),
            
            // Note for different manufacturers
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Note: The exact steps may vary slightly depending on your phone manufacturer (Samsung, Xiaomi, OnePlus, etc.)',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.orange.shade200,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Action button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  // Open app settings
                  _openAppSettings(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.settings_applications),
                label: Text(
                  'Open App Settings',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Skip button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'I\'ll do this later',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSafetyPoint(String text) {
    return Row(
      children: [
        const Icon(Icons.check, size: 16, color: Colors.teal),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade300,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildStep({
    required int stepNumber,
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step number circle
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: iconColor, width: 2),
          ),
          child: Center(
            child: Text(
              '$stepNumber',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: iconColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade400,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  void _openAppSettings(BuildContext context) async {
    try {
      // Use Android's intent to open app settings
      const platform = MethodChannel('com.example.autospend/settings');
      await platform.invokeMethod('openAppSettings');
    } catch (e) {
      // Fallback: Show a message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please go to: Settings → Apps → AutoSpend → Permissions',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }
}
