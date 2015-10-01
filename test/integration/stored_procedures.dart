part of integrationtests;
/*

void runStoredProcedureTests(String user, String password, String db, int port, String host) {
  ConnectionPool pool;
  group('error tests:', () {
    test('setup', () {
      pool = new ConnectionPool(user: user, password: password, db: db, port: port, host: host, max: 1);
//      return setup(pool, "stream", "create table stream (id integer, name text)");
    });

    test('store data', () async {
//      pool.query('''
//CREATE PROCEDURE getall ()
//BEGIN
//select * from stream;
//END
//''').then((results) {
//        return query.query('call getall()');
      var results = await pool.query('call getall()');
      results.listen((row) {}, onDone: () {
        c.complete();
      });
      return c.future;
    });

    test('close connection', () {
      pool.closeConnectionsWhenNotInUse();
    });
  });
}
*/
