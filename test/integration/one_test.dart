library mysql1.test.one_test;

import 'package:mysql1/mysql1.dart';
import 'package:test/test.dart';

import '../test_infrastructure.dart';

final dt = DateTime.utc(2018, 01, 01, 7, 0);

void main() {
  initializeTest(
      'test1',
      'create table test1 ('
          'atinyint tinyint, asmallint smallint, adatetime datetime)');

  test('datetimes are de-serialized in UTC', () async {
    var results = await conn.query(
        'insert into test1 (atinyint, adatetime) values (?, ?)', [126, dt]);
    results = await conn.query('select adatetime from test1');

    // Normal
    var dt1 = results.first[0] as DateTime;
    expect(dt1.isUtc, isTrue);

    // Binary packet
    results = await conn
        .query('select adatetime from test1 WHERE atinyint = ?', [126]);
    var dt2 = results.first[0] as DateTime;
    expect(dt2.isUtc, isTrue);

    expect(dt1, equals(dt2));
    expect(dt1, equals(dt));
  });

  test('a result is a list of rows with a schema', () async {
    await conn.query('delete from test1');
    await conn.query('insert into test1 (atinyint, asmallint) values (1, 2)');
    await conn.query('insert into test1 (atinyint, asmallint) values (3, 4)');

    final Result result = await conn
        .query('select atinyint as a, asmallint from test1 order by atinyint');
    expect(result.length, equals(2));
    expect(result.affectedRows, equals(2));
    expect(result[1][0], equals(3));
    expect(result.schema.columns.map((c) => c.columnName),
        equals(['a', 'asmallint']));
    expect(result.fields, same(result.schema.columns));
    expect(result[0].schema, same(result.schema));
    expect(result[0].toColumnMap(), equals({'a': 1, 'asmallint': 2}));
    expect(() => result.add(result[0]), throwsUnsupportedError);

    final update = await conn.query('update test1 set asmallint = 5');
    expect(update, isEmpty);
    expect(update.schema.columns, isEmpty);
    expect(update.affectedRows, equals(2));
  });

  test('disallow non-utc datetime serialization', () async {
    expect(() async {
      var results = await conn
          .query('insert into test1 (adatetime) values (?)', [DateTime.now()]);
      results = await conn.query('select adatetime from test1');
      var dt = results.first[0] as DateTime;
      expect(dt.isUtc, isTrue);
    }, throwsA(TypeMatcher<MySqlClientError>()));
  });
}
