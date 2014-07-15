part of integrationtests;

void runExecuteMultiTests(String user, String password, String db, int port, String host) {
  ConnectionPool pool;
  group('executeMulti tests:', () {
    test('setup', () {
      pool = new ConnectionPool(user:user, password:password, db:db, port:port, host:host, max:1);
      return setup(pool, "stream", "create table stream (id integer, name text)",
      "insert into stream (id, name) values (1, 'A'), (2, 'B'), (3, 'C')");
    });

    test('store data', () {
      var c = new Completer();
      var theValues;
      pool.prepare('select * from stream where id = ?').then((query) {
        return query.executeMulti([[1], [2], [3]]);
      }).then((values) {
        theValues = values;
        expect(values, hasLength(3));
        return theValues[0].toList();
      }).then((resultList) {
        expect(resultList[0][0], equals(1));
        expect(resultList[0][1].toString(), equals('A'));
        return theValues[1].toList();
      }).then((resultList) {
        expect(resultList[0][0], equals(2));
        expect(resultList[0][1].toString(), equals('B'));
        return theValues[2].toList();
      }).then((resultList) {
        expect(resultList[0][0], equals(3));
        expect(resultList[0][1].toString(), equals('C'));
        c.complete(null);
      });
      return c.future;
    });

    test('close connection', () {
      pool.closeConnectionsWhenNotInUse();
    });
  });
}
