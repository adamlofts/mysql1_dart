part of sqljocky;

/**
 * Maintains a pool of database connections. When queries are executed, if there is
 * a free connection it will be used, otherwise the query is queued until a connection is
 * free. 
 */
class ConnectionPool {
  final Logger log;

  final String _host;
  final int _port;
  final String _user;
  final String _password;
  final String _db;
  
  int _max;

  /*
   * The pool maintains a queue of connection requests. When a connection completes, if there
   * is a connection in the queue then it is 'activated' - that is, the future returned 
   * by _getConnection() completes.
   */
  final Queue<Completer<_Connection>> _pendingConnections;
  final List<_Connection> _pool;
  
  /**
   * Creates a [ConnectionPool]. When connections are required they will connect to the
   * [db] on the given [host] and [port], using the [user] and [password]. The [max] number
   * of simultaneous connections can also be specified.
   */
  ConnectionPool({String host: 'localhost', int port: 3306, String user,
      String password, String db, int max: 5}) :
        _pendingConnections = new Queue<Completer<_Connection>>(),
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
      var cnx = new _Connection(this, _pool.length);
      cnx.use();
      var future = cnx.connect(
          host: _host, 
          port: _port, 
          user: _user, 
          password: _password, 
          db: _db);
      _pool.add(cnx);
      future
        .then((x) {
          log.finest("Logged in on cnx#${cnx.number}");
          c.complete(cnx);
        })
        .catchError((e) {
          c.completeError(e);
          _releaseConnection(cnx);
          _reuseConnection(cnx);
        });
    } else {
      log.finest("Waiting for an available connection");
      _pendingConnections.add(c);
    }
    return c.future;
  }
  
  _releaseConnection(_Connection cnx) {
    cnx.release();
    log.finest("Finished with cnx#${cnx.number}: marked as not in use");
  }
  
  /**
   * Attempts to continue using a connection. If the connection isn't managed
   * by this pool, or if the connection is already in use, nothing happens.
   * 
   * If there are operations which have been queued in this pool, starts
   * to execute that operation. 
   * 
   * Otherwise, nothing happens.
   * 
   * //TODO rename to something like processQueuedOperations??
   */
  _reuseConnection(_Connection cnx) {
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
      var c = _pendingConnections.removeFirst();
      cnx.use();
      c.complete(cnx);
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
  
  /**
   * Closes all open connections. 
   * 
   * WARNING: this will probably break things.
   */
  void close() {
    for (_Connection cnx in _pool) {
      cnx.close();
    }
  }

  /**
   * Executes the [sql] query as soon as a connection is available, returning
   * a [Future<Results>] that completes when the results are available.
   */
  Future<Results> query(String sql) {
    log.info("Running query: ${sql}");
    var c = new Completer<Results>();
    
    _getConnection()
      .then((cnx) {
        log.fine("Got cnx#${cnx.number} for query");
        cnx.processHandler(new _QueryHandler(sql))
          .then((results) {
            log.fine("Got query results on #${cnx.number} for: ${sql}");
            _releaseConnection(cnx);
            c.complete(results);
            _reuseConnection(cnx);
          })
          .catchError((e) {
            c.completeError(e);
            _releaseConnection(cnx);
            _reuseConnection(cnx);
          });
      })
      .catchError((e) {
        c.completeError(e);
      });

    return c.future;
  }

  /**
   * Pings the server. Returns a [Future] that completes when the server replies.
   */
  Future ping() {
    log.info("Pinging server");
    var c = new Completer<Results>();
    
    _getConnection()
      .then((cnx) {
        cnx.processHandler(new _PingHandler())
          .then((x) {
            log.fine("Pinged");
            _releaseConnection(cnx);
            c.complete(x);
            _reuseConnection(cnx);
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
  
  /**
   * Sends a debug message to the server. Returns a [Future] that completes
   * when the server replies.
   */
  Future debug() {
    log.info("Sending debug message");
    var c = new Completer<Results>();
    
    _getConnection()
      .then((cnx) {
        cnx.processHandler(new _DebugHandler())
          .then((x) {
            log.fine("Message sent");
            c.complete(x);
            _releaseConnection(cnx);
          })
          .catchError((e) {
            c.completeError(e);
            _releaseConnection(cnx);
            _reuseConnection(cnx);
          });
      })
      .catchError((e) {
        c.completeError(e);
      });
    
    return c.future;
  }
  
  void _closeQuery(Query q, bool retain) {
    log.finest("Closing query: ${q.sql}");
    for (var cnx in _pool) {
      var preparedQuery = cnx.removePreparedQueryFromCache(q.sql);
      if (preparedQuery != null) {
        _waitUntilReady(cnx).then((x) {
          log.finest("Connection ready - closing query: ${q.sql}");
          var handler = new _CloseStatementHandler(preparedQuery.statementHandlerId);
          cnx.processHandler(handler, noResponse: true)
            .then((x) {
              if (!retain) {
                _releaseConnection(cnx);
                _reuseConnection(cnx);
              }
            })
            .catchError((e) {
              if (!retain) {
                _releaseConnection(cnx);
                _reuseConnection(cnx);
              }
            });
        });
      }
    }
  }

  /**
   * The future returned by [whenReady] fires when all queued operations in the pool
   * have completed, and the connection is free to be used again.
   */
  Future<_Connection> _waitUntilReady(_Connection cnx) {
    var c = new Completer<_Connection>();
    if (!cnx.inUse) {
      cnx.use();
      c.complete(cnx);
    } else {
      _pendingConnections.add(c);
    }
    return c.future;
  }

  /**
   * Prepares a query with the given [sql]. Returns a [Future<Query>] that
   * completes when the query has been prepared.
   */
  Future<Query> prepare(String sql) {
    var query = new Query._internal(this, sql);
    var c = new Completer<Query>();
    query._prepare()
      .then((preparedQuery) {
        log.info("Got value count");
        _releaseConnection(preparedQuery.cnx);
        c.complete(query);
        _reuseConnection(preparedQuery.cnx);
      })
      .catchError((e) {
        c.completeError(e);
      });
    return c.future;
  }
  
  /**
   * Starts a transaction. Returns a [Future<Transaction>] that completes
   * when the transaction has been started. If [consistent] is true, the
   * transaction is started with consistent snapshot.
   */
  Future<Transaction> startTransaction({bool consistent: false}) {
    log.info("Starting transaction");
    var c = new Completer<Transaction>();
    
    _getConnection()
      .then((cnx) {
        var sql;
        if (consistent) {
          sql = "start transaction with consistent snapshot";
        } else {
          sql = "start transaction";
        }
        cnx.processHandler(new _QueryHandler(sql))
          .then((results) {
            log.fine("Transaction started on cnx#${cnx.number}");
            var transaction = new Transaction._internal(cnx, this);
            c.complete(transaction);
          })
          .catchError((e) {
            c.completeError(e);
            _releaseConnection(cnx);
            _reuseConnection(cnx);
          });
      })
      .catchError((e) {
        c.completeError(e);
      });
    
    return c.future;
  }
  
  /**
   * Prepares and executes the [sql] with the given list of [parameters].
   * Returns a [Future<Results>] that completes when the query has been
   * executed.
   */
  Future<Results> prepareExecute(String sql, List<dynamic> parameters) {
    var c = new Completer<Results>();
    prepare(sql)
      .then((q) {
        for (int i = 0; i < parameters.length; i++) {
          q[i] = parameters[i];
        }
        q.execute()
          .then((results) {
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

