library mysql1.test.decode_error_test;

import 'package:test/test.dart';

import '../test_infrastructure.dart';

const tableName = 'decode_error';

// https://github.com/adamlofts/mysql1_dart/issues/76
//
// A value the driver cannot decode has to fail the query. A point is such a
// value: it arrives as bytes which are read as utf8, and are not utf8.
void main() {
  initializeTest(
      tableName,
      'create table $tableName (name varchar(10), p point)',
      'insert into $tableName values '
          "('a', ST_GeomFromText('POINT(1 2)')), "
          "('b', ST_GeomFromText('POINT(3 4)'))");

  test('the query fails with the error', () async {
    await expectLater(conn.query('select * from $tableName'),
        throwsA(isA<FormatException>()));
  });

  test('the connection can still be used', () async {
    await expectLater(conn.query('select * from $tableName'),
        throwsA(isA<FormatException>()));
    var results = await conn.query('select name from $tableName order by name');
    expect(results.map((r) => r['name']), equals(['a', 'b']));
  });
}
