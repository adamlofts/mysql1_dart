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
    Future f = cnx.query("create table test1 (achar char(20), "
      "aint int, adate date, adatetime datetime, avarchar varchar(20))");
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
      return cnx.prepare("insert into test1 (achar, aint, adate, adatetime, avarchar) values (?, ?, ?, ?, ?)");
    }).chain((Query query) {
      query[0] = "Hey!";
      query[1] = 163;
      query[2] = new Date.now();
      query[3] = new Date.now();
      query[4] = "Hello.";
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
