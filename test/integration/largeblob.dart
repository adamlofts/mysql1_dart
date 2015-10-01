part of integrationtests;

/*
void runLargeBlobTests(String user, String password, String db, int port, String host) {
  ConnectionPool pool;
  var text;
  group('large blob tests:', () {
    test('setup', () {
      pool = new ConnectionPool(
          user: user, password: password, db: db, port: port, host: host, max: 1, maxPacketSize: 32 * 1024 * 1024);
      text = new String.fromCharCodes(new List.filled(16 * 1024 * 1024, 65));
      var sql = "insert into large (stuff) values ('$text')";
      return setup(pool, "large", "create table large (stuff longtext)", sql);
    });

    test('read data', () {
      var c = new Completer();
      pool.query('select * from large').then(expectAsync1((Results results) {
        results.listen((row) {
          var t = row[0].toString();
          expect(t.length, equals(text.length));
          expect(t, equals(text));
          // shouldn't get exception here
        }, onDone: () {
          c.complete();
        });
      }));
      return c.future;
    });

    test('close connection', () {
      pool.closeConnectionsWhenNotInUse();
    });
  });
}
*/
