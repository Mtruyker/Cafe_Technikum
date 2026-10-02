import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import '../state/techcafe_state.dart';
import '../services/order_push_service.dart';
import '../router.dart';

class OrderNotificationHost extends StatefulWidget {
  const OrderNotificationHost({
    super.key,
    required this.child,
    required this.messengerKey,
  });
  final Widget child;
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  @override
  State<OrderNotificationHost> createState() => _OrderNotificationHostState();
}

class _OrderNotificationHostState extends State<OrderNotificationHost>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _busy = false;
  bool _foreground = true;
  StreamSubscription<RemoteMessage>? _messages;
  StreamSubscription<RemoteMessage>? _opened;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _check());
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    if (OrderPushService.available) {
      _messages = FirebaseMessaging.onMessage.listen((_) => _check());
      _opened = FirebaseMessaging.onMessageOpenedApp.listen(_open);
      FirebaseMessaging.instance
          .getInitialMessage()
          .then((message) {
            if (mounted && message != null) _open(message);
          })
          .catchError((Object _) {});
    }
  }

  void _open(RemoteMessage message) {
    final id = message.data['orderId'];
    if (id is String && id.isNotEmpty) {
      router.push('/tracking/${Uri.encodeComponent(id)}');
    }
    _check();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _check();
  }

  Future<void> _check() async {
    if (_busy || !mounted || !_foreground) return;
    _busy = true;
    try {
      final orders = await context
          .read<TechCafeState>()
          .refreshOrderNotifications();
      if (!mounted) return;
      for (final order in orders) {
        widget.messengerKey.currentState?.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 10),
            content: Text(
              'Заказ ${order.orderNumber} готов! Можно забрать на кассе.',
            ),
            action: SnackBarAction(
              label: 'Открыть',
              onPressed: () =>
                  router.push('/tracking/${Uri.encodeComponent(order.id)}'),
            ),
          ),
        );
      }
    } catch (_) {
      // A temporary local-storage or network failure is retried next tick.
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _messages?.cancel();
    _opened?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
