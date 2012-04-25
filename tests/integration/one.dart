runTests(String user, String password, String db, int port, String host) {
  Connection cnx;
  group('some tests:', () {
    asyncTest('connect', 1, () {
      cnx = new Connection();
      cnx.connect(user:user, password:password, db:db, port:port, host:host).then((nothing) {
        callbackDone();
      });
    });
    
    asyncTest('dropTables', 1, () {
      var tables = ["test1"];

      void dropTables(Connection cnx1) {
        String table = tables.last();
        tables.removeLast();
//        print("drop table $table");
        Future future = cnx1.query("drop table $table");
        future.handleException((exception) {
          if (exception is MySqlError && exception.errorNumber == 1051) {
//            print("no table to delete");
            if (tables.length == 0) {
              callbackDone();
            } else {
              dropTables(cnx1);
            }
          }
          return true;
        });
        future.then((x) {
//          print("deleted");
          if (tables.length == 0) {
            callbackDone();
          } else {
            dropTables(cnx1);
          }
        });
      }
      
      dropTables(cnx);
    });
    
    asyncTest('create tables', 1, () {
      cnx.query("create table test1 ("
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
      cnx.query("show tables").then((Results results) {
        print("tables");
        for (List<Dynamic> row in results) {
          print(row);
        }
        callbackDone();
      });
    });
    
    asyncTest('describe stuff', 1, () {
      cnx.query("describe test1").then((Results results) {
        print("table test1");
        showResults(results);
        callbackDone();
      });
    });
    
    asyncTest('insert stuff', 1, () {
      cnx.prepare("insert into test1 (atinyint, asmallint, amediumint, abigint, aint, "
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
        "?, ?)").chain((Query query) {
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
                 
          return query.execute();
        }).then((Results results) {
          expect(results.affectedRows).equals(1);
          print("updated ${results.affectedRows} ${results.insertId}");
          callbackDone();
        });
    });
    
    asyncTest('select everything', 1, () {
      cnx.query('select * from test1').then((Results results) {
//        expect(results.count).equals(1);
        callbackDone();
      });
    });
    
    asyncTest('update', 1, () {
      Query preparedQuery;
      cnx.prepare("update test1 set atinyint = ?, adecimal = ?").chain((Query query) {
        preparedQuery = query;
        query[0] = 127;
        query[1] = "123456789.987654321";
        return query.execute();
      }).then((Results results) {
        preparedQuery.close();
        callbackDone();
      });
    });
    
    asyncTest('select stuff', 1, () {
      cnx.query("select atinyint, adecimal from test1").then((Results results) {
        List row = results.iterator().next();
        Expect.equals(127, row[0]);
        Expect.equals(123456789.987654321, row[1]);
        callbackDone();
      });
    });
    
    asyncTest('prepare execute', 1, () {
      cnx.prepareExecute('insert into test1 (atinyint, adecimal) values (?, ?)', [123, 123.321]).then((Results results) {
        Expect.equals(1, results.affectedRows);
        callbackDone();
      });
    });
    
    List<Field> preparedFields;
    List<Dynamic> values;
    
    asyncTest('data types (prepared)', 1, () {
      cnx.prepareExecute('select * from test1', []).then((Results results) {
        print("----------- prepared results ---------------");
        preparedFields = results.fields;
        values = results.iterator().next();
        for (int i = 0; i < results.fields.length; i++) {
          Field field = results.fields[i];
          print("${field.name} ${fieldTypeToString(field.type)} ${typeof(values[i])}");
        }
        callbackDone();
      });
    });

    asyncTest('data types (query)', 1, () {
      cnx.query('select * from test1').then((Results results) {
        print("----------- query results ---------------");
        List row = results.iterator().next();
        for (int i = 0; i < results.fields.length; i++) {
          Field field = results.fields[i];
          
          // make sure field types returned by both queries are the same
          expect(field.type).equals(preparedFields[i].type);
          // make sure results types are the same
          expect(typeof(row[i])).equals(typeof(values[i]));
          // make sure the values are the same
          if (row[i] is double) {
            // or at least close
            expect(row[i]).approxEquals(values[i]);
          } else if (row[i] is Collection) {
            expect(row[i]).equalsCollection(values[i]);
          } else {
            expect(row[i]).equals(values[i]);
          }
          print("${field.name} ${fieldTypeToString(field.type)} ${typeof(row[i])}");
        }
        callbackDone();
      });
    });
    
    asyncTest('multi queries', 1, () {
      Date start = new Date.now();
      cnx.prepare('insert into test1 (aint) values (?)').then((Query query) {
        var params = [];
        for (int i = 0; i < 50; i++) {
          params.add([i]);
        }
        query.executeMulti(params).then((List<Results> resultList) {
          Date end = new Date.now();
          print(end.difference(start));
          expect(resultList.length).equals(50);
          callbackDone();
        });
      });
    });

    test('close connection', () {
      cnx.close();
    });
  });
}

void showResults(Results results) {
  List<String> fieldNames = <String>[];
  for (Field field in results.fields) {
    fieldNames.add("${field.name}:${field.type}");
  }
  print(fieldNames);
  for (List<Dynamic> row in results) {
    print(row);
  }
}

String typeof(Dynamic item) {
  if (item is String) {
    return "String";
  } else if (item is int) {
    return "int";
  } else if (item is double) {
    return "double";
  } else if (item is Date) {
    return "Date";
  } else if (item is ByteArray) {
    return "ByteArray";
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