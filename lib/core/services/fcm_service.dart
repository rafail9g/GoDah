import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('📩 Background FCM: ${message.notification?.title}');
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotif = FlutterLocalNotificationsPlugin();
  final _supabase = Supabase.instance.client;

  static const _channelId = 'godah_verifikasi';
  static const _channelName = 'Go-Dah Verifikasi';

  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    await _requestPermission();
    await _initLocalNotifications();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotifTap);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotifTap(initialMessage);
    }

    debugPrint('✅ FCM Service initialized');
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint(
      '🔔 Notification permission: ${settings.authorizationStatus}',
    );
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotif.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (details) {
        debugPrint('🔔 Notif tapped payload: ${details.payload}');
      },
    );

    if (Platform.isAndroid) {
      await _localNotif
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: 'Notifikasi verifikasi porter Go-Dah',
              importance: Importance.high,
            ),
          );
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📩 Foreground FCM: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    _localNotif.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(
            notification.body ?? '',
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleNotifTap(RemoteMessage message) {
    debugPrint('🔔 Notif tap data: ${message.data}');
  }

  Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('📱 FCM Token: $token');
      return token;
    } catch (e) {
      debugPrint('❌ Gagal ambil FCM token: $e');
      return null;
    }
  }

  Future<void> saveAdminToken(String adminId) async {
    try {
      final token = await getToken();
      if (token == null) return;

      await _supabase.from('admins').update({
        'fcm_token': token,
        'fcm_token_updated_at': DateTime.now().toIso8601String(),
      }).eq('id', adminId);

      debugPrint('✅ FCM token admin disimpan');

      _messaging.onTokenRefresh.listen((newToken) async {
        await _supabase.from('admins').update({
          'fcm_token': newToken,
          'fcm_token_updated_at': DateTime.now().toIso8601String(),
        }).eq('id', adminId);
        debugPrint('🔄 FCM token admin diperbarui');
      });
    } catch (e) {
      debugPrint('❌ Gagal simpan FCM token: $e');
    }
  }

  Future<void> clearAdminToken(String adminId) async {
    try {
      await _supabase.from('admins').update({
        'fcm_token': null,
      }).eq('id', adminId);

      await _messaging.deleteToken();
      debugPrint('🗑️ FCM token admin dihapus');
    } catch (e) {
      debugPrint('❌ Gagal hapus FCM token: $e');
    }
  }

  Future<void> sendVerifikasiNotifToAdmins({
    required String porterNama,
    required String porterId,
  }) async {
    try {
      final admins = await _supabase
          .from('admins')
          .select('id, fcm_token')
          .not('fcm_token', 'is', null);

      if ((admins as List).isEmpty) {
        debugPrint('⚠️ Tidak ada admin dengan FCM token');
        return;
      }

      for (final admin in admins) {
        final fcmToken = admin['fcm_token'] as String?;
        if (fcmToken == null || fcmToken.isEmpty) continue;

        await _sendFcmMessage(
          token: fcmToken,
          title: '📋 Pengajuan Verifikasi Baru',
          body: '$porterNama mengajukan verifikasi dokumen. Silakan ditinjau.',
          data: {
            'type': 'verifikasi_porter',
            'porter_id': porterId,
            'porter_nama': porterNama,
          },
        );
      }

      debugPrint('✅ Notif verifikasi terkirim ke ${admins.length} admin');
    } catch (e) {
      debugPrint('❌ Gagal kirim notif verifikasi: $e');
    }
  }

  Future<void> _sendFcmMessage({
    required String token,
    required String title,
    required String body,
    Map<String, String> data = const {},
  }) async {
    try {
      await _supabase.functions.invoke(
        'send-fcm-notification',
        body: {
          'token': token,
          'title': title,
          'body': body,
          'data': data,
        },
      );
    } catch (e) {
      debugPrint('❌ Gagal invoke edge function: $e');
    }
  }
}