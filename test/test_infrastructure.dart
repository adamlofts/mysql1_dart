library mysql1.test.test_infrastructure;

import 'package:options_file/options_file.dart';
import 'package:mysql1/mysql1.dart';
import 'package:test/test.dart';

import 'test_util.dart';

MySqlConnection get conn => _conn;
late MySqlConnection _conn;

void initializeTest([String? tableName, String? createSql, String? insertSql]) {
  var options = OptionsFile('connection.options');
  var user = options.getString('user');
  var password = options.getString('password', null);
  var port = options.getInt('port', 3306)!;
  var host = options.getString('host', 'localhost')!;

  final noDb = ConnectionSettings(
    user: user,
    password: password,
    port: port,
    host: host,
  );

  final withDb = ConnectionSettings(
    user: user,
    password: password,
    port: port,
    host: host,
    db: options.getString('db'),
  );

  setUp(() async {
    // Ensure db exists
    final c = await MySqlConnection.connect(noDb);
    await c.query('CREATE DATABASE IF NOT EXISTS ${withDb.db} CHARACTER SET utf8');
    await c.close();

    _conn = await MySqlConnection.connect(withDb);

    if (tableName != null) {
      await setup(_conn, tableName, createSql, insertSql);
    }
  });

  tearDown(() async {
    await _conn.close();
  });
}
