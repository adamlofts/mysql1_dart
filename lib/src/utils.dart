part of utils;

/**
 * Drops a set of tables.
 */
class TableDropper {
  ConnectionPool pool;
  List<String> tables;
  List<String> _tables = [];
  
  /**
   * Create a [TableDropper]. Needs a [pool] and
   * a list of [tables].
   */
  TableDropper(this.pool, this.tables);
  
  void _dropTables(Completer c) {
    var table = _tables[0];
    _tables.removeRange(0, 1);
    var future = pool.query('drop table $table');
    future.handleException((exception) {
      if (exception is MySqlError && (exception as MySqlError).errorNumber == ERROR_UNKNOWN_TABLE) {
        if (_tables.length == 0) {
          c.complete(null);
        } else {
          _dropTables(c);
        }
        return true;
      }
      c.completeException(exception);
      return true;
    });
    future.then((x) {
      if (_tables.length == 0) {
        c.complete(null);
      } else {
        _dropTables(c);
      }
    });
  }

  /**
   * Drops the tables this [TableDropper] was created with. The 
   * returned [Future] completes when all the tables have been dropped.
   * If a table doesn't exist, it is ignored.
   */
  Future dropTables() {
    var dropCompleter = new Completer();
    _tables.clear();
    _tables.addAll(tables);
    _dropTables(dropCompleter);
    return dropCompleter.future;
  }
}

/**
 * Runs a list of arbitrary queries. Currently only handles update
 * queries as the results are ignored.
 */
class QueryRunner {
  final ConnectionPool pool;
  final List<String> queries;
  final List<String> _queries = [];
  
  /**
   * Create a [QueryRunner]. Needs a [pool] and
   * a list of [queries]. 
   */
  QueryRunner(this.pool, this.queries);
  
  Future _executeQueries(Completer c) {
    var query = _queries[0];
    _queries.removeRange(0, 1);
    pool.query(query).then((result) {
      if (_queries.length == 0) {
        c.complete(null);
      } else {
        _executeQueries(c);
      }
    });
  }

  /**
   * Executes the queries this [QueryRunner] was created with. The
   * returned [Future] completes when all the queries have been executed.
   * Results are ignored.
   */
  Future executeQueries() {
    var completer = new Completer();
    _queries.clear();
    _queries.addAll(queries);
    _executeQueries(completer);
    return completer.future;
  }
}
