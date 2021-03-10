library mysql1.test.test_infrastructure;

import 'package:options_file/options_file.dart';
import 'package:mysql1/mysql1.dart';
import 'package:test/test.dart';

import 'test_util.dart';

MySqlConnection get conn => _conn;
late MySqlConnection _conn;

void initializeTest([String? tableName, String? createSql, String? insertSql]) {
  var options = OptionsFile('connection.options');

  var s = ConnectionSettings(
    user: options.getString('user'),
    password: options.getString('password', null),
    port: options.getInt('port', 3306)!,
    db: options.getString('db'),
    host: options.getString('host', 'localhost')!,
  );

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
