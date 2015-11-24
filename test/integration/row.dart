part of integrationtests;

void runRowTests(
    String user, String password, String db, int port, String host) {
  group('row tests:', () {
    ConnectionPool pool;

    setUp(() {
      pool = new ConnectionPool(
          user: user,
          password: password,
          db: db,
          port: port,
          host: host,
          max: 1);
      return setup(pool, "row",
          "create table row (id integer, name text, `the field` text, length integer)");
    });

    tearDown(() {
      pool.closeConnectionsNow();
    });

    test('store data', () async {
      var query = await pool.prepare(
          'insert into row (id, name, `the field`, length) values (?, ?, ?, ?)');
      await query.execute([0, 'Bob', 'Thing', 5000]);
    });

    test('first field is empty', () async {
      final query = await pool.prepare(
          'insert into row (id, name, `the field`, length) values (?, ?, ?, ?)');
      await (await query.execute([1, '', 'Thing', 5000])).toList();
      Iterable<Row> results =
          await (await pool.query("select name, length from row")).toList();
      expect(results.map((r) => [r[0].toString(), r[1]]).toList().first,
          equals(['', 5000]));
    });

    test('select from stream using query and listen', () async {
      var futures = [];
      for (var i = 0; i < 5; i++) {
        var c = new Completer();
        var results = await pool.query('select * from row');
        results.listen((row) {
          expect(row.id, equals(0));
          expect(row.name.toString(), equals("Bob"));
          // length is a getter on List, so it isn't mapped to the result field
          expect(row.length, equals(4));
        }, onDone: () {
          c.complete();
        });
        futures.add(c.future);
      }
      return Future.wait(futures);
    });

    test('select from stream using prepareExecute and listen', () async {
      var futures = [];
      for (var i = 0; i < 5; i++) {
        var c = new Completer();
        var results =
            await pool.prepareExecute('select * from row where id = ?', [0]);
        results.listen((row) {
          expect(row.id, equals(0));
          expect(row.name.toString(), equals("Bob"));
          // length is a getter on List, so it isn't mapped to the result field
          expect(row.length, equals(4));
        }, onDone: () {
          c.complete();
        });
        futures.add(c.future);
      }
      return Future.wait(futures);
    });
  });
}
