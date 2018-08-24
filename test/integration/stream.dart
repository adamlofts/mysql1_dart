part of integrationtests;

/*
void runStreamTests(
    String user, String password, String db, int port, String host) {
  ConnectionPool pool;
  group('stream tests:', () {
    test('setup', () {
      pool = new ConnectionPool(
          user: user,
          password: password,
          db: db,
          port: port,
          host: host,
          max: 1);
      return setup(
          pool, "stream", "create table stream (id integer, name text)");
    });

    test('store data', () async {
      var query =
          await pool.prepare('insert into stream (id, name) values (?, ?)');
      await query.execute([0, 'Bob']);
    });

    test('select from stream using query and listen', () async {
      var futures = [];
      for (var i = 0; i < 5; i++) {
        var c = new Completer();
        var results = await pool.query('select * from stream');
        results.listen((row) {}, onDone: () {
          c.complete();
        });
        futures.add(c.future);
      }
      return Future.wait(futures);
    });

    test('select nothing from stream using query and listen', () async {
      var futures = [];
      for (var i = 0; i < 5; i++) {
        var c = new Completer();
        var results = await pool.query('select * from stream where id=5');
        results.listen((row) {}, onDone: () {
          c.complete();
        });
        futures.add(c.future);
      }
      return Future.wait(futures);
    });

    test('select from stream using query and first', () async {
      for (var i = 0; i < 5; i++) {
        var results = await pool.query('select * from stream');
        await results.first;
      }
    });

    test('select from stream using query and drain', () async {
      for (var i = 0; i < 5; i++) {
        var results = await pool.query('select * from stream');
        await results.drain();
      }
    });

    test('select from stream using prepare and listen', () async {
      var futures = [];
      for (var i = 0; i < 5; i++) {
        var c = new Completer();
        var query = await pool.prepare('select * from stream');
        var results = await query.execute();
        results.listen((row) {}, onDone: () {
          c.complete();
        });
        futures.add(c.future);
      }
      return Future.wait(futures);
    });

    test('select nothing from stream using prepare and listen', () async {
      var futures = [];
      for (var i = 0; i < 5; i++) {
        var c = new Completer();
        var query = await pool.prepare('select * from stream where id=5');
        var results = await query.execute();
        results.listen((row) {}, onDone: () {
          c.complete();
        });
        futures.add(c.future);
      }
      return Future.wait(futures);
    });

    test('select from stream using prepare and first', () async {
      for (var i = 0; i < 5; i++) {
        var query = await pool.prepare('select * from stream');
        var results = await query.execute();
        await results.first;
      }
    });

    test('select from stream using prepare and drain', () async {
      for (var i = 0; i < 5; i++) {
        var query = await pool.prepare('select * from stream');
        var results = await query.execute();
        await results.drain();
      }
    });

    test('close connection', () {
      pool.closeConnectionsWhenNotInUse();
    });
  });
}


*/
