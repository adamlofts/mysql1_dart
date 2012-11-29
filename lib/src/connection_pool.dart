part of sqljocky;

class ConnectionRequest {
  final Completer<_Connection> c;
  
  ConnectionRequest(this.c);
}

class ConnectionPool {
  final Logger log;

  final String _host;
  final int _port;
  final String _user;
  final String _password;
  final String _db;
  
  int _max;
  
  final Queue<ConnectionRequest> _pendingConnections;
  final List<_Connection> _pool;
  
  addPendingConnection(Completer<_Connection> pendingConnection) {
    _pendingConnections.add(new ConnectionRequest(pendingConnection));
  }

  ConnectionPool({String host: 'localhost', int port: 3306, String user, 
      String password, String db, int max: 5}) :
        _pendingConnections = new Queue<ConnectionRequest>(),
        _pool = new List<_Connection>(),
        _host = host,
        _port = port,
        _user = user,
        _password = password,
        _db = db,
        _max = max,
        log = new Logger("ConnectionPool");
  
  Future<_Connection> _getConnection() {
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
        log.finest("Using open pooled cnx#${cnx.number}");
        cnx.use();
        c.complete(cnx);
        return c.future;
      }
    }
    
    if (_pool.length < _max) {
      log.finest("Creating new pooled cnx#${_pool.length}");
      _Connection cnx = new _Connection(this, _pool.length);
      cnx.use();
      var future = cnx.connect(
          host: _host, 
          port: _port, 
          user: _user, 
          password: _password, 
          db: _db);
      _pool.add(cnx);
      future.then((x) {
        log.finest("Logged in on cnx#${cnx.number}");
        c.complete(cnx);
      });
      handleFutureException(future, c, cnx);
    } else {
      log.finest("Waiting for an available connection");
      addPendingConnection(c);
    }
    return c.future;
  }
  
  releaseConnection(_Connection cnx) {
    cnx.release();
    log.finest("Finished with cnx#${cnx.number}: marked as not in use");
  }
  
  reuseConnection(_Connection cnx) {
    if (!_pool.contains(cnx)) {
      log.warning("reuseConnection called for unmanaged connection");
      return;
    }
    
    if (cnx.inUse) {
      log.finest("cnx#${cnx.number} already reused");
      return;
    }
    
    if (_pendingConnections.length > 0) {
      log.finest("Reusing cnx#${cnx.number} for a queued operation");
      var request = _pendingConnections.removeFirst();
      cnx.use();
      request.c.complete(cnx);
    }
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
    log.info("Running query: ${sql}");
    var c = new Completer<Results>();
    
    var cnxFuture = _getConnection();
    cnxFuture.then((cnx) {
      log.fine("Got cnx#${cnx.number} for query");
      var handler = new QueryHandler(sql);
      var queryFuture = cnx.processHandler(handler);
      queryFuture.then((results) {
        log.fine("Got query results on #${cnx.number} for: ${sql}");
        releaseConnection(cnx);
        c.complete(results);
        reuseConnection(cnx);
      });
      handleFutureException(queryFuture, c, cnx);
    });
    handleFutureException(cnxFuture, c);

    return c.future;
  }
  
  Future<int> update(String sql) {
  }
  
  Future ping() {
    log.info("Pinging server");
    var c = new Completer<Results>();
    
    var cnxFuture = _getConnection();
    cnxFuture.then((cnx) {
      var handler = new PingHandler();
      var future = cnx.processHandler(handler);
      future.then((x) {
        log.fine("Pinged");
        releaseConnection(cnx);
        c.complete(x);
        reuseConnection(cnx);
      });
      handleFutureException(future, c);
    });
    handleFutureException(cnxFuture, c);
    
    return c.future;
  }
  
  Future debug() {
    log.info("Sending debug message");
    var c = new Completer<Results>();
    
    var cnxFuture = _getConnection();
    cnxFuture.then((cnx) {
      var handler = new DebugHandler();
      var future = cnx.processHandler(handler);
      future.then((x) {
        log.fine("Message sent");
        c.complete(x);
        releaseConnection(cnx);
      });
      handleFutureException(future, c, cnx);
    });
    handleFutureException(cnxFuture, c);
    
    return c.future;
  }
  
  void _closeQuery(Query q, bool retain) {
    log.finest("Closing query: ${q.sql}");
    for (var cnx in _pool) {
      var preparedQuery = cnx.removePreparedQueryFromCache(q.sql);
      if (preparedQuery != null) {
        cnx.whenReady().then((x) {
          log.finest("Connection ready - closing query: ${q.sql}");
          var handler = new CloseStatementHandler(preparedQuery.statementHandlerId);
          var future = cnx.processHandler(handler, noResponse: true);
          future.then((x) {
            if (!retain) {
              releaseConnection(cnx);
              reuseConnection(cnx);
            }
          });
          future.handleException((e) {
            if (!retain) {
              releaseConnection(cnx);
              reuseConnection(cnx);
            }
          });
        });
      }
    }
  }
  
  Future<Query> prepare(String sql) {
    var query = new Query._internal(this, sql);
    var c = new Completer<Query>();
    var future = query._prepare();
    future.then((preparedQuery) {
      log.info("Got value count");
      releaseConnection(preparedQuery.cnx);
      c.complete(query);
      reuseConnection(preparedQuery.cnx);
    });
    handleFutureException(future, c); //TODO release connection here?
    return c.future;
  }
  
  Future<Transaction> startTransaction({bool consistent: false}) {
    log.info("Starting transaction");
    var c = new Completer<Transaction>();
    
    var cnxFuture = _getConnection();
    cnxFuture.then((cnx) {
      var sql;
      if (consistent) {
        sql = "start transaction with consistent snapshot";
      } else {
        sql = "start transaction";
      }
      var handler = new QueryHandler(sql);
      var queryFuture = cnx.processHandler(handler);
      queryFuture.then((results) {
        log.fine("Transaction started on cnx#${cnx.number}");
        var transaction = new Transaction._internal(cnx, this);
        c.complete(transaction);
      });
      handleFutureException(queryFuture, c, cnx);
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

