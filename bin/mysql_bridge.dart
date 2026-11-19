import 'dart:io';

import 'package:mysql1/src/bridge/mysql_bridge.dart';

/// Carry MySQL connections for a browser.
///
/// A Flutter web app cannot open port 3306. It connects to this process over
/// a WebSocket, and this process opens the database socket. The database host
/// comes from the environment below, never from the page.
///
///     MYSQL_BRIDGE_TOKEN   required, at least 16 characters
///     MYSQL_HOST           default 127.0.0.1
///     MYSQL_PORT           default 3306
///     MYSQL_BRIDGE_BIND    default 127.0.0.1
///     MYSQL_BRIDGE_PORT    default 8080
///     MYSQL_BRIDGE_ORIGIN  if set, only this Origin is upgraded
///
/// The token, the database user and the password all end up inside the built
/// web app. Anyone who can load the app can read them. Bind this to loopback
/// unless the people who can open that WebSocket are the people who should
/// be able to log in to that database.
Future<void> main() async {
  final token = Platform.environment['MYSQL_BRIDGE_TOKEN'] ?? '';
  if (token.length < 16) {
    stderr.writeln(
      'MYSQL_BRIDGE_TOKEN must be set to at least 16 characters. '
      'The value is not printed.',
    );
    exitCode = 64;
    return;
  }

  final bridge = await MysqlBridge.start(
    token: token,
    mysqlHost: Platform.environment['MYSQL_HOST'] ?? '127.0.0.1',
    mysqlPort: _port('MYSQL_PORT', 3306),
    bindHost: Platform.environment['MYSQL_BRIDGE_BIND'] ?? '127.0.0.1',
    port: _port('MYSQL_BRIDGE_PORT', 8080),
    origin: _optional('MYSQL_BRIDGE_ORIGIN'),
  );
  stdout.writeln('mysql1 bridge listening on ${bridge.url}');
  stdout.writeln('forwarding to ${bridge.mysqlHost}:${bridge.mysqlPort}');
}

int _port(String name, int fallback) {
  final value = Platform.environment[name];
  if (value == null || value.isEmpty) {
    return fallback;
  }
  final port = int.tryParse(value);
  if (port == null || port < 0 || port > 65535) {
    stderr.writeln('$name must be a port from 0 to 65535. It was $value');
    exit(64);
  }
  return port;
}

String? _optional(String name) {
  final value = Platform.environment[name];
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}
