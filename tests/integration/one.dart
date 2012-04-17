class One {
  List<String> tables;
  
  void runAll() {
    tables = ["integ", "integ2", "integ3"];
    
    AsyncConnection cnx = new AsyncMySqlConnection();
    cnx.connect(user:'test', password:'test', db:'bob').then((nothing) {
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
