part of sqljocky;

/**
 * Start a transaction by using [ConnectionPool.startTransaction]. Once a transaction
 * is started it retains its connection until the transaction is committed or rolled
 * back. You must use the [commit] and [rollback] methods to do this, otherwise
 * the connection will not be released back to the pool.
 */
abstract class Transaction extends QueriableConnection {
  /**
   * Commits the transaction and released the connection. An error will be thrown
   * if any queries are executed after calling commit.
   */
  Future commit();

  /**
   * Rolls back the transaction and released the connection. An error will be thrown
   * if any queries are executed after calling rollback.
   */
  Future rollback();
}

class _TransactionImpl extends _RetainedConnectionBase implements Transaction {
  _TransactionImpl._(cnx, pool) : super._(cnx, pool);
  
  Future commit() {
    _checkReleased();
    _released = true;
  
    var handler = new _QueryStreamHandler("commit");
    return _cnx.processHandler(handler)
      .then((results) {
        _cnx.inTransaction = false;
        _cnx.release();
        _pool._newReuseConnection(_cnx);
        return results;
      });
  }
  
  Future rollback() {
    _checkReleased();
    _released = true;
  
    var handler = new _QueryStreamHandler("rollback");
    return _cnx.processHandler(handler)
      .then((results) {
        _cnx.inTransaction = false;
        _cnx.release();
        _pool._newReuseConnection(_cnx);
        return results;
      });
  }

  void _checkReleased() {
    if (_released) {
      throw new StateError("Transaction has already finished");
    }
  }
}

class _TransactionPool extends ConnectionPool {
  final _Connection cnx;
  
  _TransactionPool(this.cnx);
  
  Future<_Connection> _getConnection() => new Future.value(cnx);
  
  _removeConnection(_Connection cnx) {
  }
}
