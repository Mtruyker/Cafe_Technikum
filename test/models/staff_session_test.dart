import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_technikum/models/staff_session.dart';

void main() {
  group('StaffSession.fromJson', () {
    test('parses correct JSON', () {
      final session = StaffSession.fromJson({
        'token': 'jwt_token_123',
        'role': 'admin',
        'name': 'Иван',
      });

      expect(session.token, 'jwt_token_123');
      expect(session.role, 'admin');
      expect(session.name, 'Иван');
    });

    test('handles missing fields', () {
      final session = StaffSession.fromJson({});

      expect(session.token, '');
      expect(session.role, '');
      expect(session.name, '');
    });
  });

  group('isAdmin', () {
    test('returns true when role is admin', () {
      final session = StaffSession.fromJson({
        'token': 't',
        'role': 'admin',
        'name': 'Admin',
      });

      expect(session.isAdmin, true);
    });

    test('returns false when role is not admin', () {
      final session = StaffSession.fromJson({
        'token': 't',
        'role': 'teacher',
        'name': 'Teacher',
      });

      expect(session.isAdmin, false);
    });

    test('returns false when role is empty', () {
      final session = StaffSession.fromJson({});
      expect(session.isAdmin, false);
    });
  });
}
