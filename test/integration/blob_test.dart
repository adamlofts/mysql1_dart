library sqljocky.test.blob_test;

import 'dart:async';

import 'package:sqljocky/sqljocky.dart';
import 'package:test/test.dart';

import '../test_infrastructure.dart';

const tableName = 'blobtable';

void main() {
  initializeTest(tableName, "create table $tableName (stuff blob)");

  test('write blob', () async {
    var query = await pool.prepare("insert into $tableName (stuff) values (?)");
    await query.execute([
      [0xc3, 0x28]
    ]); // this is an invalid UTF8 string
  });

  test('read data', () async {
    var c = new Completer();
    var results = await pool.query('select * from $tableName');
    results.listen((row) {
      expect((row[0] as Blob).toBytes(), equals([0xc3, 0x28]));
    }, onDone: () {
      c.complete();
    });
    return c.future;
  });
}
