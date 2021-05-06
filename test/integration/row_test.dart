@Skip('API Update')

library mysql1.test.row_test;

import 'package:test/test.dart';

const tableName = 'row1';

void main() {}
/*

  initializeTest(tableName,
      "create table $tableName (id integer, name text, `the field` text, length integer)");

  test('store data', () async {
    var query = await pool.prepare(
        'insert into $tableName (id, name, `the field`, length) values (?, ?, ?, ?)');
    await query.execute([0, 'Bob', 'Thing', 5000]);
  });

  test('first field is empty', () async {
    final query = await pool.prepare(
        'insert into $tableName (id, name, `the field`, length) values (?, ?, ?, ?)');
    var result = await query.execute([1, '', 'Thing', 5000]);
    await result.toList();

    result = await pool.query("select name, length from $tableName");

    Iterable<Row> results = await result.toList();
    expect(results.map((r) => [r[0].toString(), r[1]]).toList().first,
        equals(['', 5000]));
  });

  test('select from stream using query and listen', () async {
    var futures = [];
    for (var i = 0; i < 5; i++) {
      var c = new Completer();
      var results = await pool.query('select * from $tableName');
      results.listen((row) {
        expect(row.id, equals(0));
        expect(row.name.toString(), equals("Bob"));
        // length is a getter on List, so it isn't mapped to the result field
        expect(row.length, equals(4));
      }, onDone: () {
        c.complete();
      });
      futures.add(c.future);
    }
    return Future.wait(futures);
  });

  test('select from stream using prepareExecute and listen', () async {
    var futures = [];
    for (var i = 0; i < 5; i++) {
      var c = new Completer();
      var results = await pool
          .prepareExecute('select * from $tableName where id = ?', [0]);
      results.listen((row) {
        expect(row.id, equals(0));
        expect(row.name.toString(), equals("Bob"));
        // length is a getter on List, so it isn't mapped to the result field
        expect(row.length, equals(4));
      }, onDone: () {
        c.complete();
      });
      futures.add(c.future);
    }
    return Future.wait(futures);
  });
}
*/
