library sqljocky.test.test_infrastructure;

import 'package:options_file/options_file.dart';
import 'package:sqljocky5/sqljocky.dart';
import 'package:test/test.dart';

import 'test_util.dart';

MySqlConnection get conn => _conn;
MySqlConnection _conn;

void initializeTest([String tableName, String createSql, String insertSql]) {
  var options = new OptionsFile('connection.options');
  var user = options.getString('user');
  var password = options.getString('password', null);
  var port = options.getInt('port', 3306);
  var db = options.getString('db');
  var host = options.getString('host', 'localhost');

  setUp(() async {
    // Ensure db exists
    final c = await MySqlConnection.connect(
      host: "localhost",
      port: 3306,
      user: "root",
    );
    await c.query("CREATE DATABASE IF NOT EXISTS $db CHARACTER SET utf8");
    await c.close();

    _conn = await MySqlConnection.connect(
      host: "localhost",
      port: 3306,
      user: "root",
      db: db
    );

    if (tableName != null) {
      await setup(_conn, tableName, createSql, insertSql);
    }
  });

  tearDown(() async {
    await _conn?.close();
  });
}
