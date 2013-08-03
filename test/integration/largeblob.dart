part of integrationtests;

void runLargeBlobTests(String user, String password, String db, int port, String host) {
  ConnectionPool pool;
  group('some tests:', () {
    test('create pool', () {
      pool = new ConnectionPool(user:user, password:password, db:db, port:port, host:host, max:1);
      expect(pool, isNotNull);
    });
    
    test('dropTables', () {
      new TableDropper(pool, ["large"]).dropTables().then(expectAsync1((_) {
        expect(1, equals(1)); // not quite sure of the async testing stuff yet
      }));
    });
    
    test('create tables', () {
      pool.query("create table large ("
        "stuff text)").then(expectAsync1((Results results) {
          expect(results.stream, equals(null));
        }));
    });
    
    test('store data', () {
      var x = "insert into large (stuff) values ('";
      while (x.length < 50000) {
        x += "asdfghjkqaewrpoiuwretlkjahsdflkjashguaihefalkjehfauiwhefklajshdfkj";
      }
      x += "')";
      pool.query(x).then(expectAsync1((Results results) {
        expect(1, equals(1));
      }));
    });

    test('read data', () {
      var c = new Completer();
      pool.query('select * from large').then(expectAsync1((Results results) {
        results.stream.listen((row) {
          // shouldn't get exception here
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
