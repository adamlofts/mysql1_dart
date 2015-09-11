part of integrationtests;

void runExecuteMultiTests(String user, String password, String db, int port, String host) {
  ConnectionPool pool;
  group('executeMulti tests:', () {
    test('setup', () {
      pool = new ConnectionPool(user: user, password: password, db: db, port: port, host: host, max: 2);
      return setup(pool, "stream", "create table stream (id integer, name text)",
          "insert into stream (id, name) values (1, 'A'), (2, 'B'), (3, 'C')");
    });

    test('store data', () async {
      var query = await pool.prepare('select * from stream where id = ?');
      var values = await query.executeMulti([
        [1],
        [2],
        [3]
      ]);
      expect(values, hasLength(3));

      var resultList = await values[0].toList();
      expect(resultList[0][0], equals(1));
      expect(resultList[0][1].toString(), equals('A'));

      resultList = await values[1].toList();
      expect(resultList[0][0], equals(2));
      expect(resultList[0][1].toString(), equals('B'));

      resultList = await values[2].toList();
      expect(resultList[0][0], equals(3));
      expect(resultList[0][1].toString(), equals('C'));
    });

    test('issue 43', () async {
      var tran = await pool.startTransaction();
      var query = await tran.prepare("SELECT * FROM stream");
      var result = await query.execute();

      await result.first;

      await query.close();
      await tran.rollback();
    });

    test('close connection', () {
      pool.closeConnectionsWhenNotInUse();
    });
  });
}
