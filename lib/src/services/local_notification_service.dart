import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localNotificationServiceProvider = Provider<LocalNotificationService>((ref) {
  return LocalNotificationService();
});

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    await _createNotificationChannels();

    _isInitialized = true;
    print('✅ Local notification service initialized');
  }

  Future<void> _createNotificationChannels() async {
    // Budget warning channel (80-90%)
    const warningChannel = AndroidNotificationChannel(
      'budget_warning',
      'Budget Warnings',
      description: 'Alerts when you approach budget limits',
      importance: Importance.defaultImportance,
      enableVibration: true,
    );

    // Budget danger channel (90-100%)
    const dangerChannel = AndroidNotificationChannel(
      'budget_danger',
      'Budget Danger',
      description: 'Critical alerts when nearing budget limits',
      importance: Importance.high,
      enableVibration: true,
    );

    // Budget exceeded channel (>100%)
    const exceededChannel = AndroidNotificationChannel(
      'budget_exceeded',
      'Budget Exceeded',
      description: 'Alerts when budget limits are exceeded',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(warningChannel);

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(dangerChannel);

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(exceededChannel);

    print('✅ Notification channels created');
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('🔔 Notification tapped: ${response.payload}');
    // Future: Navigate to budget settings screen
  }

  /// Show budget alert notification
  Future<void> showBudgetAlert({
    required String category,
    required double percentage,
    required String message,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final (title, channelId, priority) = _getAlertConfig(percentage);
    final notificationId = category.hashCode; // Use category hash as unique ID

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      channelDescription: _getChannelDescription(channelId),
      importance: priority,
      priority: priority == Importance.max ? Priority.max : Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    final details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      notificationId,
      '$title - $category',
      message,
      details,
      payload: category,
    );

    print('🔔 Budget alert shown: $category - $percentage%');
  }

  (String, String, Importance) _getAlertConfig(double percentage) {
    if (percentage >= 100) {
      return ('❌ Budget Exceeded', 'budget_exceeded', Importance.max);
    } else if (percentage >= 90) {
      return ('🚨 Budget Alert', 'budget_danger', Importance.high);
    } else {
      return ('⚠️ Budget Warning', 'budget_warning', Importance.defaultImportance);
    }
  }

  String _getChannelName(String channelId) {
    switch (channelId) {
      case 'budget_warning':
        return 'Budget Warnings';
      case 'budget_danger':
        return 'Budget Danger';
      case 'budget_exceeded':
        return 'Budget Exceeded';
      default:
        return 'Budget Alerts';
    }
  }

  String _getChannelDescription(String channelId) {
    switch (channelId) {
      case 'budget_warning':
        return 'Alerts when you approach budget limits';
      case 'budget_danger':
        return 'Critical alerts when nearing budget limits';
      case 'budget_exceeded':
        return 'Alerts when budget limits are exceeded';
      default:
        return 'Budget alert notifications';
    }
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Cancel notification for specific category
  Future<void> cancelForCategory(String category) async {
    await _notifications.cancel(category.hashCode);
  }
}
