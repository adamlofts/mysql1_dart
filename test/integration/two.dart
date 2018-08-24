part of integrationtests;

/*
void runIntTests2(
    String user, String password, String db, int port, String host) {
  ConnectionPool pool;
  group('some tests:', () {
    test('create pool', () {
      pool = new ConnectionPool(
          user: user,
          password: password,
          db: db,
          port: port,
          host: host,
          max: 1);
      expect(pool, isNotNull);
    });

    test('four pings', () {
      var c1 = new Completer();
      var c2 = new Completer();
      var c3 = new Completer();
      var c4 = new Completer();
      var futures = [c1.future, c2.future, c3.future, c4.future];
      var finished = [];
      pool.ping().then((_) {
        finished.add(1);
        print("ping 1 received");
        c1.complete();

        pool.ping().then((_) {
          finished.add(4);
          print("ping 4 received");
          c4.complete();
        });
        print("ping 4 sent");
      });
      print("ping 1 sent");

      pool.ping().then((_) {
        finished.add(2);
        print("ping 2 received");
        c2.complete();
      });
      print("ping 2 sent");

      pool.ping().then((_) {
        finished.add(3);
        print("ping 3 received");
        c3.complete();
      });
      print("ping 3 sent");

      expect(finished, equals([]));

      return Future.wait(futures).then((_) {
        expect(finished, contains(1));
        expect(finished, contains(2));
        expect(finished, contains(3));
        expect(finished, contains(4));
        expect(finished, hasLength(4));
      });
    });

    test('close connection', () {
      pool.closeConnectionsWhenNotInUse();
      expect(1, equals(1));
    });
  });
}

*/
