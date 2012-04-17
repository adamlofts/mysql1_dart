class One {
  void runAll() {
    AsyncConnection cnx = new AsyncMySqlConnection();
    cnx.connect(user:'test', password:'test', db:'bob').then((nothing) {
      cnx.useDatabase('bob').then((dummy) {
        dropTables(cnx);
      });
    });
  }
  
  void dropTables(AsyncConnection cnx) {
    print("drop tables");
    Future future = cnx.query("drop table integ");
    future.handleException((exception) {
      if (exception is MySqlError && exception.errorNumber == 1051) {
        print("no table to delete");
        createTables(cnx);
      }
      return true;
    });
    future.then((x) {
      print("deleted");
      createTables(cnx);
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
