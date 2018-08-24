part of integrationtests;
/*
void runPreparedQueryTests(
    String user, String password, String db, int port, String host) {
  group('prepared query', () {
    ConnectionPool pool;

    setUp(() {
      pool = new ConnectionPool(
          user: user,
          password: password,
          db: db,
          port: port,
          host: host,
          max: 2);
      return setup(pool, "row", "create table row (id integer, name text)",
          "insert into row values (0, 'One'), (1, 'One')");
    });

    tearDown(() {
      pool.closeConnectionsNow();
    });

    test('can close prepared query on in-use connections', () async {
      var cnx = await pool.getConnection();
      var query = await pool.prepare("select * from row");
      await query.close();
      cnx.release();
    });
  });
}
*/
