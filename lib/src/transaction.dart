part of sqljocky;

/**
 * Start a transaction by using [ConnectionPool.startTransaction]. Once a transaction
 * is started it retains its connection until the transaction is committed or rolled
 * back. You must use the [commit] and [rollback] methods to do this, otherwise
 * the connection will not be released back to the pool.
 */
class Transaction extends Object with _ConnectionHelpers implements QueriableConnection {
  _Connection _cnx;
  ConnectionPool _pool;
  bool _finished;
  
  // TODO: maybe give the connection a link to its transaction?

  Transaction._internal(this._cnx, this._pool) : _finished = false;
  
  /**
   * Commits the transaction and released the connection. An error will be thrown
   * if any queries are executed after calling commit.
   */
  Future commit() {
    _checkFinished();
    _finished = true;
  
    var handler = new _QueryStreamHandler("commit");
    return _cnx.processHandler(handler)
      .then((results) {
        var c = new Completer();
        _releaseReuseComplete(_cnx, c, results);
        return c.future;
      });
  }
  
  /**
   * Rolls back the transaction and released the connection. An error will be thrown
   * if any queries are executed after calling rollback.
   */
  Future rollback() {
    _checkFinished();
    _finished = true;
  
    var handler = new _QueryStreamHandler("rollback");
    return _cnx.processHandler(handler)
      .then((results) {
        var c = new Completer();
        _releaseReuseComplete(_cnx, c, results);
        return c.future;
      });
  }

  Future<Results> query(String sql) {
    _checkFinished();
    var handler = new _QueryStreamHandler(sql);
    return _cnx.processHandler(handler);
  }
  
  //TODO: should the query get closed when the transaction is closed?
  //TODO: it isn't valid any more, at least
  Future<Query> prepare(String sql) {
    _checkFinished();
    var query = new Query._forTransaction(new _TransactionPool(_cnx), _cnx, sql);
    return query._prepare().then((preparedQuery) => new Future.value(query));
  }
  
  Future<Results> prepareExecute(String sql, List parameters) {
    _checkFinished();
    return prepare(sql)
      .then((query) {
        return query.execute(parameters)
          .then((results) {
            //TODO is it right to close here? Query might still be running
            query.close();
            return new Future.value(results);
          });
      });
  }

  void _checkFinished() {
    if (_finished) {
      throw new StateError("Transaction has already finished");
    }
  }

  _releaseConnection(_Connection cnx) {
    _pool._releaseConnection(cnx);
  }

  _reuseConnection(_Connection cnx) {
    _pool._reuseConnection(cnx);
  }
  
  _removeConnection(_Connection cnx) {
    _pool._removeConnection(cnx);
  }
}

class _TransactionPool extends ConnectionPool {
  final _Connection cnx;
  
  _TransactionPool(this.cnx);
  
  Future<_Connection> _getConnection() => new Future.value(cnx);
  
  _releaseConnection(_Connection cnx) {
  }
  
  _reuseConnection(_Connection cnx) {
  }
  
  _removeConnection(_Connection cnx) {
  }
}
