part of sqljocky;

class Transaction {
  _Connection cnx;
  ConnectionPool _pool;
  bool _finished;
  
  // TODO: maybe give the connection a link to its transaction?

  Transaction._internal(this.cnx, this._pool) : _finished = false;
  
  Future commit() {
    _checkFinished();
    _finished = true;
    var c = new Completer();
  
    var handler = new QueryHandler("commit");
    cnx.processHandler(handler)
      .then((results) {
        _pool.releaseConnection(cnx);
        c.complete(results);
        _pool.reuseConnection(cnx);
      })
      .catchError((e) {
        c.completeError(e);
      });

    return c.future;
  }
  
  Future rollback() {
    _checkFinished();
    _finished = true;
    var c = new Completer();
  
    var handler = new QueryHandler("rollback");
    cnx.processHandler(handler)
      .then((results) {
        _pool.releaseConnection(cnx);
        c.complete(results);
        _pool.reuseConnection(cnx);
      })
      .catchError((e) {
        c.completeError(e);
      });

    return c.future;
  }

  Future<Results> query(String sql) {
    _checkFinished();
    var c = new Completer<Results>();
    
    var handler = new QueryHandler(sql);
    cnx.processHandler(handler)
      .then((results) {
        c.complete(results);
      })
      .catchError((e) {
        c.completeError(e);
      });

    return c.future;
  }
  
  //TODO: should the query get closed when the transaction is closed?
  //TODO: it isn't valid any more, at least
  Future<Query> prepare(String sql) {
    _checkFinished();
    var query = new Query._forTransaction(new _TransactionPool(cnx), cnx, sql);
    var c = new Completer<Query>();
    query._prepare()
      .then((preparedQuery) {
        c.complete(query);
      })
      .catchError((e) {
        c.completeError(e);
      });
    return c.future;
  }
  
  Future<Results> prepareExecute(String sql, List<dynamic> parameters) {
    _checkFinished();
    var c = new Completer<Results>();
    prepare(sql)
      .then((query) {
        query.execute()
          .then((results) {
            query.close();
            c.complete(results);
          })
          .catchError((e) {
            c.completeError(e);
          });
      })
      .catchError((e) {
        c.completeError(e);
      });
    return c.future;
  }

  void _checkFinished() {
    if (_finished) {
      throw new StateError("Transaction has already finished");
    }
  }
}

class _TransactionPool extends ConnectionPool {
  final _Connection cnx;
  
  _TransactionPool(this.cnx);
  
  Future<_Connection> _getConnection() {
    var c = new Completer<_Connection>();
    c.complete(cnx);
    return c.future;
  }
  
  releaseConnection(_Connection cnx) {
  }
  
  reuseConnection(_Connection cnx) {
  }
}