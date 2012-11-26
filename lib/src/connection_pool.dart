part of sqljocky;

class ConnectionPool {
  final Logger log;

  final String _host;
  final int _port;
  final String _user;
  final String _password;
  final String _db;
  
  int _max;
  
  final Queue<Completer<_Connection>> _pendingConnections;
  final List<_Connection> _pool;
  
  addPendingConnection(Completer<_Connection> pendingConnection) {
    _pendingConnections.add(pendingConnection);
  }

  ConnectionPool({String host: 'localhost', int port: 3306, String user, 
      String password, String db, int max: 5}) :
        _pendingConnections = new Queue<Completer>(),
        _pool = new List<_Connection>(),
        _host = host,
        _port = port,
        _user = user,
        _password = password,
        _db = db,
        _max = max,
        log = new Logger("ConnectionPool");
  
  Future<_Connection> _getConnection({bool retain: false}) {
    log.finest("Getting a connection");
    var c = new Completer<_Connection>();

    var inUseCount = 0;
    for (var cnx in _pool) {
      if (cnx.inUse) {
        inUseCount++;
      }
    }
    log.finest("Number of in-use connections: $inUseCount");
    
    for (var cnx in _pool) {
      if (!cnx.inUse) {
        log.finest("Reusing existing pooled connection");
        cnx.use(retain: retain);
        c.complete(cnx);
        return c.future;
      }
    }
    
    if (_pool.length < _max) {
      log.finest("Creating new pooled connection");
      _Connection cnx = new _Connection(this);
      cnx.onFinished = _getConnectionFinishedWithHandler(cnx);
      var future = cnx.connect(
          host: _host, 
          port: _port, 
          user: _user, 
          password: _password, 
          db: _db);
      cnx.use(retain: retain);
      _pool.add(cnx);
      future.then((x) {
        c.complete(cnx);
      });
      handleFutureException(future, c);
    } else {
      log.finest("Waiting for an available connection");
      addPendingConnection(c);
    }
    return c.future;
  }
  
  _getConnectionFinishedWithHandler(_Connection cnx) {
    return () {
      log.finest("Finished with a connection");
      if (!_pool.contains(cnx)) {
        print("_connectionFinishedWith handler called for unmanaged connection");
        return;
      }
      
      if (_pendingConnections.length > 0) {
        log.finest("Reusing connection for queued operation");
        var c = _pendingConnections.removeFirst();
        c.complete(cnx);
      } else {
        log.finest("Marking pooled connection as not in use");
      }
    };
  }
  
  // dangerous - would need to switch all connections
//  Future useDatabase(String dbName) {
//    var completer = new Completer();
//    
//    var cnxFuture = _getConnection();
//    cnxFuture.then((cnx) {
//      var handler = new UseDbHandler(dbName);
//      var future = _connection.processHandler(handler);
//      future.then((x) {
//        completer.completer();
//      });
//      handleFutureException(future, completer);
//    });
//    handleFutureException(cnxFuture, completer);
//    
//    return completer.future;
//  }
  
  void close() {
    for (_Connection cnx in _pool) {
      cnx.close();
    }
  }

  Future<Results> query(String sql) {
    var c = new Completer<Results>();
    
    var cnxFuture = _getConnection();
    cnxFuture.then((cnx) {
      var handler = new QueryHandler(sql);
      var queryFuture = cnx.processHandler(handler);
      queryFuture.then((results) {
        c.complete(results);
      });
      handleFutureException(queryFuture, c);
    });
    handleFutureException(cnxFuture, c);

    return c.future;
  }
  
  Future<int> update(String sql) {
  }
  
  Future ping() {
    var c = new Completer<Results>();
    
    var cnxFuture = _getConnection();
    cnxFuture.then((cnx) {
      var handler = new PingHandler();
      var future = cnx.processHandler(handler);
      future.then((x) {
        c.complete(x);
      });
      handleFutureException(future, c);
    });
    handleFutureException(cnxFuture, c);
    
    return c.future;
  }
  
