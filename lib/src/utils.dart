part of utils;

/**
 * Drops a set of tables.
 */
class TableDropper {
  ConnectionPool pool;
  List<String> tables;

  /**
   * Create a [TableDropper]. Needs a [pool] and
   * a list of [tables].
   */
  TableDropper(this.pool, this.tables);

  /**
   * Drops the tables this [TableDropper] was created with. The 
   * returned [Future] completes when all the tables have been dropped.
   * If a table doesn't exist, it is ignored.
   */
  Future dropTables() async {
    await Future.forEach(tables, (table) async {
      try {
        await pool.query('drop table $table');
      } catch (e) {
        if (e is MySqlException && (e as MySqlException).errorNumber == ERROR_UNKNOWN_TABLE) {
          // if it's an unknown table, ignore the error and continue
        } else {
          throw e;
        }
      }
    });
  }
}

/**
 * Runs a list of arbitrary queries. Currently only handles update
 * queries as the results are ignored.
 */
class QueryRunner {
  final ConnectionPool pool;
  final List<String> queries;

  /**
   * Create a [QueryRunner]. Needs a [pool] and
   * a list of [queries]. 
   */
  QueryRunner(this.pool, this.queries);

  /**
   * Executes the queries this [QueryRunner] was created with. The
   * returned [Future] completes when all the queries have been executed.
   * Results are ignored.
   */
  Future executeQueries() async {
    await Future.forEach(queries, (query) async {
      await pool.query(query);
    });
  }
}
