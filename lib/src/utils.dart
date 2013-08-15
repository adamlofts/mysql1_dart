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
    afterDrop() {
      if (_tables.length == 0) {
        c.complete(null);
      } else {
        _dropTables(c);
      }
    }
    
    var table = _tables.removeAt(0);
    pool.query('drop table $table')
      // if it's an unknown table, ignore the error and continue
      .then((_) {
        afterDrop();
      })
      .catchError((e) {
        afterDrop();
      }, test: (e) => e is MySqlException && (e as MySqlException).errorNumber == ERROR_UNKNOWN_TABLE)
      .catchError((e) {
        c.completeError(e);
      });
  }

  /**
   * Drops the tables this [TableDropper] was created with. The 
   * returned [Future] completes when all the tables have been dropped.
   * If a table doesn't exist, it is ignored.
   * 
   * Do not run this a second time until the future has completed.
   */
  Future dropTables() {
    var c = new Completer();
    _tables.clear();
    _tables.addAll(tables);
    _dropTables(c);
    return c.future;
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
    var query = _queries.removeAt(0);
    pool.query(query).then((result) {
      if (_queries.length == 0) {
        c.complete(null);
      } else {
        _executeQueries(c);
      }
    })
    .catchError((e) {
      c.completeError(e);
    });
  }

  /**
   * Executes the queries this [QueryRunner] was created with. The
   * returned [Future] completes when all the queries have been executed.
   * Results are ignored.
   * 
   * Do not run this a second time until the future has completed.
   */
  Future executeQueries() {
    var c = new Completer();
    _queries.clear();
    _queries.addAll(queries);
    _executeQueries(c);
    return c.future;
  }
}
