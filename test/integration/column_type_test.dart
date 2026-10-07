library mysql1.test.column_type_test;

import 'package:mysql1/mysql1.dart';
import 'package:mysql1/src/constants.dart';
import 'package:test/test.dart';

import '../test_infrastructure.dart';

// One column of each type the driver decodes, named after what the server
// should call it.
const _columns = {
  'tiny': 'tinyint',
  'short': 'smallint',
  'int24': 'mediumint',
  'long': 'int',
  'longLong': 'bigint',
  'float': 'float',
  'double': 'double',
  'newDecimal': 'decimal(10, 2)',
  'bit': 'bit(8)',
  'date': 'date',
  'dateTime': 'datetime',
  'timestamp': 'timestamp null',
  'time': 'time',
  'year': 'year',
  'string': 'char(4)',
  'varString': 'varchar(4)',
  'tinyBlob': 'tinyblob',
  'blob': 'blob',
  'mediumBlob': 'mediumblob',
  'longBlob': 'longblob',
  'json': 'json',
  'geometry': 'geometry',
};

void main() {
  initializeTest(
      'coltypes',
      'create table coltypes ('
          '${_columns.entries.map((e) => '`${e.key}` ${e.value}').join(', ')})');

  // The three sizes of blob are defined, but a server reports every blob and
  // text column as the plain blob type and tells them apart by length.
  test('the server names each column type as the driver expects', () async {
    final result = await conn.query('select * from coltypes');
    final named = {
      for (final column in result.fields)
        column.name: ColumnType.of(column.type)?.name
    };
    expect(
        named,
        equals({
          for (final name in _columns.keys)
            name: name.endsWith('Blob') ? 'blob' : name
        }));
  });

  test('a value of each type comes back decoded', () async {
    await conn.query(
        'insert into coltypes (${_columns.keys.map((c) => '`$c`').join(', ')}) '
        'values (1, 2, 3, 4, 5, 1.5, 2.5, 3.25, 5, ?, ?, ?, '
        "'01:02:03', 2020, 'ab', 'cd', 'ef', 'gh', 'ij', 'kl', '{\"a\": 1}', "
        "ST_GeomFromText('POINT(1 2)'))",
        [
          DateTime.utc(2020, 1, 2),
          DateTime.utc(2020, 1, 2, 3, 4, 5),
          DateTime.utc(2020, 1, 2, 3, 4, 5)
        ]);
    final row = (await conn.query('select * from coltypes')).first;
    expect(row['tiny'], equals(1));
    expect(row['short'], equals(2));
    expect(row['int24'], equals(3));
    expect(row['long'], equals(4));
    expect(row['longLong'], equals(5));
    expect(row['float'], equals(1.5));
    expect(row['double'], equals(2.5));
    expect(row['newDecimal'], equals(3.25));
    expect(row['bit'], equals(5));
    expect(row['date'], equals(DateTime.utc(2020, 1, 2)));
    expect(row['dateTime'], equals(DateTime.utc(2020, 1, 2, 3, 4, 5)));
    expect(row['timestamp'], isA<DateTime>());
    expect(
        row['time'], equals(const Duration(hours: 1, minutes: 2, seconds: 3)));
    expect(row['year'], equals(2020));
    expect(row['string'], equals('ab'));
    expect(row['varString'], equals('cd'));
    expect((row['tinyBlob'] as Blob).toString(), equals('ef'));
    expect((row['blob'] as Blob).toString(), equals('gh'));
    expect((row['mediumBlob'] as Blob).toString(), equals('ij'));
    expect((row['longBlob'] as Blob).toString(), equals('kl'));
    expect(row['json'], equals('{"a": 1}'));
    // The SRID, then well-known binary: byte order, type, two doubles.
    expect((row['geometry'] as Blob).toBytes(), hasLength(4 + 1 + 4 + 16));
  });
}