  Future debug() {
    var c = new Completer<Results>();
    
    var cnxFuture = _getConnection();
    cnxFuture.then((cnx) {
      var handler = new DebugHandler();
      var future = cnx.processHandler(handler);
      future.then((x) {
        c.complete(x);
      });
      handleFutureException(future, c);
    });
    handleFutureException(cnxFuture, c);
    
    return c.future;
  }
  
  void _closeQuery(Query q) {
    for (var cnx in _pool) {
      var preparedQuery = cnx.removePreparedQueryFromCache(q.sql);
      if (preparedQuery != null) {
        cnx.whenReady().then((x) {
          var handler = new CloseStatementHandler(preparedQuery.statementHandlerId);
          cnx.processHandler(handler, noResponse: true);
        });
      }
    }
  }
  
  Future<Query> prepare(String sql) {
    var query = new Query._internal(this, sql);
    var c = new Completer<Query>();
    var future = query._getValueCount();
    future.then((preparedQuery) {
      preparedQuery.cnx.release();
      c.complete(query);
    });
    handleFutureException(future, c);
    return c.future;
  }
  
  Future<Transaction> startTransaction({bool consistent: false}) {
    var c = new Completer<Transaction>();
    
    var cnxFuture = _getConnection();
    cnxFuture.then((cnx) {
      cnx.use(retain: true, inTransaction: true);
      var sql;
      if (consistent) {
        sql = "start transaction with consistent snapshot";
      } else {
        sql = "start transaction";
      }
      var handler = new QueryHandler(sql);
      var queryFuture = cnx.processHandler(handler);
      queryFuture.then((results) {
        var transaction = new Transaction._internal(cnx);
        c.complete(transaction);
      });
      handleFutureException(queryFuture, c);
    });
    handleFutureException(cnxFuture, c);
    
    return c.future;
  }
  
  Future<Results> prepareExecute(String sql, List<dynamic> parameters) {
    var c = new Completer<Results>();
    Future<Query> future = prepare(sql);
    future.then((Query q) {
      for (int i = 0; i < parameters.length; i++) {
        q[i] = parameters[i];
      }
      var future = q.execute();
      future.then((Results results) {
        c.complete(results);
      });
      handleFutureException(future, c);
    });
    handleFutureException(future, c);
    return c.future;
  }
  
  handleFutureException(Future f, Completer c) {
    f.handleException((e) {
      c.completeException(e);
      return true;
    });
  }

//  dynamic fieldList(String table, [String column]);
//  dynamic refresh(bool grant, bool log, bool tables, bool hosts,
//                  bool status, bool threads, bool slave, bool master);
//  dynamic shutdown(bool def, bool waitConnections, bool waitTransactions,
//                   bool waitUpdates, bool waitAllBuffers,
//                   bool waitCriticalBuffers, bool killQuery, bool killConnection);
//  dynamic statistics();
//  dynamic processInfo();
//  dynamic processKill(int id);
//  dynamic changeUser(String user, String password, [String db]);
//  dynamic binlogDump(options);
//  dynamic registerSlave(options);
//  dynamic setOptions(int option);
}

class Query {
  final ConnectionPool _pool;
  final _Connection _cnx;
  List<dynamic> _values;
  final String sql;
  bool _executed = false;
  final Logger log;
  
//  int get statementId => _preparedQuery.statementHandlerId;
  
  Query._internal(ConnectionPool pool, this.sql) :
      _pool = pool,
      _cnx = null,
      log = new Logger("Query");

  Query._withConnection(_Connection cnx, this.sql) :
      _pool = null,
      _cnx = cnx,
      log = new Logger("Query");
  
  Future<PreparedQuery> _getValueCount() {
    return _prepare();
  }

  Future<_Connection> _getConnection({bool retain: true}) {
    if (_cnx != null) {
      var c = new Completer<_Connection>();
      c.complete(_cnx);
      return c.future;
    }
    return _pool._getConnection(retain: retain);
  }

