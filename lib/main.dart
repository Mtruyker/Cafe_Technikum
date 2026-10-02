import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'services/api_client.dart';
import 'services/app_backend_config.dart';
import 'services/local_orders_store.dart';
import 'state/techcafe_state.dart';
import 'services/order_push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppBackendConfig.fromEnvironment();
  if (config.isConfigured) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
    );
  }

  await OrderPushService.initialize();
  runApp(
    ChangeNotifierProvider(
      create: (_) => TechCafeState(
        apiClient: ApiClient(config: config),
        localOrdersStore: LocalOrdersStore(),
      ),
      child: const TechCafeApp(),
    ),
  );
}
