part of integrationtests;

void runCharsetTests(String user, String password, String db, int port, String host) {
  ConnectionPool pool;
  group('charset tests:', () {
    test('setup', () {
      pool = new ConnectionPool(user: user, password: password, db: db, port: port, host: host, max: 1);
      return setup(pool, "cset", "create table cset (stuff text character set utf8)",
          "insert into cset (stuff) values ('здрасти')");
    });

    test('read data', () async {
      var c = new Completer();
      var results = await pool.query('select * from cset');
      results.listen((row) {
        expect(row[0].toString(), equals("здрасти"));
      }, onDone: () {
        c.complete();
      });
      return c.future;
    });

    test('close connection', () {
      pool.closeConnectionsWhenNotInUse();
    });
  });
}
