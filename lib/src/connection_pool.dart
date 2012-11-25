part of sqljocky;

class ConnectionPool {
  final Logger log;

  final String _host;
  final int _port;
  final String _user;
  final String _password;
  final String _db;
  
  int _max;
  
  final Queue<Completer<Connection>> _pendingConnections;
  final List<Connection> _pool;
  
  addPendingConnection(Completer<Connection> pendingConnection) {
    _pendingConnections.add(pendingConnection);
  }

  ConnectionPool({String host: 'localhost', int port: 3306, String user, 
      String password, String db, int max: 5}) :
        _pendingConnections = new Queue<Completer>(),
        _pool = new List<Connection>(),
        _host = host,
        _port = port,
        _user = user,
        _password = password,
        _db = db,
        _max = max,
        log = new Logger("ConnectionPool");
  
  Future<Connection> _getConnection({bool retain: false}) {
    log.finest("Getting a connection");
    var c = new Completer<Connection>();

    var inUseCount = 0;
    for (var cnx in _pool) {
      if (cnx._inUse) {
        inUseCount++;
      }
    }
    log.finest("Number of in-use connections: $inUseCount");
    
    for (var cnx in _pool) {
      if (!cnx._inUse) {
        log.finest("Reusing existing pooled connection");
        cnx._inUse = true;
        cnx._retain = retain;
        c.complete(cnx);
        return c.future;
      }
    }
    
    if (_pool.length < _max) {
      log.finest("Creating new pooled connection");
      Connection cnx = new Connection(this);
      cnx.onFinished = _getConnectionFinishedWithHandler(cnx);
      var future = cnx.connect(
          host: _host, 
          port: _port, 
          user: _user, 
          password: _password, 
          db: _db);
      cnx._inUse = true;
      cnx._retain = retain;
      _pool.add(cnx);
      future.then((x) {
        c.complete(cnx);
      });
      future.handleException((e) {
        c.completeException(e);
        return true;
      });
    } else {
      log.finest("Waiting for an available connection");
      addPendingConnection(c);
    }
    return c.future;
  }
  
  _getConnectionFinishedWithHandler(Connection cnx) {
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
        cnx._inUse = false;
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
//      var future = _connection._processHandler(handler);
//      future.then((x) {
//        completer.completer();
//      });
//      future.handleException((e) {
//        completer.completeException(e);
//        return true;
//      });
//    });
//    cnxFuture.handleException((e) {
//      completer.completeException(e);
//      return true;
//    });
//    
//    return completer.future;
//  }
  
  void close() {
    for (Connection cnx in _pool) {
      cnx.close();
    }
  }

  Future<Results> query(String sql) {
    var c = new Completer<Results>();
    
    var cnxFuture = _getConnection();
    cnxFuture.then((cnx) {
      var handler = new QueryHandler(sql);
      var queryFuture = cnx._processHandler(handler);
      queryFuture.then((results) {
        c.complete(results);
      });
      queryFuture.handleException((e) {
        c.completeException(e);
        return true;
      });
    });
    cnxFuture.handleException((e) {
      c.completeException(e);
      return true;
    });
    
    return c.future;
  }
  
  Future<int> update(String sql) {
  }
  
  Future ping() {
    var c = new Completer<Results>();
    
    var cnxFuture = _getConnection();
    cnxFuture.then((cnx) {
      var handler = new PingHandler();
      var future = cnx._processHandler(handler);
      future.then((x) {
        c.complete(x);
      });
      future.handleException((e) {
        c.completeException(e);
      });
    });
    cnxFuture.handleException((e) {
      c.completeException(e);
      return true;
    });
    
    return c.future;
  }
  
  Future debug() {
    var c = new Completer<Results>();
    
    var cnxFuture = _getConnection();
    cnxFuture.then((cnx) {
      var handler = new DebugHandler();
      var future = cnx._processHandler(handler);
      future.then((x) {
        c.complete(x);
      });
      future.handleException((e) {
        c.completeException(e);
      });
    });
    cnxFuture.handleException((e) {
      c.completeException(e);
      return true;
    });
    
    return c.future;
  }
  
  void _closeQuery(Query q) {
    for (var cnx in _pool) {
      if (cnx._preparedQueryCache.containsKey(q.sql)) {
        var preparedQuery = cnx._preparedQueryCache[q.sql];
        cnx._preparedQueryCache.remove(q.sql);
        cnx.whenReady().then((x) {
          var handler = new CloseStatementHandler(preparedQuery.statementHandlerId);
          cnx._processHandler(handler, noResponse: true);
        });
      }
    }
  }
  
  Future<Query> prepare(String sql) {
    var query = new Query._internal(this, sql);
    var c = new Completer<Query>();
    var future = query._getValueCount();
    future.then((preparedQuery) {
      preparedQuery._cnx._retain = false;
      preparedQuery._cnx._inUse = false;
      preparedQuery._cnx._finished();
      c.complete(query);
    });
    future.handleException((e) {
      c.completeException(e);
      return true;
    });
    return c.future;
  }
  
  Future<Transaction> startTransaction({bool consistent: false}) {
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
      var queryFuture = cnx._processHandler(handler);
      queryFuture.then((results) {
        var transaction = new Transaction._internal(cnx);
        c.complete(transaction);
      });
      queryFuture.handleException((e) {
        c.completeException(e);
        return true;
      });
    });
    cnxFuture.handleException((e) {
      c.completeException(e);
      return true;
    });
    
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
      future.handleException((e) {
        c.completeException(e);
        return true;
      });
    });
    future.handleException((e) {
      c.completeException(e);
      return true;
    });
    return c.future;
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
  List<dynamic> _values;
  final String sql;
  bool _executed = false;
  final Logger log;
  
