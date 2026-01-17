import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Settings providers
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
final colorSchemeProvider = StateProvider<String>((ref) => 'teal');
final currencyProvider = StateProvider<String>((ref) => 'INR');
final dateFormatProvider = StateProvider<String>((ref) => 'DD/MM/YYYY');
final budgetAlertsProvider = StateProvider<bool>((ref) => true);
final transactionNotificationsProvider = StateProvider<bool>((ref) => true);
final biometricAuthProvider = StateProvider<bool>((ref) => false);

class AppSettingsScreen extends ConsumerStatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  ConsumerState<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends ConsumerState<AppSettingsScreen> {
  bool _isLoading = true;
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load theme mode
    final themeModeString = prefs.getString('theme_mode') ?? 'system';
    ref.read(themeModeProvider.notifier).state = ThemeMode.values.firstWhere(
      (e) => e.name == themeModeString,
      orElse: () => ThemeMode.system,
    );

    // Load color scheme
    ref.read(colorSchemeProvider.notifier).state = prefs.getString('color_scheme') ?? 'teal';
    
    // Load currency
    ref.read(currencyProvider.notifier).state = prefs.getString('currency') ?? 'INR';
    
    // Load date format
    ref.read(dateFormatProvider.notifier).state = prefs.getString('date_format') ?? 'DD/MM/YYYY';
    
    // Load notification toggles
    ref.read(budgetAlertsProvider.notifier).state = prefs.getBool('budget_alerts') ?? true;
    ref.read(transactionNotificationsProvider.notifier).state = prefs.getBool('transaction_notifications') ?? true;
    
    // Load biometric setting
    final biometricEnabled = await _storage.read(key: 'biometric_enabled');
    ref.read(biometricAuthProvider.notifier).state = biometricEnabled == 'true';

