library sqljocky.test.test_util;

import 'dart:async';

import 'package:sqljocky2/sqljocky.dart';
import 'package:sqljocky2/utils.dart';
import 'package:test/test.dart';

Future setup(ConnectionPool pool, String tableName, String createSql,
    [String insertSql]) async {
  await new TableDropper(pool, [tableName]).dropTables();
  var result = await pool.query(createSql);
  expect(result, isNotNull);
  if (insertSql != null) {
    await pool.query(insertSql);
  }
}
