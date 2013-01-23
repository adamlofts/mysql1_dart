part of integrationtests;

void runIntTests(String user, String password, String db, int port, String host) {
  ConnectionPool pool;
  group('some tests:', () {
    asyncTest('connect', 1, () {
      pool = new ConnectionPool(user:user, password:password, db:db, port:port, host:host);
      callbackDone();
    });
    
    asyncTest('dropTables', 1, () {
      new TableDropper(pool, ["test1"]).dropTables().then((x) {
        callbackDone();
      });
    });
    
    asyncTest('create tables', 1, () {
      pool.query("create table test1 ("
        "atinyint tinyint, asmallint smallint, amediumint mediumint, abigint bigint, aint int, "
        "adecimal decimal(20,10), afloat float, adouble double, areal real, "
        "aboolean boolean, abit bit(20), aserial serial, "
        "adate date, adatetime datetime, atimestamp timestamp, atime time, ayear year, "
        "achar char(10), avarchar varchar(10), "
        "atinytext tinytext, atext text, amediumtext mediumtext, alongtext longtext, "
        "abinary binary(10), avarbinary varbinary(10), "
        "atinyblob tinyblob, amediumblob mediumblob, ablob blob, alongblob longblob, "
        "aenum enum('a', 'b', 'c'), aset set('a', 'b', 'c'), ageometry geometry)").then((Results results) {
//          expect(1).equals(results.affectedRows);
          callbackDone();
        });
    });
    
    asyncTest('show tables', 1, () {
      pool.query("show tables").then((Results results) {
        print("tables");
        for (var row in results) {
          print(row);
        }
        callbackDone();
      });
    });
    
    asyncTest('describe stuff', 1, () {
      pool.query("describe test1").then((Results results) {
        print("table test1");
        showResults(results);
        callbackDone();
      });
    });
    
    asyncTest('insert stuff', 1, () {
      print("insert stuff test");
      pool.prepare("insert into test1 (atinyint, asmallint, amediumint, abigint, aint, "
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
        "?, ?)").then((Query query) {
          query[0] = 126;
          query[1] = 164;
          query[2] = 165;
          query[3] = 166;
          query[4] = 167;
          
          query[5] = 592;
          query[6] = 123.456;
          query[7] = 123.456;
          query[8] = 123.456;
          
          query[9] = true;
          query[10] = [1, 2, 3];
          query[11] = 123;
          
          query[12] = new Date.now();
          query[13] = new Date.now();
          query[14] = new Date.now();
          query[15] = new Date.now();
          query[16] = 2012;
          
          query[17] = "Hello";
          query[18] = "Hey";
          query[19] = "Hello there";
          query[20] = "Good morning";
          query[21] = "Habari boss";
          query[22] = "Bonjour";
    
          query[23] = [65, 66, 67, 68];
          query[24] = [65, 66, 67, 68];
          query[25] = [65, 66, 67, 68];
          query[26] = [65, 66, 67, 68];
          query[27] = [65, 66, 67, 68];
          query[28] = [65, 66, 67, 68];
          
          query[29] = "a";
          query[30] = "a,b";
                 
          print("executing");
          return query.execute();
        }).then((results) {
          expect(results.affectedRows, equals(1));
          print("updated ${results.affectedRows} ${results.insertId}");
          callbackDone();
        });
    });
    
    asyncTest('select everything', 1, () {
      pool.query('select * from test1').then((results) {
        expect(results.count, equals(1));
        callbackDone();
      });
    });
    
    asyncTest('update', 1, () {
      Query preparedQuery;
      pool.prepare("update test1 set atinyint = ?, adecimal = ?").then((query) {
        preparedQuery = query;
        query[0] = 127;
        query[1] = "123456789.987654321";
        return query.execute();
      }).then((results) {
        preparedQuery.close();
        callbackDone();
      });
    });
    
    asyncTest('select stuff', 1, () {
      pool.query("select atinyint, adecimal from test1").then((results) {
        var it = results.iterator;
        it.moveNext();
        var row = it.current;
        Expect.equals(127, row[0]);
        Expect.equals(123456789.987654321, row[1]);
        callbackDone();
      });
    });
    
    asyncTest('prepare execute', 1, () {
      pool.prepareExecute('insert into test1 (atinyint, adecimal) values (?, ?)', [123, 123.321]).then((results) {
        Expect.equals(1, results.affectedRows);
        callbackDone();
      });
    });
    
    List<Field> preparedFields;
    List<dynamic> values;
    
    asyncTest('data types (prepared)', 1, () {
      pool.prepareExecute('select * from test1', []).then((results) {
        print("----------- prepared results ---------------");
        preparedFields = results.fields;
        var it = results.iterator;
        it.moveNext();
        values = it.current;
        for (var i = 0; i < results.fields.length; i++) {
          var field = results.fields[i];
          print("${field.name} ${fieldTypeToString(field.type)} ${typeof(values[i])}");
        }
        callbackDone();
      });
    });

    asyncTest('data types (query)', 1, () {
      pool.query('select * from test1').then((results) {
        print("----------- query results ---------------");
        var it = results.iterator;
        it.moveNext();
        var row = it.current;
        for (var i = 0; i < results.fields.length; i++) {
          var field = results.fields[i];
          
          // make sure field types returned by both queries are the same
          expect(field.type, equals(preparedFields[i].type));
          // make sure results types are the same
          expect(typeof(row[i]), equals(typeof(values[i])));
          // make sure the values are the same
          if (row[i] is double) {
            // or at least close
            expect(row[i], closeTo(values[i], 0.1));
          } else if (row[i] is Collection) {
            expect(row[i], equals(values[i]));
          } else {
            expect(row[i], equals(values[i]));
          }
          print("${field.name} ${fieldTypeToString(field.type)} ${typeof(row[i])}");
        }
        callbackDone();
      });
    });
    
    asyncTest('multi queries', 1, () {
      pool.startTransaction().then((trans) {
        var start = new Date.now();
        trans.prepare('insert into test1 (aint) values (?)').then((query) {
          var params = [];
          for (var i = 0; i < 50; i++) {
            params.add([i]);
          }
          query.executeMulti(params).then((resultList) {
            var end = new Date.now();
            print(end.difference(start));
            expect(resultList.length, equals(50));
            trans.commit().then((x) {
              callbackDone();
            });
          });
        });
      });
    });

    test('close connection', () {
      pool.close();
    });
  });
}

void showResults(Results results) {
  var fieldNames = <String>[];
  for (var field in results.fields) {
    fieldNames.add("${field.name}:${field.type}");
  }
  print(fieldNames);
  for (var row in results) {
    print(row);
  }
}

String typeof(dynamic item) {
  if (item is String) {
    return "String";
  } else if (item is int) {
    return "int";
  } else if (item is double) {
    return "double";
  } else if (item is Date) {
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
