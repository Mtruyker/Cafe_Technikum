import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:techcafe_server/api.dart';
import 'package:techcafe_server/config.dart';
import 'package:techcafe_server/middleware/cors.dart';
import 'package:techcafe_server/store/sqlite_store.dart';

void main() async {
  final config = ServerConfig.fromEnvironment();
  final store = SqliteStore(config.dbPath);
  if (config.seedDemoData) {
    store.seedIfEmpty();
  }
  final api = TechCafeApi(store, config);

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsMiddleware())
      .addHandler(api.router.call);

  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);

  stdout.writeln(
    'TechCafe API is running on http://${server.address.host}:${server.port}',
  );
}
