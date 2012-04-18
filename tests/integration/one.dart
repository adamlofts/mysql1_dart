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
  
  void runAll() {
    tables = ["integ", "integ2", "integ3"];
    
    AsyncConnection cnx = new AsyncMySqlConnection();
    cnx.connect(user:_user, password:_password, db:_db, port:_port, host:_host).then((nothing) {
      cnx.useDatabase('bob').then((dummy) {
        dropTables(cnx);
      });
    });
  }
  
  void dropTables(AsyncConnection cnx) {
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
  
  void createTables(AsyncConnection cnx) {
    print("creating tables");
    Future future = cnx.query("create table integ (name text)");
    future.then((x) {
      print("created");
      cnx.close();
    });
  }
}
