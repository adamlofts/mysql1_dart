class One {
  List<String> tables;
  String _user;
  String _password;
  String _db;
  int _port;
  String _host;
  
  One([String user, String password, String db, int port=3306, String host='localhost']) {
    _user = user;
    _password = password;
    _db = db;
    _port = port;
    _host = host;
  }
  
  Completer _completer;
  
  Future runAll() {
    _completer = new Completer();
//    tables = ["test1", "test2", "test3"];
    tables = ["test1"];
    
    Connection cnx = new Connection();
    cnx.connect(user:_user, password:_password, db:_db, port:_port, host:_host).then((nothing) {
      // check use database works
      cnx.useDatabase(_db).then((dummy) {
        dropTables(cnx);
      });
    });
    return _completer.future;
  }
  
  void dropTables(Connection cnx) {
    String table = tables.last();
    tables.removeLast();
    print("drop table $table");
    Future future = cnx.query("drop table $table");
    future.handleException((exception) {
      if (exception is MySqlError && exception.errorNumber == 1051) {
        print("no table to delete");
        if (tables.length == 0) {
          createTables(cnx);
        } else {
          dropTables(cnx);
        }
      }
      return true;
    });
    future.then((x) {
      print("deleted");
      if (tables.length == 0) {
        createTables(cnx);
      } else {
        dropTables(cnx);
      }
    });
  }
  
  void createTables(Connection cnx) {
    print("creating tables");
    Future f = cnx.query("create table test1 ("
      "atinyint tinyint, asmallint smallint, amediumint mediumint, abigint bigint, aint int, "
      "adecimal decimal(20,10), afloat float, adouble double, areal real, "
      "aboolean boolean, abit bit(20), aserial serial, "
      "adate date, adatetime datetime, atimestamp timestamp, atime time, ayear year, "
      "achar char(10), avarchar varchar(10), "
      "atinytext tinytext, atext text, amediumtext mediumtext, alongtext longtext, "
      "abinary binary(10), avarbinary varbinary(1), "
      "atinyblob tinyblob, amediumblob mediumblob, ablob blob, alongblob longblob, "
      "aenum enum('a', 'b', 'c'), aset set('a', 'b', 'c'), ageometry geometry)");
    f.chain((x) {
      print("created");
      return cnx.query("show tables");
    }).chain((Results results) {
      print("tables");
      for (List<Dynamic> row in results) {
        print(row);
      }
      return cnx.query("describe test1");
    }).chain((Results results) {
      print("table test1");
      showResults(results);
      return cnx.prepare("insert into test1 (atinyint, asmallint, amediumint, abigint, aint, "
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
    }).chain((Query query) {
      query[0] = 163;
      query[1] = 164;
      query[2] = 165;
      query[3] = 166;
      query[4] = 167;
      
      query[5] = 592;
      query[6] = 123.456;
      query[7] = 123.456;
      query[8] = 123.456;
      
      query[9] = true;
      query[10] = 0xFF020235B01; //TODO this doesn't serialise correctly
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
    }).chain((Results results) {
      print("updated ${results.affectedRows} ${results.insertId}");
      return cnx.query("select * from test1");
    }).chain((Results results) {
      print("values");
      showResults(results);
      return cnx.prepare("select * from test1");
    }).chain((Query query) {
      return query.execute();
    }).then((Results results) {
      showResults(results);
      cnx.close();
      _completer.complete(true);
    });
  }
  
  void showResults(Results results) {
    List<String> fieldNames = new List<String>();
    for (Field field in results.fields) {
      fieldNames.add(field.name);
    }
    print(fieldNames);
    for (List<Dynamic> row in results) {
      print(row);
    }
  }
}
