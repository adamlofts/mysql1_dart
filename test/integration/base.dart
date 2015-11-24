part of integrationtests;

Future setup(ConnectionPool pool, String tableName, String createSql,
    [String insertSql]) async {
  await new TableDropper(pool, [tableName]).dropTables();
  var result = await pool.query(createSql);
  expect(result, isNotNull);
  if (insertSql != null) {
    await pool.query(insertSql);
  }
}
