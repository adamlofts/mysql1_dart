library mysql1.test.decode_error_test;

import 'package:test/test.dart';

import '../test_infrastructure.dart';

const tableName = 'decode_error';

// https://github.com/adamlofts/mysql1_dart/issues/76
//
// A value the driver cannot decode has to fail the query. Bytes in a binary
// string column are such a value: the driver reads the column as utf8, and
// these bytes are not utf8.
void main() {
  initializeTest(
      tableName,
      'create table $tableName (name varchar(10), p varbinary(2))',
      'insert into $tableName values '
          "('a', X'FFFE'), "
          "('b', X'C328')");

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
