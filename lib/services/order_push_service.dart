import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_exception.dart';
import 'local_orders_store.dart';

/// FCM is opt-in. The ordinary app also works without Firebase configuration.
class OrderPushService {
  static bool available = false;
  static const enabled = bool.fromEnvironment('ENABLE_ANDROID_PUSH');
  static StreamSubscription<String>? _tokenSubscription;
  static Future<void> initialize() async {
    if (!enabled || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await Firebase.initializeApp();
      available = true;
      _tokenSubscription ??= FirebaseMessaging.instance.onTokenRefresh.listen((
        token,
      ) {
        unawaited(_registerSavedOrders(token).catchError((Object _) {}));
      });
    } catch (_) {
      // Missing Firebase must never stop catalog and checkout.
      available = false;
      return;
    }
    unawaited(restoreSubscriptions());
  }

  static Future<void> restoreSubscriptions() async {
    if (!available) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('order_push_enabled') != true) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerSavedOrders(token);
    } catch (_) {
      // The explicit subscribe button can retry a failed registration.
    }
  }

  static Future<void> subscribe(String pickupCode) async {
    if (!available) {
      throw const ApiException(
        'Push не настроены в этой сборке. Уведомления доступны внутри открытого приложения.',
      );
    }
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        throw const ApiException('Разрешите уведомления в настройках Android.');
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        throw const ApiException(
          'Не удалось получить адрес устройства. Попробуйте ещё раз.',
        );
      }
      await _register(pickupCode, token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('order_push_enabled', true);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Не удалось подключить уведомления. Проверьте интернет и повторите.',
      );
    }
  }

  static Future<void> _register(String code, String token) =>
      Supabase.instance.client.rpc(
        'subscribe_order_push',
        params: {'p_pickup_code': code, 'p_token': token},
      );

  static Future<void> _registerSavedOrders(String token) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('order_push_enabled') != true) return;
    final orders = await LocalOrdersStore().load();
    for (final order in orders.where(
      (o) =>
          o.pickupCode.isNotEmpty &&
          !['issued', 'canceled'].contains(o.status.name),
    )) {
      try {
        await _register(order.pickupCode, token);
      } catch (_) {
        // One outdated order must not prevent subscription to the others.
      }
    }
  }
}
