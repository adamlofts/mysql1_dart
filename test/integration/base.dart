part of integrationtests;

Future setup(ConnectionPool pool, String tableName, String createSql, [String insertSql]) {
  return new TableDropper(pool, [tableName]).dropTables().then((_) {
    return pool.query(createSql);
  }).then((result) {
    expect(result, isNotNull);
    if (insertSql != null) {
      return pool.query(insertSql);
    } else {
      return new Future.value(null);
    }
  });
}

// thinking of putting other stuff in here too.
void close(ConnectionPool pool) {
  return pool.close();
}
