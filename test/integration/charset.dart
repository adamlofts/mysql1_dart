part of integrationtests;

void runCharsetTests(String user, String password, String db, int port, String host) {
  ConnectionPool pool;
  group('some tests:', () {
    test('create pool', () {
      pool = new ConnectionPool(user:user, password:password, db:db, port:port, host:host, max:1);
      expect(pool, isNotNull);
    });
    
    test('dropTables', () {
      new TableDropper(pool, ["cset"]).dropTables().then(expectAsync1((_) {
        expect(1, equals(1)); // not quite sure of the async testing stuff yet
      }));
    });
    
    test('create tables', () {
      pool.query("create table cset ("
        "stuff text character set utf8)").then(expectAsync1((Results results) {
          expect(results.stream, equals(null));
        }));
    });
    
    test('store data', () {
      pool.query('insert into cset (stuff) values ("здрасти")').then(expectAsync1((Results results) {
        expect(1, equals(1));
      }));
    });

    test('read data', () {
      var c = new Completer();
      pool.query('select * from cset').then(expectAsync1((Results results) {
        results.stream.listen((row) {
          expect(row[0].toString(), equals("здрасти"));
        }, onDone: () {
          c.complete();
        });
      }));
      return c.future;
    });

    test('close connection', () {
      pool.close();
      expect(1, equals(1));
    });
  });
}
