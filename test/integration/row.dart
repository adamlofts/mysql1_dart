part of integrationtests;

void runRowTests(String user, String password, String db, int port, String host) {
  ConnectionPool pool;
  group('row tests:', () {
    test('setup', () {
      pool = new ConnectionPool(user:user, password:password, db:db, port:port, host:host, max:1);
      return setup(pool, "row", "create table row (id integer, name text, " 
        "`the field` text, length integer)");
    });
    
    test('store data', () {
      var c = new Completer();
      pool.prepare('insert into row (id, name, `the field`, length) values (?, ?, ?, ?)').then((query) {
        query.execute([0, 'Bob', 'Thing', 5000]).then((Results results) {
          c.complete();
        });
      });
      return c.future;
    });

    test('select from stream using query and listen', () {
      var futures = [];
      for (var i = 0; i < 5; i++) {
        var c = new Completer();
        pool.query('select * from row').then((Results results) {
          results.listen((row) {
            expect(row.id, equals(0));
            expect(row.name.toString(), equals("Bob"));
            // length is a getter on List, so it isn't mapped to the result field
            expect(row.length, equals(4));
          }, onDone: () {
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
