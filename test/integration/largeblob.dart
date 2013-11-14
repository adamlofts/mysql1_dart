part of integrationtests;

void runLargeBlobTests(String user, String password, String db, int port, String host) {
  ConnectionPool pool;
  var text;
  group('large blob tests:', () {
    test('setup', () {
      pool = new ConnectionPool(user:user, password:password, db:db, port:port, host:host, max:1);
      text = "";
      while (text.length < 50000) {
        text += "asdfghjkqaewrpoiuwretlkjahsdflkjashguaihefalkjehfauiwhefklajshdfkj";
      }
      var sql = "insert into large (stuff) values ('$text')";
      return setup(pool, "large", "create table large (stuff text)", sql);
    });
    
    test('read data', () {
      var c = new Completer();
      pool.query('select * from large').then(expectAsync1((Results results) {
        results.listen((row) {
          expect(row[0].toString(), equals(text));
          // shouldn't get exception here
        }, onDone: () {
          c.complete();
        });
      }));
      return c.future;
    });

    test('close connection', () {
      return close(pool);
    });
  });
}
