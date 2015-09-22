part of sqljocky;

abstract class _RetainedConnectionBase extends Object with _ConnectionHelpers implements QueriableConnection {
  _Connection _cnx;
  ConnectionPool _pool;
  bool _released;

  _RetainedConnectionBase._(this._cnx, this._pool) : _released = false;

  Future<Results> query(String sql) {
    _checkReleased();
    var handler = new _QueryStreamHandler(sql);
    return _cnx.processHandler(handler);
  }

  Future<Query> prepare(String sql) async {
    _checkReleased();
    var query = new Query._forTransaction(new _TransactionPool(_cnx), _cnx, sql);
    await query._prepare(true);
    return new Future.value(query);
  }

  Future<Results> prepareExecute(String sql, List parameters) async {
    _checkReleased();
    var query = await prepare(sql);
    var results = await query.execute(parameters);
    //TODO is it right to close here? Query might still be running
    query.close();
    return new Future.value(results);
  }

  void _checkReleased();

  _removeConnection(_Connection cnx) {
    _pool._removeConnection(cnx);
  }

  bool get usingSSL => _cnx.usingSSL;
}

/**
 * Use [ConnectionPool.getConnection] to get a connection to the database which
 * isn't released after each query. When you have finished with the connection
 * you must [release] it, otherwise it will never be available in the pool
 * again. 
 */
abstract class RetainedConnection extends QueriableConnection {
  /**
   * Releases the connection back to the connection pool.
   */
  Future release();
}

class _RetainedConnectionImpl extends _RetainedConnectionBase implements RetainedConnection {
  _RetainedConnectionImpl._(cnx, pool) : super._(cnx, pool);

  Future release() {
    _checkReleased();
    _released = true;

    _cnx.inTransaction = false;
    _cnx.release();
    _pool._reuseConnectionForQueuedOperations(_cnx);
  }

  void _checkReleased() {
    if (_released) {
      throw new StateError("Connection has already been released");
    }
  }
}
