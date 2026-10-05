library mysql1.test.fractional_seconds_test;

import 'package:test/test.dart';

import '../test_infrastructure.dart';

const tableName = 'fsp';

// https://github.com/adamlofts/mysql1_dart/issues/160
//
// A column declared with a fractional seconds precision - DATETIME(3),
// TIMESTAMP(6), TIME(6) - keeps its fraction in both directions.
void main() {
  initializeTest(
      tableName,
      'create table $tableName ('
      'dt0 datetime, dt3 datetime(3), dt6 datetime(6), '
      'ts6 timestamp(6) null, t6 time(6))');

  test('a fraction written by the server is read', () async {
    await conn.query('insert into $tableName (dt3, dt6, ts6, t6) values ('
        "'2025-01-12 14:45:13.774', '2025-01-12 14:45:13.774123', "
        "'2025-01-12 14:45:13.774123', '14:45:13.774123')");
    var row = (await conn.query('select * from $tableName')).first;
    expect(row['dt3'], equals(DateTime.utc(2025, 1, 12, 14, 45, 13, 774)));
    expect(row['dt6'], equals(DateTime.utc(2025, 1, 12, 14, 45, 13, 774, 123)));
    expect(row['ts6'], equals(DateTime.utc(2025, 1, 12, 14, 45, 13, 774, 123)));
    expect(
        row['t6'],
        equals(Duration(
            hours: 14,
            minutes: 45,
            seconds: 13,
            milliseconds: 774,
            microseconds: 123)));
  });

  test('a DateTime parameter keeps its fraction', () async {
    final value = DateTime.utc(2025, 1, 12, 14, 45, 13, 774, 123);
    await conn.query(
        'insert into $tableName (dt0, dt3, dt6, ts6) values (?, ?, ?, ?)',
        [DateTime.utc(2025, 1, 12, 14, 45, 13), value, value, value]);
    var row = (await conn.query('select * from $tableName')).first;
    expect(row['dt0'], equals(DateTime.utc(2025, 1, 12, 14, 45, 13)));
    expect(row['dt3'], equals(DateTime.utc(2025, 1, 12, 14, 45, 13, 774)));
    expect(row['dt6'], equals(value));
    expect(row['ts6'], equals(value));
  });

  test('a DateTime parameter is matched to the microsecond', () async {
    final value = DateTime.utc(2025, 1, 12, 14, 45, 13, 774, 123);
    await conn.query('insert into $tableName (dt6) values (?)', [value]);
    var results =
        await conn.query('select dt6 from $tableName where dt6 = ?', [value]);
    expect(results.length, equals(1));
  });

  test('a Duration parameter keeps its fraction', () async {
    final value = Duration(
        hours: 14,
        minutes: 45,
        seconds: 13,
        milliseconds: 774,
        microseconds: 123);
    await conn.query('insert into $tableName (t6) values (?)', [value]);
    var row = (await conn.query('select * from $tableName')).first;
    expect(row['t6'], equals(value));
  });

  test('a negative time is read', () async {
    await conn.query("insert into $tableName (t6) values ('-01:02:03.5')");
    var row = (await conn.query('select * from $tableName')).first;
    expect(row['t6'],
        equals(-Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 500)));
  });
}
