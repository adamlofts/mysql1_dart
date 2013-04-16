part of integrationtests;

void runIntTests(String user, String password, String db, int port, String host) {
  ConnectionPool pool;
  group('some tests:', () {
    test('create pool', () {
      pool = new ConnectionPool(user:user, password:password, db:db, port:port, host:host);
      expect(pool, isNotNull);
    });
    
    test('dropTables', () {
      new TableDropper(pool, ["test1"]).dropTables().then(expectAsync1((x) {
        expect(1, equals(1)); // not quite sure of the async testing stuff yet
      }));
    });
    
    test('create tables', () {
      pool.query("create table test1 ("
        "atinyint tinyint, asmallint smallint, amediumint mediumint, abigint bigint, aint int, "
        "adecimal decimal(20,10), afloat float, adouble double, areal real, "
        "aboolean boolean, abit bit(20), aserial serial, "
        "adate date, adatetime datetime, atimestamp timestamp, atime time, ayear year, "
        "achar char(10), avarchar varchar(10), "
        "atinytext tinytext, atext text, amediumtext mediumtext, alongtext longtext, "
        "abinary binary(10), avarbinary varbinary(10), "
        "atinyblob tinyblob, amediumblob mediumblob, ablob blob, alongblob longblob, "
        "aenum enum('a', 'b', 'c'), aset set('a', 'b', 'c'), ageometry geometry)").then(expectAsync1((Results results) {
          expect(results.count, equals(0));
        }));
    });
    
    test('show tables', () {
      pool.query("show tables").then(expectAsync1((Results results) {
        print("tables");
        for (var row in results) {
          print(row);
        }
        expect(1, equals(1)); // put some real expectations here
      }));
    });
    
    test('describe stuff', () {
      pool.query("describe test1").then(expectAsync1((Results results) {
        print("table test1");
        showResults(results);
        expect(1, equals(1)); // put some real expectations here
      }));
    });
    
    test('insert stuff', () {
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
        "?, ?)").then(expectAsync1((Query query) {
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
          
          query[12] = new DateTime.now();
          query[13] = new DateTime.now();
          query[14] = new DateTime.now();
          query[15] = new DateTime.now();
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
          expect(1, equals(1)); // put some real expectations here
          return query.execute();
        })).then(expectAsync1((results) {
          print("updated ${results.affectedRows} ${results.insertId}");
          expect(results.affectedRows, equals(1));
        }));
    });
    
    test('select everything', () {
      pool.query('select * from test1').then(expectAsync1((results) {
        expect(results.count, equals(1));
      }));
    });

    test('update', () {
      Query preparedQuery;
      pool.prepare("update test1 set atinyint = ?, adecimal = ?").then(expectAsync1((query) {
        preparedQuery = query;
        query[0] = 127;
        query[1] = "123456789.987654321";
        expect(1, equals(1)); // put some real expectations here
        return query.execute();
      })).then(expectAsync1((results) {
        preparedQuery.close();
        expect(1, equals(1)); // put some real expectations here
      }));
    });
    
    test('select stuff', () {
      pool.query("select atinyint, adecimal from test1").then(expectAsync1((results) {
        var it = results.iterator;
        it.moveNext();
        var row = it.current;
        expect(row[0], equals(127));
        expect(row[1], equals(123456789.987654321));
      }));
    });
    
    test('prepare execute', () {
      pool.prepareExecute('insert into test1 (atinyint, adecimal) values (?, ?)', [123, 123.321]).then(expectAsync1((results) {
        expect(results.affectedRows, equals(1));
      }));
    });
    
    List<Field> preparedFields;
    List<dynamic> values;
    
    test('data types (prepared)', () {
      pool.prepareExecute('select * from test1', []).then(expectAsync1((results) {
        print("----------- prepared results ---------------");
        preparedFields = results.fields;
        var it = results.iterator;
        it.moveNext();
        values = it.current;
        for (var i = 0; i < results.fields.length; i++) {
          var field = results.fields[i];
          print("${field.name} ${fieldTypeToString(field.type)} ${typeof(values[i])}");
        }
        expect(1, equals(1)); // put some real expectations here
      }));
    });

    test('data types (query)', () {
      pool.query('select * from test1').then(expectAsync1((results) {
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
//          } else if (row[i] is Collection) {
//            expect(row[i], equals(values[i]));
          } else {
            expect(row[i], equals(values[i]));
          }
          print("${field.name} ${fieldTypeToString(field.type)} ${typeof(row[i])}");
        }
      }));
    });
    
    test('multi queries', () {
      pool.startTransaction().then(expectAsync1((trans) {
        var start = new DateTime.now();
        trans.prepare('insert into test1 (aint) values (?)').then((query) {
          var params = [];
          for (var i = 0; i < 50; i++) {
            params.add([i]);
          }
          query.executeMulti(params).then((resultList) {
            var end = new DateTime.now();
            print(end.difference(start));
            expect(resultList.length, equals(50));
            trans.commit().then(expectAsync1((x) {
              expect(1, equals(1)); // put some real expectations here
            }));
          });
        });
      }));
    });

    test('blobs in prepared queries', () {
      var abc = new Blob.fromBytes([65, 66, 67, 0, 68, 69, 70]);
      pool.prepareExecute("insert into test1 (aint, atext) values (?, ?)", [12344, abc]).then(expectAsync1((results) {
        expect(1, equals(1)); // put some real expectations here
        return pool.prepareExecute("select atext from test1 where aint = 12344", []);
      })).then(expectAsync1((results) {
        expect(results.count, equals(1));
        var it = results.iterator;
        it.moveNext();
        values = it.current;
        expect(values[0].toString(), equals("ABC\u0000DEF"));
      }));
    });

    test('blobs with nulls', () {
      pool.query("insert into test1 (aint, atext) values (12345, \"ABC\u0000DEF\")").then(expectAsync1((results) {
        expect(1, equals(1)); // put some real expectations here
        return pool.query("select atext from test1 where aint = 12345");
      })).then(expectAsync1((results) {
        expect(results.count, equals(1));
        var it = results.iterator;
        it.moveNext();
        values = it.current;
        expect(values[0].toString(), equals("ABC\u0000DEF"));

        return pool.query("delete from test1 where aint = 12345");
      })).then(expectAsync1((results) {
        var abc = new String.fromCharCodes([65, 66, 67, 0, 68, 69, 70]);
        expect(1, equals(1)); // put some real expectations here
        return pool.prepareExecute("insert into test1 (aint, atext) values (?, ?)", [12345, abc]);
      })).then(expectAsync1((results) {
        expect(1, equals(1)); // put some real expectations here
        return pool.prepareExecute("select atext from test1 where aint = 12345", []);
      })).then(expectAsync1((results) {
        expect(results.count, equals(1));
        var it = results.iterator;
        it.moveNext();
        values = it.current;
        expect(values[0].toString(), equals("ABC\u0000DEF"));
      }));
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
