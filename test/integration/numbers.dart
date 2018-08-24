part of integrationtests;

/*
Future deleteInsertSelect(ConnectionPool pool, table, insert, select) async {
  await pool.query('delete from $table');
  await pool.query(insert);
  return pool.query(select);
}

void runNumberTests(
    String user, String password, String db, int port, String host) {
  ConnectionPool pool;
  group('number tests:', () {
    test('setup', () {
      pool = new ConnectionPool(
          user: user,
          password: password,
          db: db,
          port: port,
          host: host,
          max: 1);
      return setup(
          pool,
          "nums",
          "create table nums ("
          "atinyint tinyint, asmallint smallint, amediumint mediumint, aint int, abigint bigint, "
          "utinyint tinyint unsigned, usmallint smallint unsigned, umediumint mediumint unsigned, uint int unsigned, ubigint bigint unsigned, "
          "adecimal decimal(20,10), afloat float, adouble double, areal real)",
          "insert into nums (atinyint, asmallint, amediumint, aint, abigint) values ("
          "-128, -32768, -8388608, -2147483648, -9223372036854775808)");
    });

    test('minimum values', () async {
      var results = await pool.query(
          'select atinyint, asmallint, amediumint, aint, abigint from nums');

      var row = await results.single;

      expect(row[0], equals(-128));
      expect(row[1], equals(-32768));
      expect(row[2], equals(-8388608));
      expect(row[3], equals(-2147483648));
      expect(row[4], equals(-9223372036854775808));
    });

    test('maximum values', () async {
      var results = await deleteInsertSelect(
          pool,
          'nums',
          "insert into nums (atinyint, asmallint, amediumint, aint, abigint, "
          "adecimal, afloat, adouble, areal) values ("
          "127, 32767, 8388607, 2147483647, 9223372036854775807, "
          "0, 0, 0, 0)",
          'select atinyint, asmallint, amediumint, aint, abigint from nums');

      var row = await results.single;
      expect(row[0], equals(127));
      expect(row[1], equals(32767));
      expect(row[2], equals(8388607));
      expect(row[3], equals(2147483647));
      expect(row[4], equals(9223372036854775807));
    });

    test('maximum unsigned values', () async {
      var results = await deleteInsertSelect(
          pool,
          'nums',
          "insert into nums (utinyint, usmallint, umediumint, uint, ubigint) values ("
          "255, 65535, 12777215, 4294967295, 18446744073709551615)",
          'select utinyint, usmallint, umediumint, uint, ubigint from nums');

      var row = await results.single;

      expect(row[0], equals(255));
      expect(row[1], equals(65535));
      expect(row[2], equals(12777215));
      expect(row[3], equals(4294967295));
      expect(row[4], equals(18446744073709551615));
    });

    test('max decimal', () async {
      var results = await deleteInsertSelect(
          pool,
          'nums',
          "insert into nums (adecimal) values ("
          "1234512345.1234512345)",
          'select adecimal from nums');

      var row = await results.single;

      expect(row[0], equals(1234512345.1234512345));
    });

    test('min decimal', () async {
      var results = await deleteInsertSelect(
          pool,
          'nums',
          "insert into nums (adecimal) values ("
          "-1234512345.1234512345)",
          'select adecimal from nums');

      var row = await results.single;

      expect(row[0], equals(-1234512345.1234512345));
    });

    test('close connection', () {
      pool.closeConnectionsWhenNotInUse();
    });
  });
}

*/
