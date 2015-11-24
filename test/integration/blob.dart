part of integrationtests;

void runBlobTests(
    String user, String password, String db, int port, String host) {
  ConnectionPool pool;
  group('charset tests:', () {
    test('setup', () {
      pool = new ConnectionPool(
          user: user,
          password: password,
          db: db,
          port: port,
          host: host,
          max: 1);
      return setup(pool, "blobtest", "create table blobtest (stuff blob)");
    });

    test('write blob', () async {
      var query = await pool.prepare("insert into blobtest (stuff) values (?)");
      await query.execute([
        [0xc3, 0x28]
      ]); // this is an invalid UTF8 string
    });

    test('read data', () async {
      var c = new Completer();
      var results = await pool.query('select * from blobtest');
      results.listen((row) {
        expect((row[0] as Blob).toBytes(), equals([0xc3, 0x28]));
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
