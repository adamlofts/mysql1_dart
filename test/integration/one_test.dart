library sqljocky.test.one_test;

import 'dart:async';

import 'package:sqljocky2/sqljocky.dart';
import 'package:sqljocky2/constants.dart';
import 'package:sqljocky2/utils.dart';
import 'package:test/test.dart';

import '../test_infrastructure.dart';

import 'dart:typed_data';

void main() {
  initializeTest();

  test('dropTables', () async {
    await new TableDropper(pool, ["test1"]).dropTables();
  });

  test('create tables', () async {
    var results = await pool.query("create table test1 ("
        "atinyint tinyint, asmallint smallint, amediumint mediumint, abigint bigint, aint int, "
        "adecimal decimal(20,10), afloat float, adouble double, areal real, "
        "aboolean boolean, abit bit(20), aserial serial, "
        "adate date, adatetime datetime, atimestamp timestamp, atime time, ayear year, "
        "achar char(10), avarchar varchar(10), "
        "atinytext tinytext, atext text, amediumtext mediumtext, alongtext longtext, "
        "abinary binary(10), avarbinary varbinary(10), "
        "atinyblob tinyblob, amediumblob mediumblob, ablob blob, alongblob longblob, "
        "aenum enum('a', 'b', 'c'), aset set('a', 'b', 'c'), ageometry geometry)");
    expect(results.affectedRows, equals(0));
    expect(results.insertId, equals(0));
    var list = await results.toList();
    expect(list, hasLength(0));
  });

  test('show tables', () async {
    var c = new Completer();
    var results = await pool.query("show tables");
    print("tables");
    results.listen((row) {
      print("table: $row");
    }, onDone: () {
      c.complete();
    });
    return c.future;
  });

  test('describe stuff', () async {
    var results = await pool.query("describe test1");
    print("table test1");
    await _showResults(results);
  });

  test('small blobs', () async {
    var query = await pool.prepare("insert into test1 (atext) values (?)");
    var longstring = "";
    for (var i = 0; i < 200; i++) {
      longstring += "x";
    }
    var results = await query.execute([new Blob.fromString(longstring)]);
    expect(results.affectedRows, equals(1));

    results = await pool.query("select atext from test1");
    var list = await results.toList();
    expect(list.length, equals(1));
    expect((list[0][0] as Blob).toString().length, equals(200));
  });

  test('medium blobs', () async {
    var query = await pool.prepare("insert into test1 (atext) values (?)");
    var longstring = "";
    for (var i = 0; i < 2000; i++) {
      longstring += "x";
    }
    var results = await query.execute([new Blob.fromString(longstring)]);
    expect(results.affectedRows, equals(1));

    results = await pool.query("select atext from test1");
    var list = await results.toList();
    expect(list.length, equals(2));
    expect((list[1][0] as Blob).toString().length, equals(2000));
  });

  test('clear stuff', () {
    return pool.query('delete from test1');
  });

  test('insert stuff', () async {
    print("insert stuff test");
    var query = await pool.prepare(
        "insert into test1 (atinyint, asmallint, amediumint, abigint, aint, "
        "adecimal, afloat, adouble, areal, "
        "aboolean, abit, aserial, "
        "adate, adatetime, atimestamp, atime, ayear, "
        "achar, avarchar, atinytext, atext, amediumtext, alongtext, "
        "abinary, avarbinary, atinyblob, amediumblob, ablob, alongblob, "
        "aenum, aset) values"
        "(?, ?, ?, ?, ?, "
        "?, ?, ?, ?, "
        "?, ?, ?, "
        "?, ?, ?, ?, ?, "
        "?, ?, ?, ?, ?, ?, "
        "?, ?, ?, ?, ?, ?, "
        "?, ?)");
    var values = [];
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

    values.add(new DateTime.now());
    values.add(new DateTime.now());
    values.add(new DateTime.now());
    values.add(new DateTime.now());
    values.add(2012);

    values.add("Hello");
    values.add("Hey");
    values.add("Hello there");
    values.add("Good morning");
    values.add("Habari boss");
    values.add("Bonjour");

    values.add([65, 66, 67, 68]);
    values.add([65, 66, 67, 68]);
    values.add([65, 66, 67, 68]);
    values.add([65, 66, 67, 68]);
    values.add([65, 66, 67, 68]);
    values.add([65, 66, 67, 68]);

    values.add("a");
    values.add("a,b");

    print("executing");
    expect(1, equals(1)); // put some real expectations here
    var results = await query.execute(values);
    print("updated ${results.affectedRows} ${results.insertId}");
    expect(results.affectedRows, equals(1));
  });

  test('select everything', () async {
    var results = await pool.query('select * from test1');
    var list = await results.toList();
    expect(list.length, equals(1));
    var row = list.first;
    expect(row[10], equals(0x010203));
  });

  test('update', () async {
    Query preparedQuery;
    var query =
        await pool.prepare("update test1 set atinyint = ?, adecimal = ?");
    preparedQuery = query;
    expect(1, equals(1)); // put some real expectations here
    await query.execute([127, "123456789.987654321"]);
    preparedQuery.close();
  });

  test('select stuff', () async {
    var results = await pool.query("select atinyint, adecimal from test1");
    var list = await results.toList();
    var row = list[0];
    expect(row[0], equals(127));
    expect(row[1], equals(123456789.987654321));
  });

  test('prepare execute', () async {
    var results = await pool.prepareExecute(
        'insert into test1 (atinyint, adecimal) values (?, ?)', [123, 123.321]);
    expect(results.affectedRows, equals(1));
  });

  List<Field> preparedFields;
  List<dynamic> values;

  test('data types (prepared)', () async {
    var results = await pool.prepareExecute('select * from test1', []);
    print("----------- prepared results ---------------");
    preparedFields = results.fields;
    var list = await results.toList();
    values = list[0];
    for (var i = 0; i < results.fields.length; i++) {
      var field = results.fields[i];
      print(
          "${field.name} ${fieldTypeToString(field.type)} ${_typeof(values[i])}");
    }
  });

  test('data types (query)', () async {
    var results = await pool.query('select * from test1');
    print("----------- query results ---------------");
    var list = await results.toList();
    var row = list[0];
    for (var i = 0; i < results.fields.length; i++) {
      var field = results.fields[i];

      // make sure field types returned by both queries are the same
      expect(field.type, equals(preparedFields[i].type));
      // make sure results types are the same
      expect(_typeof(row[i]), equals(_typeof(values[i])));
      // make sure the values are the same
      if (row[i] is double) {
        // or at least close
        expect(row[i], closeTo(values[i], 0.1));
      } else {
        expect(row[i], equals(values[i]));
      }
      print(
          "${field.name} ${fieldTypeToString(field.type)} ${_typeof(row[i])}");
    }
  });

  test('multi queries', () async {
    var trans = await pool.startTransaction();
    var start = new DateTime.now();
    var query = await trans.prepare('insert into test1 (aint) values (?)');
    var params = [];
    for (var i = 0; i < 50; i++) {
      params.add([i]);
    }
    var resultList = await query.executeMulti(params);
    var end = new DateTime.now();
    print(end.difference(start));
    expect(resultList.length, equals(50));
    await trans.commit();
  });

  test('blobs in prepared queries', () async {
    var abc = new Blob.fromBytes([65, 66, 67, 0, 68, 69, 70]);
    var results = await pool.prepareExecute(
        "insert into test1 (aint, atext) values (?, ?)", [12344, abc]);
    expect(1, equals(1)); // put some real expectations here
    results = await pool
        .prepareExecute("select atext from test1 where aint = 12344", []);
    var list = await results.toList();
    expect(list.length, equals(1));
    values = list[0];
    expect(values[0].toString(), equals("ABC\u0000DEF"));
  });

  test('blobs with nulls', () async {
    var results = await pool.query(
        "insert into test1 (aint, atext) values (12345, \"ABC\u0000DEF\")");
    expect(1, equals(1)); // put some real expectations here
    results = await pool.query("select atext from test1 where aint = 12345");
    results = await results.toList();
    expect(results.length, equals(1));
    values = results[0];
    expect(values[0].toString(), equals("ABC\u0000DEF"));

    results = await pool.query("delete from test1 where aint = 12345");
    var abc = new String.fromCharCodes([65, 66, 67, 0, 68, 69, 70]);
    expect(1, equals(1)); // put some real expectations here
    results = await pool.prepareExecute(
        "insert into test1 (aint, atext) values (?, ?)", [12345, abc]);
    expect(1, equals(1)); // put some real expectations here
    results = await pool
        .prepareExecute("select atext from test1 where aint = 12345", []);
    results = await results.toList();
    expect(results.length, equals(1));
    values = results[0];
    expect(values[0].toString(), equals("ABC\u0000DEF"));
  });
}

Future _showResults(Results results) {
  var c = new Completer();
  var fieldNames = <String>[];
  for (var field in results.fields) {
    fieldNames.add("${field.name}:${field.type}");
  }
  print(fieldNames);
  results.listen((row) {
    print(row);
  }, onDone: () {
    c.complete(null);
  });

  return c.future;
}

String _typeof(dynamic item) {
  if (item is String) {
    return "String";
  } else if (item is int) {
    return "int";
  } else if (item is double) {
    return "double";
  } else if (item is DateTime) {
    return "Date";
  } else if (item is Uint8List) {
    return "Uint8List";
  } else if (item is List<int>) {
    return "List<int>";
  } else if (item is List) {
    return "List";
  } else if (item is Duration) {
    return "Duration";
  } else {
    return "Unknown";
  }
}