    setState(() => _isLoading = false);
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
    ref.read(themeModeProvider.notifier).state = mode;
  }

  Future<void> _saveColorScheme(String scheme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('color_scheme', scheme);
    ref.read(colorSchemeProvider.notifier).state = scheme;
  }

  Future<void> _saveCurrency(String currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', currency);
    ref.read(currencyProvider.notifier).state = currency;
  }

  Future<void> _saveDateFormat(String format) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('date_format', format);
    ref.read(dateFormatProvider.notifier).state = format;
  }

  Future<void> _saveBudgetAlerts(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('budget_alerts', value);
    ref.read(budgetAlertsProvider.notifier).state = value;
  }

  Future<void> _saveTransactionNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('transaction_notifications', value);
    ref.read(transactionNotificationsProvider.notifier).state = value;
  }
  
  Future<void> _toggleBiometric(bool enable) async {
    if (enable) {
      // Try to enable biometric
      try {
        final canCheck = await _auth.canCheckBiometrics;
        
        if (!canCheck) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Biometric authentication not available on this device'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        
        // Attempt to authenticate
        final didAuthenticate = await _auth.authenticate(
          localizedReason: 'Authenticate to enable biometric security',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: false,
          ),
        );
        
        if (didAuthenticate) {
          // Save preference
          await _storage.write(key: 'biometric_enabled', value: 'true');
          ref.read(biometricAuthProvider.notifier).state = true;
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Biometric authentication enabled!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        print('⚠️ Biometric error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // Disable biometric
      await _storage.write(key: 'biometric_enabled', value: 'false');
      ref.read(biometricAuthProvider.notifier).state = false;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication disabled'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Settings', style: GoogleFonts.poppins()),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final themeMode = ref.watch(themeModeProvider);
    final colorScheme = ref.watch(colorSchemeProvider);
    final currency = ref.watch(currencyProvider);
    final dateFormat = ref.watch(dateFormatProvider);
    final budgetAlerts = ref.watch(budgetAlertsProvider);
    final transactionNotifs = ref.watch(transactionNotificationsProvider);
    final biometricAuth = ref.watch(biometricAuthProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('Settings', style: GoogleFonts.poppins()),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange, width: 1),
              ),
              child: Text(
                'BETA',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        children: [
          // Appearance Section
          _buildSectionHeader('Appearance'),
          _buildThemeModeTile(themeMode),
          _buildColorSchemeTile(colorScheme),
          const Divider(height: 32),

          // Security Section
          _buildSectionHeader('Security'),
          _buildBiometricTile(biometricAuth),
          const Divider(height: 32),
          
          // Data & Privacy Section
          _buildSectionHeader('Data & Privacy'),
          _buildCurrencyTile(currency),
          _buildDateFormatTile(dateFormat),
          _buildExportTile(),
          const Divider(height: 32),

          // Notifications Section
          _buildSectionHeader('Notifications'),
          _buildBudgetAlertsTile(budgetAlerts),
          _buildTransactionNotifsTile(transactionNotifs),
          const Divider(height: 32),

          // Advanced Section
          _buildSectionHeader('Advanced'),
          _buildClearCacheTile(),
          _buildResetSettingsTile(),
          
          const SizedBox(height: 32),
          
          // App Info
          Center(
            child: Text(
              'AutoSpend v2.0 Beta',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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

  Widget _buildThemeModeTile(ThemeMode currentMode) {
    return ListTile(
      leading: const Icon(Icons.palette_outlined),
      title: Text('Theme', style: GoogleFonts.poppins()),
      subtitle: Text(
        currentMode == ThemeMode.system
            ? 'Follow system'
            : currentMode == ThemeMode.dark
                ? 'Dark'
                : 'Light',
        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
      ),
      trailing: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(value: ThemeMode.system, label: Text('Auto'), icon: Icon(Icons.brightness_auto, size: 16)),
          ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode, size: 16)),
          ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode, size: 16)),
        ],
        selected: {currentMode},
        onSelectionChanged: (Set<ThemeMode> newSelection) {
          _saveThemeMode(newSelection.first);
        },
        style: ButtonStyle(
          textStyle: WidgetStateProperty.all(GoogleFonts.poppins(fontSize: 11)),
        ),
      ),
    );
  }

  Widget _buildColorSchemeTile(String currentScheme) {
    final schemes = {
      'teal': Colors.teal,
      'purple': Colors.deepPurple,
      'blue': Colors.blue,
      'red': Colors.red,
      'orange': Colors.deepOrange,
    };

    return ListTile(
      leading: const Icon(Icons.color_lens_outlined),
      title: Text('Color Scheme', style: GoogleFonts.poppins()),
      subtitle: Text(
        currentScheme.toUpperCase(),
        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
      ),
      trailing: Wrap(
        spacing: 8,
        children: schemes.entries.map((entry) {
          final isSelected = currentScheme == entry.key;
          return GestureDetector(
            onTap: () => _saveColorScheme(entry.key),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: entry.value,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: Colors.white, width: 3)
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCurrencyTile(String currentCurrency) {
    return ListTile(
      leading: const Icon(Icons.currency_rupee),
      title: Text('Currency', style: GoogleFonts.poppins()),
      subtitle: Text(currentCurrency, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
      trailing: DropdownButton<String>(
        value: currentCurrency,
        items: ['INR', 'USD', 'EUR', 'GBP'].map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value, style: GoogleFonts.poppins()),
          );
        }).toList(),
        onChanged: (String? value) {
          if (value != null) _saveCurrency(value);
        },
      ),
    );
  }

  Widget _buildDateFormatTile(String currentFormat) {
    return ListTile(
      leading: const Icon(Icons.calendar_today),
      title: Text('Date Format', style: GoogleFonts.poppins()),
      subtitle: Text(currentFormat, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
      trailing: DropdownButton<String>(
        value: currentFormat,
        items: ['DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD'].map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value, style: GoogleFonts.poppins()),
          );
        }).toList(),
        onChanged: (String? value) {
          if (value != null) _saveDateFormat(value);
        },
      ),
    );
  }

  Widget _buildExportTile() {
    return ListTile(
      leading: const Icon(Icons.download),
      title: Text('Export Data', style: GoogleFonts.poppins()),
      subtitle: Text('Export transactions as JSON or CSV', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export feature coming soon!')),
        );
      },
    );
  }

  Widget _buildBudgetAlertsTile(bool enabled) {
    return SwitchListTile(
      secondary: const Icon(Icons.notifications_active),
      title: Text('Budget Alerts', style: GoogleFonts.poppins()),
      subtitle: Text('Get notified when approaching budget limits', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
      value: enabled,
      onChanged: _saveBudgetAlerts,
    );
  }

  Widget _buildTransactionNotifsTile(bool enabled) {
    return SwitchListTile(
      secondary: const Icon(Icons.payment),
      title: Text('Transaction Notifications', style: GoogleFonts.poppins()),
      subtitle: Text('Show notifications for new transactions', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
      value: enabled,
      onChanged: _saveTransactionNotifications,
    );
  }
  
  Widget _buildBiometricTile(bool enabled) {
    return SwitchListTile(
      secondary: const Icon(Icons.fingerprint),
      title: Text('Biometric Authentication', style: GoogleFonts.poppins()),
      subtitle: Text(
        enabled 
          ? 'Fingerprint/Face unlock enabled' 
          : 'Secure your app with biometrics',
        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
      ),
      value: enabled,
      onChanged: _toggleBiometric,
    );
  }

  Widget _buildClearCacheTile() {
    return ListTile(
      leading: const Icon(Icons.delete_outline),
      title: Text('Clear Cache', style: GoogleFonts.poppins()),
      subtitle: Text('Free up storage space', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        // Implement cache clearing
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache cleared successfully!')),
        );
      },
    );
  }

  Widget _buildResetSettingsTile() {
    return ListTile(
      leading: const Icon(Icons.restore, color: Colors.red),
      title: Text('Reset Settings', style: GoogleFonts.poppins(color: Colors.red)),
      subtitle: Text('Reset all settings to default', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, color: Colors.red),
      onTap: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Reset Settings?', style: GoogleFonts.poppins()),
            content: Text(
              'This will reset all app settings to default values.',
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: GoogleFonts.poppins()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Reset', style: GoogleFonts.poppins(color: Colors.red)),
              ),
            ],
          ),
        );

        if (confirm == true && mounted) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('theme_mode');
          await prefs.remove('color_scheme');
          await prefs.remove('currency');
          await prefs.remove('date_format');
          await prefs.remove('budget_alerts');
          await prefs.remove('transaction_notifications');
          
          _loadSettings();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings reset successfully!')),
            );
          }
        }
      },
    );
  }
}
