library mysql1.test.one_test;

import 'package:mysql1/mysql1.dart';
import 'package:test/test.dart';

import '../test_infrastructure.dart';

import 'dart:typed_data';

final dt = DateTime.utc(2018, 01, 01, 7, 0);

List<Object>? get insertValues {
  var values = <Object>[];
  values.add(126);
  values.add(164);
  values.add(165);
  values.add(166);
  values.add(167);

  values.add(592);
  values.add(123.456);
  values.add(123.456);
  values.add(123.456);

  values.add(true);
  values.add(0x010203); //[1, 2, 3]);
  values.add(123);

  values.add(dt);
  values.add(dt);
  values.add(dt);
  values.add(dt);
  values.add(2012);

  values.add('Hello');
  values.add('Hey');
  values.add('Hello there');
  values.add('Good morning');
  values.add('Habari boss');
  values.add('Bonjour');

  values.add([65, 66, 67, 68]);
  values.add([65, 66, 67, 68]);
  values.add([65, 66, 67, 68]);
  values.add([65, 66, 67, 68]);
  values.add([65, 66, 67, 68]);
  values.add([65, 66, 67, 68]);

  values.add('a');
  values.add('a,b');
  return values;
}

List get responseValues {
  var values = <Object?>[];
  values.add(126);
  values.add(164);
  values.add(165);
  values.add(166);
  values.add(167);

  values.add(592);
  values.add(123.456);
  values.add(123.456);
  values.add(123.456);

  values.add(1);
  values.add(0x010203); //[1, 2, 3]);
  values.add(123);

  values.add(DateTime(dt.year, dt.month, dt.day)
      .toUtc()); // date has zero'd out time value
  // Datetime has no millis
  values.add(DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second)
      .toUtc());
  values.add(DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second)
      .toUtc());
  values.add(Duration(hours: dt.hour, minutes: dt.minute, seconds: dt.second));
  values.add(2012);

  values.add('Hello');
  values.add('Hey');
  values.add(Blob.fromString('Hello there'));
  values.add(Blob.fromString('Good morning'));
  values.add(Blob.fromString('Habari boss'));
  values.add(Blob.fromString('Bonjour'));

  values.add('ABCD\x00\x00\x00\x00\x00\x00');
  values.add('ABCD');
  values.add(Blob.fromString('ABCD'));
  values.add(Blob.fromString('ABCD'));
  values.add(Blob.fromString('ABCD'));
  values.add(Blob.fromString('ABCD'));

  values.add('a');
  values.add('a,b');
  values.add(null);
  return values;
}

List<String> valueTypes = [
  'int',
  'int',
  'int',
  'int',
  'int',
  'double',
  'double',
  'double',
  'double',
  'int',
  'int',
  'int',
  'Date',
  'Date',
  'Date',
  'Duration',
  'int',
  'String',
  'String',
  'Unknown',
  'Unknown',
  'Unknown',
  'Unknown',
  'String',
  'String',
  'Unknown',
  'Unknown',
  'Unknown',
  'Unknown',
  'String',
  'String',
  'Unknown'
];

List<String> fieldTypes = [
  'TINY',
  'SHORT',
  'INT24',
  'LONGLONG',
  'LONG',
  'NEWDECIMAL',
  'FLOAT',
  'DOUBLE',
  'DOUBLE',
  'TINY',
  'BIT',
  'LONGLONG',
  'DATE',
  'DATETIME',
  'TIMESTAMP',
  'TIME',
  'YEAR',
  'STRING',
  'VAR_STRING',
  'BLOB',
  'BLOB',
  'BLOB',
  'BLOB',
  'STRING',
  'VAR_STRING',
  'BLOB',
  'BLOB',
  'BLOB',
  'BLOB',
  'STRING',
  'STRING',
  'GEOMETRY'
];

