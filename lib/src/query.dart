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

  Future<_PreparedQuery> _prepare(bool retainConnection) {
    _log.fine("Getting prepared query for: $sql");
    
    return _getConnection()
      .then((cnx) {
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
      });
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
  
  void _prepareAndCacheQuery(_Connection cnx, Completer c, retainConnection) {
    _log.fine("Preparing new query in cnx#${cnx.number} for: $sql");
    var handler = new _PrepareHandler(sql);
    cnx.use();
    cnx.autoRelease = !retainConnection;
    cnx.processHandler(handler)
      .then((preparedQuery) {
        _log.fine("Prepared new query in cnx#${cnx.number} for: $sql");
        preparedQuery.cnx = cnx;
        cnx.putPreparedQueryInCache(sql, preparedQuery);
        c.complete(preparedQuery);
      })
      .catchError((e) {
        _releaseReuseCompleteError(cnx, c, e);
      });
  }

  /// Closes this query and removes it from all connections in the pool.
  void close() {
    _pool._closeQuery(this, _inTransaction);
  }
  
  /**
   * Executes the query, returning a future [Results] object.
   */
  Future<Results> execute([List values]) {
    _log.fine("Prepare...");
    return _prepare(true)
      .then((preparedQuery) {
        _log.fine("Prepared, now to execute");
        return _execute(preparedQuery, values == null ? [] : values)
          .then((Results results) {
            _log.fine("Got prepared query results on #${preparedQuery.cnx.number} for: ${sql}");
            return results;
          });
      });
  }
  
  Future<Results> _execute(_PreparedQuery preparedQuery, List values,
      {bool retainConnection: false}) {
    _log.finest("About to execute");
    var c = new Completer<Results>();
    var handler = new _ExecuteQueryHandler(preparedQuery, _executed, values);
    preparedQuery.cnx.autoRelease = !retainConnection;
    preparedQuery.cnx.processHandler(handler)
      .then((results) {
        _log.finest("Prepared query got results");
        c.complete(results);
      })
      .catchError((e) {
        _releaseReuseCompleteError(preparedQuery.cnx, c, e);
      });
    return c.future;
  }

  /**
   * Executes the query once for each set of [parameters], and returns a future list
   * of results, one for each set of parameters, that completes when the query has been executed.
   *
   * The [Results] in the list contain their rows in the [Results.rows] field, rather than in the
   * [Results.stream] field.
   */
  Future<List<Results>> executeMulti(List<List> parameters) {
    return _prepare(true)
      .then((preparedQuery) {
        var c = new Completer<List<Results>>();
        _log.fine("Prepared query for multi execution. Number of values: ${parameters.length}");
        var resultList = new List<Results>();
        
        executeQuery(int i) {
          _log.fine("Executing query, loop $i");
          _execute(preparedQuery, parameters[i], retainConnection: true)
            .then((Results results) {
              _log.fine("Got results, loop $i");
              resultList.add(results);
              if (i < parameters.length - 1) {
                executeQuery(i + 1);
              } else {
                preparedQuery.cnx.release();
                c.complete(resultList);
              }
            })
            .catchError((e) {
              _releaseReuseCompleteError(preparedQuery.cnx, c, e);
            });
        }
        
        executeQuery(0);
        return c.future;
      });
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
