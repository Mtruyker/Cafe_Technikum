import 'package:shelf/shelf.dart';

class AuthResult {
  AuthResult({this.session, this.error});

  final StaffSession? session;
  final Response? error;
}

class StaffSession {
  const StaffSession({
    required this.userId,
    required this.role,
    required this.name,
  });

  final String userId;
  final String role;
  final String name;
}

class StaffUser {
  const StaffUser({required this.id, required this.name, required this.role});

  final String id;
  final String name;
  final String role;
}
