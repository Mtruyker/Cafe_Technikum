import 'dart:io';

class ServerConfig {
  const ServerConfig({
    required this.jwtSecret,
    required this.rateLimitMaxRequests,
    required this.rateLimitWindow,
    required this.jwtExpiresInHours,
    required this.dbPath,
    required this.seedDemoData,
  });

  factory ServerConfig.fromEnvironment() {
    final env = Platform.environment;

    return ServerConfig(
      jwtSecret: env['JWT_SECRET'] ?? 'techcafe-demo-secret-change-me',
      rateLimitMaxRequests: int.tryParse(env['RATE_LIMIT_MAX'] ?? '') ?? 15,
      rateLimitWindow: Duration(
        minutes: int.tryParse(env['RATE_LIMIT_WINDOW_MIN'] ?? '') ?? 1,
      ),
      jwtExpiresInHours: int.tryParse(env['JWT_EXPIRES_HOURS'] ?? '') ?? 8,
      dbPath: env['DB_PATH'] ?? 'techcafe.db',
      seedDemoData: (env['SEED_DEMO_DATA'] ?? 'true').toLowerCase() == 'true',
    );
  }

  final String jwtSecret;
  final int rateLimitMaxRequests;
  final Duration rateLimitWindow;
  final int jwtExpiresInHours;
  final String dbPath;
  final bool seedDemoData;
}
