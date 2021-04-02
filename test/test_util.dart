library mysql1.test.test_util;

import 'dart:async';

import 'package:mysql1/mysql1.dart';
import 'package:mysql1/src/constants.dart';
import 'package:test/test.dart';

Future setup(MySqlConnection conn, String tableName, String? createSql,
    [String? insertSql]) async {
  await TableDropper(conn, [tableName]).dropTables();
  if (createSql != null) {
    var result = await conn.query(createSql);
    expect(result, isNotNull);
  }
  if (insertSql != null) {
    await conn.query(insertSql);
  }
}

/// Drops a set of tables.
class TableDropper {
  MySqlConnection conn;
  List<String> tables;

  /// Create a [TableDropper]. Needs a [pool] and
  /// a list of [tables].
  TableDropper(this.conn, this.tables);

  /// Drops the tables this [TableDropper] was created with. The
  /// returned [Future] completes when all the tables have been dropped.
  /// If a table doesn't exist, it is ignored.
  Future dropTables() async {
    for (var table in tables) {
      try {
        await conn.query('drop table $table');
      } catch (e) {
        if (e is MySqlException && e.errorNumber == ERROR_UNKNOWN_TABLE) {
          // if it's an unknown table, ignore the error and continue
        } else {
          rethrow;
        }
      }
    }
  }
}
