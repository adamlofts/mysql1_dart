import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:mysql1/mysql1.dart';
import 'package:test/test.dart';

import 'test_infrastructure.dart';

void main() {
  hierarchicalLoggingEnabled = true;
  Logger.root.level = Level.OFF;
//  Logger('ConnectionPool').level = Level.ALL;
//  Logger('Connection.Lifecycle').level = Level.ALL;
//  Logger('Query').level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord r) {
    print('${r.time}: ${r.loggerName}: ${r.message}');
  });

  initializeTest();

  test('connection test', () async {
    await conn.query('DROP TABLE IF EXISTS t1');
    await conn.query('CREATE TABLE IF NOT EXISTS t1 (a INT)');
    var r = await conn.query('INSERT INTO `t1` (a) VALUES (?)', [1]);

    r = await conn.query('SELECT * FROM `t1` WHERE a = ?', [1]);
    expect(r.length, 1);

    r = await conn.query('SELECT * FROM `t1` WHERE a = ?', [2]);
    expect(r.length, 0);

    // Drop a table which doesn't exist. This should cause an error.
    try {
      await conn.query('DROP TABLE doesnotexist');
      expect(true, false); // not reached
    } on MySqlException catch (e) {
      expect(e.errorNumber, 1051);
    }

    // Check the conn is still ok after the error
    r = await conn.query('SELECT * FROM `t1` WHERE a = ?', [1]);
    expect(r.length, 1);
  });

  test('queued queries test', () async {
    // Even though we do not await these queries they should be queued.
    Future _;
    _ = conn.query('DROP TABLE IF EXISTS t1');
    _ = conn.query('CREATE TABLE IF NOT EXISTS t1 (a INT)');
    var f1 = conn.query('SELECT * FROM `t1`');

    _ = conn.query('INSERT INTO `t1` (a) VALUES (?)', [1]);

    var f2 = conn.query('SELECT * FROM `t1` WHERE a = ?', [1]);

    var r1 = await f1;
    var r2 = await f2;

    expect(r1.length, 0);
    expect(r2.length, 1);
  });

  test('Stored procedure', () async {
    await conn.query('DROP PROCEDURE IF EXISTS p');
    await conn.query('''CREATE PROCEDURE p(a DOUBLE, b DOUBLE)
BEGIN
  SELECT a * b;
END
''');
    var results = await conn.query('CALL p(2, 3)');
    expect(results.first.first, 6);
  });

//  // FIXME: This test fails travis. Different mysql version?
//  test('bad parameter type string', () async {
//    await conn.query('SET GLOBAL sql_mode='STRICT_TRANS_TABLES';');
//
//    await conn.query('DROP TABLE IF EXISTS p1');
//    await conn.query('CREATE TABLE IF NOT EXISTS p5 (a INT)');
//    MySqlException e;
//    try {
//      await conn.query('INSERT INTO `p5` (a) VALUES (?)', ['string']);
//    } on MySqlException catch (e1) {
//      e = e1;
//    }
//    expect(e.errorNumber, 1366);
//    expect(e.message,
//        'Incorrect integer value: \'string\' for column \'a\' at row 1');
//  });

  test('too few parameter count test', () async {
    await conn.query('DROP TABLE IF EXISTS p1');
    await conn.query('CREATE TABLE IF NOT EXISTS p1 (a INT, b INT)');
    MySqlClientError? e;
    try {
      await conn.query('INSERT INTO `p1` (a, b) VALUES (?, ?)', [1]);
    } on MySqlClientError catch (e1) {
      e = e1;
    }
    expect(e?.message,
        'Length of parameters (1) does not match parameter count in query (2)');
  });
  test('json type test', () async {
    await conn.query('DROP TABLE IF EXISTS tjson');
    await conn.query('CREATE TABLE tjson(a int, b json NULL)');
    await conn.query('INSERT INTO `tjson` (a, b) VALUES (?, ?)', [
      3,
      json.encode({'key': 'val'})
    ]);
    var result = await conn.query('SELECT * FROM tjson');
    expect(result.first.first, 3);
    final obj = json.decode(result.first.last);
    expect(obj, {'key': 'val'});
  });
}
