part of integrationtests;

Future setup(ConnectionPool pool, String tableName, String createSql, [String insertSql]) async {
  await new TableDropper(pool, [tableName]).dropTables();
  var result = await pool.query(createSql);
  expect(result, isNotNull);
  if (insertSql != null) {
    return pool.query(insertSql);
  } else {
    return new Future.value(null);
  }
}

// thinking of putting other stuff in here too.
void close(ConnectionPool pool) {
  pool.closeConnectionsWhenNotInUse();
}
