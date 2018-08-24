part of integrationtests;
/*
void runNullMapTests(
    String user, String password, String db, int port, String host) {
  ConnectionPool pool;
  group('nullmap tests:', () {
    test('setup', () {
      pool = new ConnectionPool(
          user: user,
          password: password,
          db: db,
          port: port,
          host: host,
          max: 1);
      return setup(pool, "nullmap",
          "create table nullmap (a text, b text, c text, d text)");
    });

    test('store data', () async {
      var query = await pool
          .prepare('insert into nullmap (a, b, c, d) values (?, ?, ?, ?)');
      await query.execute([null, 'b', 'c', 'd']);
    });

    test('read data', () {
      var c = new Completer();
      pool.query('select * from nullmap').then((Results results) {
        results.listen((row) {
          expect(row[0], equals(null));
          expect(row[1].toString(), equals('b'));
          expect(row[2].toString(), equals('c'));
          expect(row[3].toString(), equals('d'));
        }, onDone: () {
          c.complete();
        });
      });
      return c.future;
    });

    test('close connection', () {
      pool.closeConnectionsWhenNotInUse();
    });
  });
}

*/
