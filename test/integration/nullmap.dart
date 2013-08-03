part of integrationtests;

void runNullMapTests(String user, String password, String db, int port, String host) {
  ConnectionPool pool;
  group('some tests:', () {
    test('create pool', () {
      pool = new ConnectionPool(user:user, password:password, db:db, port:port, host:host, max:1);
      expect(pool, isNotNull);
    });
    
    test('dropTables', () {
      new TableDropper(pool, ["nullmap"]).dropTables().then(expectAsync1((_) {
        expect(1, equals(1)); // not quite sure of the async testing stuff yet
      }));
    });
    
    test('create tables', () {
      pool.query("create table nullmap ("
        "a text, b text, c text, d text)").then(expectAsync1((Results results) {
          expect(results.stream, equals(null));
        }));
    });
    
    test('store data', () {
      var c = new Completer();
      pool.prepare('insert into nullmap (a, b, c, d) values (?, ?, ?, ?)').then((query) {
        query[0] = null;
        query[1] = 'b';
        query[2] = 'c';
        query[3] = 'd';
        query.execute().then((Results results) {
          c.complete();
        });
      });
      return c.future;
    });

    test('read data', () {
      var c = new Completer();
      pool.query('select * from nullmap').then((Results results) {
        results.stream.listen((row) {
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
      pool.close();
      expect(1, equals(1));
    });
  });
}
