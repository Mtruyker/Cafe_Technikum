import '../utils/formatters.dart';

class StaffSession {
  const StaffSession({
    required this.token,
    required this.role,
    required this.name,
  });

  final String token;
  final String role;
  final String name;

  bool get isAdmin => role == 'admin';

  factory StaffSession.fromJson(JsonMap json) {
    return StaffSession(
      token: json['token']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}
