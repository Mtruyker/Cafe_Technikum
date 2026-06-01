import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/staff_panel_screen.dart';
import 'services/api_client.dart';
import 'services/app_backend_config.dart';
import 'services/local_orders_store.dart';
import 'state/techcafe_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppBackendConfig.fromEnvironment();
  if (config.isConfigured) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
    );
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => TechCafeState(
        apiClient: ApiClient(config: config),
        localOrdersStore: LocalOrdersStore(),
      ),
      child: const TechCafeAdminApp(),
    ),
  );
}

class TechCafeAdminApp extends StatelessWidget {
  const TechCafeAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'АдминКафе',
      theme: AppTheme.admin(),
      home: const StaffPanelScreen(),
    );
  }
}
