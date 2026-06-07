import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background FCM: ${message.notification?.title}');
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

    debugPrint('FCM Service initialized');
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('Notification permission: ${settings.authorizationStatus}');
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
        debugPrint('Notif tapped payload: ${details.payload}');
      },
    );

    if (Platform.isAndroid) {
      await _localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
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
    debugPrint('Foreground FCM: ${message.notification?.title}');

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
    debugPrint('Notif tap data: ${message.data}');
  }

  Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('FCM Token: $token');
      return token;
    } catch (e) {
      debugPrint('Gagal ambil FCM token: $e');
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

      debugPrint('FCM token admin disimpan');

      _messaging.onTokenRefresh.listen((newToken) async {
        await _supabase.from('admins').update({
          'fcm_token': newToken,
          'fcm_token_updated_at': DateTime.now().toIso8601String(),
        }).eq('id', adminId);
        debugPrint('FCM token admin diperbarui');
      });
    } catch (e) {
      debugPrint('Gagal simpan FCM token: $e');
    }
  }

  Future<void> clearAdminToken(String adminId) async {
    try {
      await _supabase.from('admins').update({
        'fcm_token': null,
      }).eq('id', adminId);

      await _messaging.deleteToken();
      debugPrint('FCM token admin dihapus');
    } catch (e) {
      debugPrint('Gagal hapus FCM token: $e');
    }
  }

  Future<void> saveUserToken(String userId) async {
    await _saveRoleToken(table: 'users', id: userId, label: 'user');
  }

  Future<void> clearUserToken(String userId) async {
    await _clearRoleToken(table: 'users', id: userId, label: 'user');
  }

  Future<void> savePorterToken(String porterId) async {
    await _saveRoleToken(table: 'porters', id: porterId, label: 'porter');
  }

  Future<void> clearPorterToken(String porterId) async {
    await _clearRoleToken(table: 'porters', id: porterId, label: 'porter');
  }

  Future<void> _saveRoleToken({
    required String table,
    required String id,
    required String label,
  }) async {
    try {
      final token = await getToken();
      if (token == null) return;

      await _supabase.from(table).update({
        'fcm_token': token,
        'fcm_token_updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      debugPrint('FCM token $label disimpan');
    } catch (e) {
      debugPrint('Gagal simpan FCM token $label: $e');
    }
  }

  Future<void> _clearRoleToken({
    required String table,
    required String id,
    required String label,
  }) async {
    try {
      await _supabase.from(table).update({
        'fcm_token': null,
      }).eq('id', id);

      debugPrint('FCM token $label dihapus');
    } catch (e) {
      debugPrint('Gagal hapus FCM token $label: $e');
    }
  }

  Future<void> sendVerifikasiNotifToAdmin({
    required String porterNama,
    required String porterId,
    required String targetAdminId,
  }) async {
    try {
      await _supabase.functions.invoke(
        'send-fcm-notification',
        body: {
          'target_admin_id': targetAdminId,
          'porter_nama': porterNama,
          'porter_id': porterId,
          'title': 'Pengajuan Verifikasi Porter Baru',
          'body': '$porterNama mengajukan verifikasi dokumen. Silakan ditinjau.',
        },
      );
      debugPrint('Notif terkirim ke admin $targetAdminId');
    } catch (e) {
      debugPrint('Gagal kirim notif: $e');
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
      debugPrint('Gagal invoke edge function: $e');
    }
  }
}