  Future<PreparedQuery> _prepare() {
    var c = new Completer<PreparedQuery>();
    
    var cnxFuture = _getConnection(retain: true);
    cnxFuture.then((cnx) {
      var preparedQuery = cnx.getPreparedQueryFromCache(sql);
      if (preparedQuery != null) {
        c.complete(preparedQuery);
        return c.future;
      }
      
      var handler = new PrepareHandler(sql);
      Future<PreparedQuery> queryFuture = cnx.processHandler(handler);
      queryFuture.then((preparedQuery) {
        preparedQuery.cnx = cnx;
        cnx.putPreparedQueryInCache(sql, preparedQuery);
        if (_values == null) {
          _values = new List<dynamic>(preparedQuery.parameters.length);
        }
        c.complete(preparedQuery);
      });
      handleFutureException(queryFuture, c);
    });
    handleFutureException(cnxFuture, c);
    return c.future;
  }
      
  handleFutureException(Future f, Completer c) {
    f.handleException((e) {
      c.completeException(e);
      return true;
    });
  }

  void close() {
    _pool._closeQuery(this);
  }
  
  Future<Results> execute() {
    var c = new Completer<Results>();
    var future = _prepare();
    future.then((preparedQuery) {
      var handler = new ExecuteQueryHandler(preparedQuery, _executed, _values);
      var handlerFuture = preparedQuery.cnx.processHandler(handler);
      handlerFuture.then((results) {
        log.finest("Prepared query finished with connection");
        preparedQuery.cnx.release();
        c.complete(results);
      });
      handleFutureException(handlerFuture, c);
    });
    handleFutureException(future, c);
    return c.future;
  }
  
  Future<List<Results>> executeMulti(List<List<dynamic>> parameters) {
    Completer<List<Results>> c= new Completer<List<Results>>();
    List<Results> resultList = new List<Results>();
    exec(int i) {
      _values.setRange(0, _values.length, parameters[i]);
      var future = execute();
      future.then((Results results) {
        resultList.add(results);
        if (i < parameters.length - 1) {
          exec(i + 1);
        } else {
          c.complete(resultList);
        }
      });
      handleFutureException(future, c);
    }
    exec(0);
    return c.future;
  } 
  
  Future<int> executeUpdate() {
    
  }

  dynamic operator [](int pos) => _values[pos];
  
  void operator []=(int index, dynamic value) {
    _values[index] = value;
    _executed = false;
  }
  
//  dynamic longData(int index, data);
//  dynamic reset();
//  dynamic fetch(int rows);
}

class Transaction {
  _Connection cnx;
  bool _finished;
  
  // TODO: maybe give the connection a link to its transaction?

  handleFutureException(Future f, Completer c) {
    f.handleException((e) {
      c.completeException(e);
      return true;
    });
  }
  
  Transaction._internal(this.cnx) : _finished = false;
  
  Future commit() {
    _checkFinished();
    _finished = true;
    var c = new Completer();
  
    var handler = new QueryHandler("commit");
    var queryFuture = cnx.processHandler(handler);
    queryFuture.then((results) {
      cnx.release(fromTransaction: true);
      c.complete(results);
    });
    handleFutureException(queryFuture, c);

    return c.future;
  }
  
  Future rollback() {
    _checkFinished();
    _finished = true;
    var c = new Completer();
  
    var handler = new QueryHandler("rollback");
    var queryFuture = cnx.processHandler(handler);
    queryFuture.then((results) {
      cnx.release(fromTransaction: true);
      c.complete(results);
    });
    handleFutureException(queryFuture, c);

    return c.future;
  }

  Future<Results> query(String sql) {
    _checkFinished();
    var c = new Completer<Results>();
    
    var handler = new QueryHandler(sql);
    var queryFuture = cnx.processHandler(handler);
    queryFuture.then((results) {
      c.complete(results);
    });
    handleFutureException(queryFuture, c);

    return c.future;
  }
  
  Future<Query> prepare(String sql) {
    _checkFinished();
    var query = new Query._withConnection(cnx, sql);
    var c = new Completer<Query>();
    var future = query._getValueCount();
    future.then((preparedQuery) {
      preparedQuery.cnx.release();
      c.complete(query);
    });
    handleFutureException(future, c);
    return c.future;
  }
  
  Future<Results> prepareExecute(String sql, List<dynamic> parameters) {
    _checkFinished();
  }

  void _checkFinished() {
    if (_finished) {
      throw new StateError("Transaction has already finished");
    }
  }
}
