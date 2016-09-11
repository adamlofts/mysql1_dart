library sqljocky.test.test_infrastructure;

import 'package:options_file/options_file.dart';
import 'package:sqljocky2/sqljocky.dart';
import 'package:test/test.dart';

import 'test_util.dart';

ConnectionPool get pool => _pool;
ConnectionPool _pool;

void initializeTest([String tableName, String createSql]) {
  var options = new OptionsFile('connection.options');
  var user = options.getString('user');
  var password = options.getString('password', null);
  var port = options.getInt('port', 3306);
  var db = options.getString('db');
  var host = options.getString('host', 'localhost');

  setUp(() async {
    _pool = new ConnectionPool(
        user: user, password: password, db: db, port: port, host: host, max: 1);

    if (tableName != null) {
      await setup(pool, tableName, createSql);
    }
  });

  tearDown(() {
    if (_pool != null) {
      _pool.closeConnectionsNow();
      _pool = null;
    }
  });
}
