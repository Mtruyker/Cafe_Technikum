import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';
import 'widgets/order_notification_host.dart';

final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class TechCafeApp extends StatelessWidget {
  const TechCafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'КафеТехникум',
      theme: AppTheme.student(),
      routerConfig: router,
      scaffoldMessengerKey: _messengerKey,
      builder: (context, child) => OrderNotificationHost(
        messengerKey: _messengerKey,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
