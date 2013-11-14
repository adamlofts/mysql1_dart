part of integrationtests;

void runIntTests(String user, String password, String db, int port, String host) {
  ConnectionPool pool;
  group('some tests:', () {
    test('create pool', () {
      pool = new ConnectionPool(user:user, password:password, db:db, port:port, host:host);
      expect(pool, isNotNull);
    });
    
    test('dropTables', () {
      new TableDropper(pool, ["test1"]).dropTables().then(expectAsync1((_) {
        expect(1, equals(1)); // not quite sure of the async testing stuff yet
      }));
    });
    
    test('create tables', () {
      return pool.query("create table test1 ("
        "atinyint tinyint, asmallint smallint, amediumint mediumint, abigint bigint, aint int, "
        "adecimal decimal(20,10), afloat float, adouble double, areal real, "
        "aboolean boolean, abit bit(20), aserial serial, "
        "adate date, adatetime datetime, atimestamp timestamp, atime time, ayear year, "
        "achar char(10), avarchar varchar(10), "
        "atinytext tinytext, atext text, amediumtext mediumtext, alongtext longtext, "
        "abinary binary(10), avarbinary varbinary(10), "
        "atinyblob tinyblob, amediumblob mediumblob, ablob blob, alongblob longblob, "
        "aenum enum('a', 'b', 'c'), aset set('a', 'b', 'c'), ageometry geometry)").then((Results results) {
          expect(results.affectedRows, equals(0));
          expect(results.insertId, equals(0));
          return results.toList().then((list) {
            expect(list, hasLength(0));
          });
        });
    });
    
    test('show tables', () {
      var c = new Completer();
      pool.query("show tables").then(expectAsync1((Results results) {
        print("tables");
        results.listen((row) {
          print("table: $row");
        }, onDone: () {
          c.complete();
        });
      }));
      return c.future;
    });
    
    test('describe stuff', () {
      var c = new Completer();
      pool.query("describe test1").then(expectAsync1((Results results) {
        print("table test1");
        showResults(results).then((_) {
          c.complete();
        });
      }));
      return c.future;
    });
    
    test('small blobs', () {
      var c = new Completer();
      pool.prepare("insert into test1 (atext) values (?)").then((query) {
        var longstring = "";
        for (var i = 0; i < 200; i++) {
          longstring += "x";
        }
        return query.execute([new Blob.fromString(longstring)]);
      }).then((results) {
        expect(results.affectedRows, equals(1));
        
//        return pool.query("select atext from test1 where length(atext) > 1000");
        return pool.query("select atext from test1");
      }).then((results) {
        return results.toList();
      }).then((list) {
        expect(list.length, equals(1));
        expect((list[0][0] as Blob).toString().length, equals(200));
        c.complete();
      });
      return c.future;
    });
    
    test('medium blobs', () {
      var c = new Completer();
      pool.prepare("insert into test1 (atext) values (?)").then((query) {
        var longstring = "";
        for (var i = 0; i < 2000; i++) {
          longstring += "x";
        }
        return query.execute([new Blob.fromString(longstring)]);
      }).then((results) {
        expect(results.affectedRows, equals(1));
        
//        return pool.query("select atext from test1 where length(atext) > 1000");
        return pool.query("select atext from test1");
      }).then((results) {
        return results.toList();
      }).then((list) {
        expect(list.length, equals(2));
        expect((list[1][0] as Blob).toString().length, equals(2000));
        c.complete();
      });
      return c.future;
    });
    
    test('clear stuff', () {
      return pool.query('delete from test1');
    });
    
    test('insert stuff', () {
      var c = new Completer();
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
          values.add(0x010203);//[1, 2, 3]);
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
          return query.execute(values);
        }).then((results) {
          print("updated ${results.affectedRows} ${results.insertId}");
          expect(results.affectedRows, equals(1));
          c.complete();
        });
      return c.future;
    });
    
    test('select everything', () {
      var c = new Completer();
      pool.query('select * from test1').then((results) {
        results.toList().then((list) {
          expect(list.length, equals(1));
          var row = list.first;
          expect(row[10], equals(0x010203));
          c.complete();
        });
      });
      return c.future;
    });

    test('update', () {
      var c = new Completer();
      Query preparedQuery;
      pool.prepare("update test1 set atinyint = ?, adecimal = ?").then((query) {
        preparedQuery = query;
        expect(1, equals(1)); // put some real expectations here
        return query.execute([127, "123456789.987654321"]);
      }).then((results) {
        preparedQuery.close();
        c.complete();
      });
      return c.future;
    });
    
    test('select stuff', () {
      var c = new Completer();
      pool.query("select atinyint, adecimal from test1").then((results) {
        results.toList().then((list) {
          var row = list[0];
          expect(row[0], equals(127));
          expect(row[1], equals(123456789.987654321));
          c.complete();
        });
      });
      return c.future;
    });
    
    test('prepare execute', () {
      var c = new Completer();
      pool.prepareExecute('insert into test1 (atinyint, adecimal) values (?, ?)', [123, 123.321]).then((results) {
        expect(results.affectedRows, equals(1));
        c.complete();
      });
      return c.future;
    });
    
    List<Field> preparedFields;
    List<dynamic> values;
    
    test('data types (prepared)', () {
      var c = new Completer();
      pool.prepareExecute('select * from test1', []).then((results) {
        print("----------- prepared results ---------------");
        preparedFields = results.fields;
        results.toList().then((list) {
          values = list[0];
          for (var i = 0; i < results.fields.length; i++) {
            var field = results.fields[i];
            print("${field.name} ${fieldTypeToString(field.type)} ${typeof(values[i])}");
          }
          c.complete();
        });
      });
      return c.future;
    });

    test('data types (query)', () {
      var c = new Completer();
      pool.query('select * from test1').then((results) {
        print("----------- query results ---------------");
        results.toList().then((list) {
          var row = list[0];
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
          c.complete();
        });
      });
      return c.future;
    });

    test('multi queries', () {
      var c = new Completer();
      pool.startTransaction().then((trans) {
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
            trans.commit().then((_) {
              c.complete();
            });
          });
        });
      });
      return c.future;
    });

    test('blobs in prepared queries', () {
      var c = new Completer();
      var abc = new Blob.fromBytes([65, 66, 67, 0, 68, 69, 70]);
      pool.prepareExecute("insert into test1 (aint, atext) values (?, ?)", [12344, abc]).then((results) {
        expect(1, equals(1)); // put some real expectations here
        return pool.prepareExecute("select atext from test1 where aint = 12344", []);
      }).then((results) {
        results.toList().then((list) {
          expect(list.length, equals(1));
          values = list[0];
          expect(values[0].toString(), equals("ABC\u0000DEF"));
          c.complete();
        });
      });
      return c.future;
    });

    test('blobs with nulls', () {
      var c = new Completer();
      pool.query("insert into test1 (aint, atext) values (12345, \"ABC\u0000DEF\")").then((results) {
        expect(1, equals(1)); // put some real expectations here
        return pool.query("select atext from test1 where aint = 12345");
      }).then((results) {
        return results.toList();
      }).then((results) {
        expect(results.length, equals(1));
        values = results[0];
        expect(values[0].toString(), equals("ABC\u0000DEF"));

        return pool.query("delete from test1 where aint = 12345");
      }).then((results) {
        var abc = new String.fromCharCodes([65, 66, 67, 0, 68, 69, 70]);
        expect(1, equals(1)); // put some real expectations here
        return pool.prepareExecute("insert into test1 (aint, atext) values (?, ?)", [12345, abc]);
      }).then((results) {
        expect(1, equals(1)); // put some real expectations here
        return pool.prepareExecute("select atext from test1 where aint = 12345", []);
      }).then((results) {
        return results.toList();
      }).then((results) {
        expect(results.length, equals(1));
        values = results[0];
        expect(values[0].toString(), equals("ABC\u0000DEF"));
        c.complete();
      });
      return c.future;
    });

    test('close connection', () {
      pool.close();
    });
  });
}

Future showResults(Results results) {
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
