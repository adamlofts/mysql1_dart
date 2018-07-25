import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:mockito/mockito.dart';
import 'package:options_file/options_file.dart';
import 'package:sqljocky5/constants.dart';
import 'package:sqljocky5/sqljocky.dart';
import 'package:sqljocky5/src/single_connection.dart';
import 'package:test/test.dart';
import 'test_infrastructure.dart';

void main() {
  hierarchicalLoggingEnabled = true;
  Logger.root.level = Level.OFF;
//  new Logger("ConnectionPool").level = Level.ALL;
//  new Logger("Connection.Lifecycle").level = Level.ALL;
//  new Logger("Query").level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord r) {
    print("${r.time}: ${r.loggerName}: ${r.message}");
  });

  initializeTest();

  test('connection test', () async {

    await conn.query("DROP TABLE IF EXISTS t1");
    await conn.query("CREATE TABLE IF NOT EXISTS t1 (a INT)");
    var r = await conn.query("INSERT INTO `t1` (a) VALUES (?)", [1]);

    r = await conn.query("SELECT * FROM `t1` WHERE a = ?", [1]);
    expect(r.length, 1);

    r = await conn.query("SELECT * FROM `t1` WHERE a = ?", [2]);
    expect(r.length, 0);

    // Drop a table which doesn't exist. This should cause an error.
    try {
      await conn.query("DROP TABLE doesnotexist");
      expect(true, false); // not reached
    } on MySqlException catch (e) {
      expect(e.errorNumber, 1051);
    }

    // Check the conn is still ok after the error
    r = await conn.query("SELECT * FROM `t1` WHERE a = ?", [1]);
    expect(r.length, 1);


    await conn.close();
  });


}
