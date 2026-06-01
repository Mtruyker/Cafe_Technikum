import 'package:flutter_test/flutter_test.dart';

import 'package:cafe_technikum/services/api_client.dart';
import 'package:cafe_technikum/services/api_exception.dart';
import 'package:cafe_technikum/services/app_backend_config.dart';

void main() {
  const missingConfig = AppBackendConfig(
    supabaseUrl: '',
    supabaseAnonKey: '',
  );

  group('ApiClient without Supabase config', () {
    test('restoreStaffSession returns null', () async {
      final apiClient = ApiClient(config: missingConfig);

      final session = await apiClient.restoreStaffSession();

      expect(session, isNull);
    });

    test('fetchCategories throws configuration error', () async {
      final apiClient = ApiClient(config: missingConfig);

      expect(
        () => apiClient.fetchCategories(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.server)
              .having(
                (e) => e.message,
                'message',
                contains('SUPABASE_URL'),
              ),
        ),
      );
    });

    test('loginStaff validates empty credentials before transport', () async {
      final apiClient = ApiClient(config: missingConfig);

      expect(
        () => apiClient.loginStaff(email: '', password: ''),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.client)
              .having(
                (e) => e.message,
                'message',
                'Введите логин и пароль.',
              ),
        ),
      );
    });
  });
}
