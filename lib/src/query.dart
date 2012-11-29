part of sqljocky;

class Query {
  final ConnectionPool _pool;
  final _Connection _cnx;
  List<dynamic> _values;
  final String sql;
  bool _executed = false;
  final Logger log;
  final _inTransaction;
  
//  int get statementId => _preparedQuery.statementHandlerId;
  
  Query._internal(this._pool, this.sql) :
      _cnx = null,
      _inTransaction = false,
      log = new Logger("Query");

  Query._forTransaction(this._pool, _Connection cnx, this.sql) :
      _cnx = cnx,
      _inTransaction = true,
      log = new Logger("Query");
  
  Future<_Connection> _getConnection() {
    if (_cnx != null) {
      var c = new Completer<_Connection>();
      c.complete(_cnx);
      return c.future;
    }
    return _pool._getConnection();
  }

  Future<PreparedQuery> _prepare() {
    log.fine("Getting prepared query for: $sql");
    var c = new Completer<PreparedQuery>();
    
    var cnxFuture = _getConnection();
    cnxFuture.then((cnx) {
      log.fine("Got cnx#${cnx.number}");
      var preparedQuery = cnx.getPreparedQueryFromCache(sql);
      if (preparedQuery != null) {
        log.fine("Got prepared query from cache in cnx#${cnx.number} for: $sql");
        if (_values == null) {
          _values = new List<dynamic>(preparedQuery.parameters.length);
        }
        c.complete(preparedQuery);
        return;
      }
      
      log.fine("Preparing new query in cnx#${cnx.number} for: $sql");
      var handler = new PrepareHandler(sql);
      cnx.use();
      Future<PreparedQuery> queryFuture = cnx.processHandler(handler);
      queryFuture.then((preparedQuery) {
        log.fine("Prepared new query in cnx#${cnx.number} for: $sql");
        preparedQuery.cnx = cnx;
        cnx.putPreparedQueryInCache(sql, preparedQuery);
        if (_values == null) {
          _values = new List<dynamic>(preparedQuery.parameters.length);
        }
        c.complete(preparedQuery);
      });
      handleFutureException(queryFuture, c, cnx);
    });
    handleFutureException(cnxFuture, c);
    return c.future;
  }
      
  handleFutureException(Future f, Completer c, [_Connection cnx]) {
    f.handleException((e) {
      c.completeException(e);
      if (cnx != null) {
        releaseConnection(cnx);
        reuseConnection(cnx);
      }
      return true;
    });
  }

  void close() {
    _pool._closeQuery(this, _inTransaction);
  }
  
  
  //TODO: maybe have execute(Transaction) and execute(ConnectionPool)
  Future<Results> execute() {
    var c = new Completer<Results>();
    var future = _prepare();
    future.then((preparedQuery) {
      var future = _execute(preparedQuery);
      future.then((Results results) {
        releaseConnection(preparedQuery.cnx);
        c.complete(results);
        reuseConnection(preparedQuery.cnx);
      });
      handleFutureException(future, c);
    });
    handleFutureException(future, c);
    return c.future;
  }
  
  Future<Results> _execute(PreparedQuery preparedQuery) {
    log.finest("About to execute");
    var c = new Completer<Results>();
    var handler = new ExecuteQueryHandler(preparedQuery, _executed, _values);
    var handlerFuture = preparedQuery.cnx.processHandler(handler);
    handlerFuture.then((results) {
      log.finest("Prepared query got results");
      c.complete(results);
    });
    handleFutureException(handlerFuture, c, preparedQuery.cnx);
    return c.future;
  }
  
  Future<List<Results>> executeMulti(List<List<dynamic>> parameters) {
    var c = new Completer<List<Results>>();
    var future = _prepare();
    future.then((preparedQuery) {
      log.fine("Prepared query for multi execution. Number of values: ${parameters.length}");
      var resultList = new List<Results>();
      exec(int i) {
        log.fine("Executing query, loop $i");
        _values.setRange(0, _values.length, parameters[i]);
        var future = _execute(preparedQuery);
        future.then((Results results) {
          log.fine("Got results, loop $i");
          resultList.add(results);
          if (i < parameters.length - 1) {
            exec(i + 1);
          } else {
            releaseConnection(preparedQuery.cnx);
            c.complete(resultList);
            reuseConnection(preparedQuery.cnx);
          }
        });
        handleFutureException(future, c, preparedQuery.cnx);
      }
      exec(0);
    });
    handleFutureException(future, c);
    return c.future;
  } 
  
  Future<int> executeUpdate() {
    
  }

  dynamic operator [](int pos) => _values[pos];
  
  void operator []=(int index, dynamic value) {
    _values[index] = value;
    _executed = false;
  }

  releaseConnection(_Connection cnx) {
    if (!_inTransaction) {
      _pool.releaseConnection(cnx);
    }
  }

  reuseConnection(_Connection cnx) {
    if (!_inTransaction) {
      _pool.reuseConnection(cnx);
    }
  }
//  dynamic longData(int index, data);
//  dynamic reset();
//  dynamic fetch(int rows);
}

