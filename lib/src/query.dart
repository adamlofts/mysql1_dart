part of sqljocky;

/**
 * Query is created by `ConnectionPool.prepare(sql)` and `Transaction.prepare(sql)`. It holds
 * a prepared query.
 * 
 * In MySQL, a query must be prepared on a specific connection. If you execute this
 * query and a connection is used from the pool which doesn't yet have the prepared query
 * in its cache, it will first prepare the query on that connection before executing it.
 */
class Query extends Object with _ConnectionHelpers {
  final ConnectionPool _pool;
  final _Connection _cnx;
  final String sql;
  final Logger _log;
  final _inTransaction;
  bool _executed = false;
  
  Query._internal(this._pool, this.sql) :
      _cnx = null,
      _inTransaction = false,
      _log = new Logger("Query");

  Query._forTransaction(this._pool, _Connection cnx, this.sql) :
      _cnx = cnx,
      _inTransaction = true,
      _log = new Logger("Query");
  
  Future<_Connection> _getConnection() {
    if (_cnx != null) {
      var c = new Completer<_Connection>();
      c.complete(_cnx);
      return c.future;
    }
    return _pool._getConnection();
  }

  Future<_PreparedQuery> _prepare(bool retainConnection) async {
    _log.fine("Getting prepared query for: $sql");
    
    var cnx = await _getConnection();
    cnx.autoRelease = !retainConnection;
    var c = new Completer<_PreparedQuery>();
    _log.fine("Got cnx#${cnx.number}");
    if (_useCachedQuery(cnx, c)) {
      if (!retainConnection) {
        // didn't actually use the connection, so the auto-release
        // mechanism will never get fired, so we'd better give up
        // on the connection now
        cnx.release();
      }
    } else {
      _prepareAndCacheQuery(cnx, c, retainConnection);
    }
    return c.future;
  }
  
  /**
   * Returns true if there was already a cached query which has been used.
   */
  bool _useCachedQuery(_Connection cnx, Completer c) {
    var preparedQuery = cnx.getPreparedQueryFromCache(sql);
    if (preparedQuery == null) {
      return false;
    }

    _log.fine("Got prepared query from cache in cnx#${cnx.number} for: $sql");
    c.complete(preparedQuery);
    return true;
  }
  
  _prepareAndCacheQuery(_Connection cnx, Completer c, retainConnection) async {
    _log.fine("Preparing new query in cnx#${cnx.number} for: $sql");
    var handler = new _PrepareHandler(sql);
    cnx.use();
    cnx.autoRelease = !retainConnection;
    var preparedQuery = await cnx.processHandler(handler);
    try {
      _log.fine("Prepared new query in cnx#${cnx.number} for: $sql");
      preparedQuery.cnx = cnx;
      cnx.putPreparedQueryInCache(sql, preparedQuery);
      c.complete(preparedQuery);
    } catch (e) {
      _releaseReuseCompleteError(cnx, c, e);
    }
  }

  /// Closes this query and removes it from all connections in the pool.
  void close() {
    _pool._closeQuery(this, _inTransaction);
  }
  
  /**
   * Executes the query, returning a future [Results] object.
   */
  Future<Results> execute([List values]) async {
    _log.fine("Prepare...");
    var preparedQuery = await _prepare(true);
    _log.fine("Prepared, now to execute");
    Results results = await _execute(preparedQuery, values == null ? [] : values);
    _log.fine("Got prepared query results on #${preparedQuery.cnx.number} for: ${sql}");
    return results;
  }
  
  Future<Results> _execute(_PreparedQuery preparedQuery, List values,
      {bool retainConnection: false}) async {
    _log.finest("About to execute");
    var c = new Completer<Results>();
    var handler = new _ExecuteQueryHandler(preparedQuery, _executed, values);
    preparedQuery.cnx.autoRelease = !retainConnection;
    Results results = await preparedQuery.cnx.processHandler(handler);
    try {
      _log.finest("Prepared query got results");
      c.complete(results);
    } catch (e) {
      _releaseReuseCompleteError(preparedQuery.cnx, c, e);
    }
    return c.future;
  }

  /**
   * Executes the query once for each set of [parameters], and returns a future list
   * of results, one for each set of parameters, that completes when the query has been executed.
   *
   * Because this method has to wait for all the results to return from the server before it
   * can move onto the next query, it ends up keeping all the results in memory, rather than
   * streaming them, which can be less efficient.
   */
  Future<List<Results>> executeMulti(List<List> parameters) async {
    var preparedQuery = await _prepare(true);
    var c = new Completer<List<Results>>();
    _log.fine("Prepared query for multi execution. Number of values: ${parameters.length}");
    var resultList = new List<Results>();

    executeQuery(int i) async {
      try {
        _log.fine("Executing query, loop $i");
        Results results = await _execute(preparedQuery, parameters[i], retainConnection: true);
        _log.fine("Got results, loop $i");
        Results deStreamedResults = await _ResultsImpl.destream(results);
        resultList.add(deStreamedResults);
        if (i < parameters.length - 1) {
          await executeQuery(i + 1);
        } else {
          preparedQuery.cnx.release();
        }
      } catch (e) {
        _releaseReuseCompleteError(preparedQuery.cnx, c, e);
      }
    }

    await executeQuery(0);
    return resultList;
  }
  
  _removeConnection(_Connection cnx) {
    if (!_inTransaction) {
      _pool._removeConnection(cnx);
    }
  }
//  dynamic longData(int index, data);
//  dynamic reset();
//  dynamic fetch(int rows);
}
