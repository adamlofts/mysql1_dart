library mysql1.test.test_infrastructure;

import 'dart:io';

import 'package:mysql1/mysql1.dart';
import 'package:test/test.dart';

import 'test_util.dart';

MySqlConnection get conn => _conn;
late MySqlConnection _conn;

/// The `key=value` pairs in `connection.options`, ignoring blank lines and
/// `#` comments. Missing file means no pairs, which is fine - everything it
/// can set has either a default or an environment variable.
Map<String, String> _readOptionsFile() {
  final file = File('connection.options');
  if (!file.existsSync()) {
    return {};
  }

  final options = <String, String>{};
  for (var line in file.readAsLinesSync()) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    final separator = line.indexOf('=');
    if (separator == -1) {
      continue;
    }
    options[line.substring(0, separator).trim()] =
        line.substring(separator + 1).trim();
  }
  return options;
}

/// How the integration tests reach the database.
///
/// `connection.options` is read first, then any `MYSQL_*` environment
/// variable overrides it, so a checkout can be pointed at another server
/// without editing a tracked file.
ConnectionSettings testConnectionSettings() {
  final options = _readOptionsFile();
  final env = Platform.environment;

  String? value(String key, String envKey) => env[envKey] ?? options[key];

  final port = value('port', 'MYSQL_PORT');

  return ConnectionSettings(
    user: value('user', 'MYSQL_USER'),
    password: value('password', 'MYSQL_PASSWORD'),
    port: port == null ? 3306 : int.parse(port),
    db: value('db', 'MYSQL_DATABASE'),
    host: value('host', 'MYSQL_HOST') ?? 'localhost',
  );
}

void initializeTest([String? tableName, String? createSql, String? insertSql]) {
  var s = testConnectionSettings();

  setUp(() async {
    // Ensure db exists
    var checkSettings = ConnectionSettings.copy(s);
    checkSettings.db = null;
    final c = await MySqlConnection.connect(checkSettings);
    await c.query('CREATE DATABASE IF NOT EXISTS ${s.db} CHARACTER SET utf8');
    await c.close();

    _conn = await MySqlConnection.connect(s);

    if (tableName != null) {
      await setup(_conn, tableName, createSql, insertSql);
    }
  });

  tearDown(() async {
    await _conn.close();
  });
}
