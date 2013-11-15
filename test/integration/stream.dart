part of integrationtests;

void runStreamTests(String user, String password, String db, int port, String host) {
  ConnectionPool pool;
  group('stream tests:', () {
    test('setup', () {
      pool = new ConnectionPool(user:user, password:password, db:db, port:port, host:host, max:1);
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
      for (var i = 0; i < 5; i++) {
        var c = new Completer();
        pool.query('select * from stream').then((Results results) {
          results.listen((row) {
          }, onDone: () {
            c.complete();
          });
        });
        futures.add(c.future);
      }
      return Future.wait(futures);
    });

    test('select nothing from stream using query and listen', () {
      var futures = [];
      for (var i = 0; i < 5; i++) {
        var c = new Completer();
        pool.query('select * from stream where id=5').then((Results results) {
          results.listen((row) {
          }, onDone: () {
            c.complete();
          });
        });
        futures.add(c.future);
      }
      return Future.wait(futures);
    });

    test('select from stream using query and first', () {
      var futures = [];
      for (var i = 0; i < 5; i++) {
        var c = new Completer();
        pool.query('select * from stream').then((Results results) {
          results.first.then((row) {
            c.complete();
          });
        });
        futures.add(c.future);
      }
      return Future.wait(futures);
    });

    test('select from stream using query and drain', () {
      var futures = [];
      for (var i = 0; i < 5; i++) {
        var c = new Completer();
        pool.query('select * from stream').then((Results results) {
          results.drain().then((row) {
            c.complete();
          });
        });
        futures.add(c.future);
      }
      return Future.wait(futures);
    });

    test('select from stream using prepare and listen', () {
      var futures = [];
      for (var i = 0; i < 5; i++) {
        var c = new Completer();
        pool.prepare('select * from stream').then((Query query) {
          return query.execute();
        }).then((Results results) {
          results.listen((row) {
          }, onDone: () {
            c.complete();
          });
        });
        futures.add(c.future);
      }
      return Future.wait(futures);
    });

    test('select nothing from stream using prepare and listen', () {
      var futures = [];
      for (var i = 0; i < 5; i++) {
        var c = new Completer();
        pool.prepare('select * from stream where id=5').then((Query query) {
          return query.execute();
        }).then((Results results) {
          results.listen((row) {
          }, onDone: () {
            c.complete();
          });
        });
        futures.add(c.future);
      }
      return Future.wait(futures);
    });

    test('select from stream using prepare and first', () {
      var futures = [];
      for (var i = 0; i < 5; i++) {
        var c = new Completer();
        pool.prepare('select * from stream').then((Query query) {
          return query.execute();
        }).then((Results results) {
          results.first.then((row) {
            c.complete();
          });
        });
        futures.add(c.future);
      }
      return Future.wait(futures);
    });

    test('select from stream using prepare and drain', () {
      var futures = [];
      for (var i = 0; i < 5; i++) {
        var c = new Completer();
        pool.prepare('select * from stream').then((Query query) {
          return query.execute();
        }).then((Results results) {
          results.drain().then((row) {
            c.complete();
          });
        });
        futures.add(c.future);
      }
      return Future.wait(futures);
    });

    test('close connection', () {
      pool.close();
    });
  });
}