void main() {
  initializeTest(
      'test1',
      'create table test1 ('
          'atinyint tinyint, asmallint smallint, amediumint mediumint, abigint bigint, aint int, '
          'adecimal decimal(20,10), afloat float, adouble double, areal real, '
          'aboolean boolean, abit bit(20), aserial serial, '
          'adate date, adatetime datetime, atimestamp timestamp, atime time, ayear year, '
          'achar char(10), avarchar varchar(10), '
          'atinytext tinytext, atext text, amediumtext mediumtext, alongtext longtext, '
          'abinary binary(10), avarbinary varbinary(10), '
          'atinyblob tinyblob, amediumblob mediumblob, ablob blob, alongblob longblob, '
          'aenum enum("a", "b", "c"), aset set("a", "b", "c"), ageometry geometry)');

  test('show tables', () async {
    var results = await conn.query('show tables');
    expect(results.isNotEmpty, true);
    for (var r in results) {
      print(r);
    }
  });

  test('describe stuff', () async {
    var results = await conn.query('describe test1');
    print('table test1');
    _showResults(results);
  });

  test('small blobs', () async {
    var longstring = '';
    for (var i = 0; i < 200; i++) {
      longstring += 'x';
    }
    var results = await conn.query(
        'insert into test1 (atext) values (?)', [Blob.fromString(longstring)]);
    expect(results.affectedRows, equals(1));

    results = await conn.query('select atext from test1');
    expect(results.length, equals(1));
    expect((results.first[0] as Blob).toString().length, equals(200));
  });

  test('medium blobs', () async {
    var longstring = '';
    for (var i = 0; i < 2000; i++) {
      longstring += 'x';
    }
    var query = await conn.query(
        'insert into test1 (atext) values (?)', [Blob.fromString(longstring)]);
    expect(query.affectedRows, equals(1));

    var results = await conn.query('select atext from test1');
    var list = results.toList();
    expect(list.length, equals(1));
    expect((list.first[0] as Blob).toString().length, equals(2000));

    await conn.query('delete from test1');
    results = await conn.query('select atext from test1');
    list = results.toList();
    expect(list.isEmpty, true);
  });

  test('insert stuff', () async {
    var results = await conn.query(
      'insert into test1 (atinyint, asmallint, amediumint, abigint, aint, '
      'adecimal, afloat, adouble, areal, '
      'aboolean, abit, aserial, '
      'adate, adatetime, atimestamp, atime, ayear, '
      'achar, avarchar, atinytext, atext, amediumtext, alongtext, '
      'abinary, avarbinary, atinyblob, amediumblob, ablob, alongblob, '
      'aenum, aset) values'
      '(?, ?, ?, ?, ?, '
      '?, ?, ?, ?, '
      '?, ?, ?, '
      '?, ?, ?, ?, ?, '
      '?, ?, ?, ?, ?, ?, '
      '?, ?, ?, ?, ?, ?, '
      '?, ?)',
      insertValues,
    );

    expect(results.affectedRows, equals(1));

    await conn.query('update test1 set atinyint = ?, adecimal = ?',
        [127, '123456789.987654321']);

    results = await conn.query('select atinyint, adecimal from test1');
    var list = await results.toList();
    var row = list[0];
    expect(row[0], equals(127));
    expect(row[1], equals(123456789.987654321));
  });

  test('data types (query)', () async {
    await conn.query(
        'insert into test1 (atinyint, asmallint, amediumint, abigint, aint, '
        'adecimal, afloat, adouble, areal, '
        'aboolean, abit, aserial, '
        'adate, adatetime, atimestamp, atime, ayear, '
        'achar, avarchar, atinytext, atext, amediumtext, alongtext, '
        'abinary, avarbinary, atinyblob, amediumblob, ablob, alongblob, '
        'aenum, aset) values'
        '(?, ?, ?, ?, ?, '
        '?, ?, ?, ?, '
        '?, ?, ?, '
        '?, ?, ?, ?, ?, '
        '?, ?, ?, ?, ?, ?, '
        '?, ?, ?, ?, ?, ?, '
        '?, ?)',
        insertValues);

    var results = await conn.query('select * from test1');
    var list = await results.toList();
    var row = list[0];

    for (var i = 0; i < results.fields.length; i++) {
      print('i: $i');
      var field = results.fields[i];
      // field types
      expect(field.typeString, fieldTypes[i]);
      // make sure results types are the same
      expect(_typeof(row[i]), equals(valueTypes[i]));
      // make sure the values are the same
      if (row[i] is double) {
        // or at least close
        expect(row[i], closeTo(responseValues[i] as num, 0.1));
      } else {
        expect(row[i], equals(responseValues[i]));
      }
    }
  });

  test('multi queries', () async {
    await conn.transaction((ctx) async {
      var params = <List<int>>[];

      for (var i = 0; i < 50; i++) {
        params.add([i]);
      }
      var resultList =
          await ctx.queryMulti('insert into test1 (aint) values (?)', params);
      expect(resultList.length, equals(50));
    });
  });

  test('blobs in prepared queries', () async {
    var abc = Blob.fromBytes([65, 66, 67, 0, 68, 69, 70]);
    var results = await conn
        .query('insert into test1 (aint, atext) values (?, ?)', [12344, abc]);
    results =
        await conn.query('select atext from test1 where aint = 12344', []);
    var list = await results.toList();
    expect(list.length, equals(1));
    var values = list[0];
    expect(values[0].toString(), equals('ABC\u0000DEF'));
  });

  test('blobs with nulls', () async {
    await conn.query(
        'insert into test1 (aint, atext) values (12345, \'ABC\u0000DEF\')');
    var results =
        (await conn.query('select atext from test1 where aint = 12345'))
            .toList();
    expect(results.length, equals(1));
    var v = results.first;
    expect(v[0].toString(), equals('ABC\u0000DEF'));

    await conn.query('delete from test1 where aint = 12345');
    var abc = String.fromCharCodes([65, 66, 67, 0, 68, 69, 70]);
    await conn
        .query('insert into test1 (aint, atext) values (?, ?)', [12345, abc]);
    results =
        (await conn.query('select atext from test1 where aint = 12345', []))
            .toList();
    expect(results.length, equals(1));
    v = results[0];
    expect(v[0].toString(), equals('ABC\u0000DEF'));
  });

  test('datetimes are de-serialized in UTC', () async {
    var results = await conn.query(
        'insert into test1 (atinyint, asmallint, amediumint, abigint, aint, '
        'adecimal, afloat, adouble, areal, '
        'aboolean, abit, aserial, '
        'adate, adatetime, atimestamp, atime, ayear, '
        'achar, avarchar, atinytext, atext, amediumtext, alongtext, '
        'abinary, avarbinary, atinyblob, amediumblob, ablob, alongblob, '
        'aenum, aset) values'
        '(?, ?, ?, ?, ?, '
        '?, ?, ?, ?, '
        '?, ?, ?, '
        '?, ?, ?, ?, ?, '
        '?, ?, ?, ?, ?, ?, '
        '?, ?, ?, ?, ?, ?, '
        '?, ?)',
        insertValues);
    results = await conn.query('select adatetime from test1');

    // Normal
    var dt = results.first[0] as DateTime;
    expect(dt.isUtc, isTrue);

    // Binary packet
    results = await conn
        .query('select adatetime from test1 WHERE atinyint = ?', [126]);
    var dt2 = results.first[0] as DateTime;
    expect(dt2.isUtc, isTrue);

    expect(dt, equals(dt2));
  });

  test('result fields are accessible by name', () async {
    var results = await conn.query(
        'insert into test1 (atinyint, asmallint, amediumint, abigint, aint, '
        'adecimal, afloat, adouble, areal, '
        'aboolean, abit, aserial, '
        'adate, adatetime, atimestamp, atime, ayear, '
        'achar, avarchar, atinytext, atext, amediumtext, alongtext, '
        'abinary, avarbinary, atinyblob, amediumblob, ablob, alongblob, '
        'aenum, aset) values'
        '(?, ?, ?, ?, ?, '
        '?, ?, ?, ?, '
        '?, ?, ?, '
        '?, ?, ?, ?, ?, '
        '?, ?, ?, ?, ?, ?, '
        '?, ?, ?, ?, ?, ?, '
        '?, ?)',
        insertValues);

    // Normal
    results = await conn.query('select atinyint from test1');
    var v1 = results.first.fields['atinyint'] as int;
    var v2 = results.first['atinyint'] as int;
    expect(v1, isNotNull);
    expect(v2, equals(v1));

    // Binary packet
    results =
        await conn.query('select atinyint from test1 WHERE ? = ?', [1, 1]);
    var v3 = results.first.fields['atinyint'] as int;
    var v4 = results.first['atinyint'] as int;
    expect(v3, isNotNull);
    expect(v4, equals(v3));

    expect(v1, equals(v3));
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

void _showResults(Results results) {
  var fieldNames = <String>[];
  for (var field in results.fields) {
    fieldNames.add('${field.name}:${field.type}');
  }
  print(fieldNames);
  for (var row in results) {
    print(row);
  }
}

String _typeof(dynamic item) {
  if (item is String) {
    return 'String';
  } else if (item is int) {
    return 'int';
  } else if (item is double) {
    return 'double';
  } else if (item is DateTime) {
    return 'Date';
  } else if (item is Uint8List) {
    return 'Uint8List';
  } else if (item is List<int>) {
    return 'List<int>';
  } else if (item is List) {
    return 'List';
  } else if (item is Duration) {
    return 'Duration';
  } else {
    return 'Unknown';
  }
}
