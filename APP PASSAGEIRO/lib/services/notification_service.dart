import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:troco_seguro/firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'troco_seguro_channel',
    'Troco Seguro',
    description: 'Notificações do Troco Seguro',
    importance: Importance.high,
  );

  bool _initialized = false;
  void Function(String token)? _onTokenRefresh;
  void Function(Map<String, dynamic> data)? _onNotificationTap;

  /// Chama [callback] sempre que o Firebase renovar o token FCM.
  /// Usar para manter o backend actualizado automaticamente.
  void subscribeTokenRefresh(void Function(String token) callback) {
    _onTokenRefresh = callback;
  }

  /// Chama [callback] quando o utilizador toca numa notificação (app em
  /// background ou terminada). Usar para navegar para o ecrã relevante
  /// (ex: viagens) consoante `data['type']`.
  void subscribeNotificationTap(
      void Function(Map<String, dynamic> data) callback) {
    _onNotificationTap = callback;
  }

  /// Verifica se a app foi aberta a partir de uma notificação (cold start).
  /// Chamar depois de [subscribeNotificationTap] e da primeira frame estar
  /// pronta para navegar.
  Future<void> checkInitialMessage() async {
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _onNotificationTap?.call(initialMessage.data);
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    _fcm.onTokenRefresh.listen((newToken) {
      _onTokenRefresh?.call(newToken);
    });

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );

    await _localNotifications.initialize(initSettings);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _onNotificationTap?.call(message.data));
  }

  Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint('Erro ao obter FCM token: $e');
      return null;
    }
  }

  /// Títulos por defeito quando o backend envia notificação data-only
  /// (sem bloco `notification`) para tipos de evento conhecidos.
  static const Map<String, String> _defaultTitles = {
    'PAYMENT_SENT': 'Pagamento Confirmado',
    'PAYMENT_CONFIRMED': 'Pagamento Confirmado',
  };

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final type = message.data['type'];
    final title = notification?.title ??
        message.data['title'] ??
        _defaultTitles[type];
    final body = notification?.body ?? message.data['body'];

    if (title == null && body == null) return;

    _localNotifications.show(
      message.messageId.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
