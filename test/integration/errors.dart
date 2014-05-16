part of integrationtests;

void runErrorTests(String user, String password, String db, int port, String host) {
  ConnectionPool pool;
  group('error tests:', () {
    test('setup', () {
      pool = new ConnectionPool(user:user, password:password, db:db, port:port, host:host, max:1,
//          useCompression: false, 
          useSSL: true);
      pool.getConnection().then((cnx) {
        print("Connection secure: ${cnx.usingSSL}");
        cnx.release();
      });
      return setup(pool, "stream", "create table stream (id integer, name text)");
    });
    
    test('store data', () {
      var c = new Completer();
      pool.prepare('insert into stream (id, name) values (?, ?)').then((query) {
        query.execute([0, 'Bob']).then((Results results) {
          c.complete();
        });
      });
      return c.future;
    });

    test('select from stream using query and listen', () {
      var futures = [];
      for (var i = 0; i < 1; i++) {
        var c = new Completer();
        pool.query('squiggle').then((Results results) {
          results.listen((row) {
          }, onDone: () {
            c.complete();
          });
        })
        .catchError((error) {
          c.complete();
        });
        futures.add(c.future);
      }
      return Future.wait(futures);
    });
    test('close connection', () {
      pool.closeConnectionsWhenNotInUse();
    });
  });
}
