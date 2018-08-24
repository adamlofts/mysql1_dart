part of integrationtests;
/*
void runErrorTests(
    String user, String password, String db, int port, String host) {
  ConnectionPool pool;
  group('error tests:', () {
    test('setup', () async {
      pool = new ConnectionPool(
          user: user,
          password: password,
          db: db,
          port: port,
          host: host,
          max: 1,
//          useCompression: false,
          useSSL: true);
      var cnx = await pool.getConnection();
      print("Connection secure: ${cnx.usingSSL}");
      cnx.release();
      return setup(
          pool, "stream", "create table stream (id integer, name text)");
    });

    test('store data', () async {
      var query =
          await pool.prepare('insert into stream (id, name) values (?, ?)');
      await query.execute([0, 'Bob']);
    });

    test('select from stream using query and listen', () {
      var futures = [];
      for (var i = 0; i < 1; i++) {
        var c = new Completer();
        pool.query('squiggle').then((Results results) {
          results.listen((row) {}, onDone: () {
            c.complete();
          });
        }).catchError((error) {
          c.complete();
        });
        futures.add(c.future);
      }
      return Future.wait(futures);
    });
  });
}

*/