//  int get statementId => _preparedQuery.statementHandlerId;
  
  Query._internal(ConnectionPool pool, this.sql) :
      _pool = pool,
      log = new Logger("Query");
  
  Future<PreparedQuery> _getValueCount() {
    return _prepare();
  }

  Future<PreparedQuery> _prepare() {
    Completer c = new Completer<PreparedQuery>();
    
    var cnxFuture = _pool._getConnection(retain: true);
    cnxFuture.then((cnx) {
      if (cnx._preparedQueryCache.containsKey(sql)) {
        c.complete(cnx._preparedQueryCache[sql]);
        return c.future;
      }
      
      var handler = new PrepareHandler(sql);
      Future<PreparedQuery> queryFuture = cnx._processHandler(handler);
      queryFuture.then((preparedQuery) {
        preparedQuery._cnx = cnx;
        cnx._preparedQueryCache[sql] = preparedQuery;
        if (_values == null) {
          _values = new List<dynamic>(preparedQuery.parameters.length);
        }
        c.complete(preparedQuery);
      });
      queryFuture.handleException((e) {
        c.completeException(e);
        return true;
      });
    });
    cnxFuture.handleException((e) {
      c.completeException(e);
      return true;
    });
    return c.future;
  }
      

  void close() {
    _pool._closeQuery(this);
  }
  
  Future<Results> execute() {
    var c = new Completer<Results>();
    var future = _prepare();
    future.then((preparedQuery) {
      var handler = new ExecuteQueryHandler(preparedQuery, _executed, _values);
      var handlerFuture = preparedQuery._cnx._processHandler(handler);
      handlerFuture.then((results) {
        log.finest("Finished with prepared query, setting in-use to false");
        preparedQuery._cnx._retain = false;
        preparedQuery._cnx._inUse = false;
        preparedQuery._cnx._finished();
        c.complete(results);
      });
      handlerFuture.handleException((e) {
        c.completeException(e);
        return true;
      });
    });
    future.handleException((e) {
      c.completeException(e);
      return true;
    });
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
      future.handleException((e) {
        c.completeException(e);
        return true;
      });
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
  Connection cnx;
  
  // TODO: make connection persistent here
  // TODO: maybe give the connection a link to its transaction?
  
  Transaction._internal(this.cnx);
  
  Future commit() {
    return query("commit");
  }
  
  Future rollback() {
    return query("rollback");
  }

  Future<Results> query(String sql) {
    var c = new Completer<Results>();
    
    var handler = new QueryHandler(sql);
    var queryFuture = cnx._processHandler(handler);
    queryFuture.then((results) {
      c.complete(results);
    });
    queryFuture.handleException((e) {
      c.completeException(e);
      return true;
    });

    return c.future;
  }
  
  Future<Query> prepare(String sql) {
    
  }
  
  Future<Results> prepareExecute(String sql, List<dynamic> parameters) {
    
  }
}