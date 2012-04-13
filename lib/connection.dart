class MySqlConnection implements Connection {
  Transport _transport;
  List<MySqlQuery> _queries;
  
  Dynamic connect([String host='localhost', int port=3306, String user, String password, String db]) {
    return _transport.connect(host, port, user, password, db);
  }
  
  Dynamic useDatabase(String dbName) {
    var handler = new UseDbHandler(dbName);
    return _transport.processHandler(handler);
  }
  
  void close() {
    _transport.close();
  }

  Dynamic query(String sql) {
    var handler = new QueryHandler(sql);
    return _transport.processHandler(handler);
  }
  
  Dynamic update(String sql) {
    
  }
  
  abstract Dynamic prepare(String sql);
  
  Dynamic _closeQuery(MySqlQuery q) {
    int index = _queries.indexOf(q);
    if (index != -1) {
      _queries.removeRange(index, 1);
    }
    var handler = new CloseStatementHandler(q.statementId);
    return _transport.processHandler(handler);
  }
}

class AsyncMySqlConnection extends MySqlConnection implements AsyncConnection {
  AsyncMySqlConnection() {
    _transport = new AsyncTransport._internal();
    _queries = new List<MySqlQuery>();
  }
  
  Future<Query> prepare(String sql) {
    var handler = new PrepareHandler(sql);
    Future<PreparedQuery> future = _transport.processHandler(handler);
    Completer c = new Completer();
    future.then((preparedQuery) {
      MySqlQuery q = new AsyncMySqlQuery._internal(this, preparedQuery);
      _queries.add(q);
      c.complete(q);
    });
    return c.future;
  }
}

class SyncMySqlConnection extends MySqlConnection implements SyncConnection {
  SyncMySqlConnection() {
    _transport = new SyncTransport._internal();
    _queries = new List<MySqlQuery>();
  }

  Query prepare (String sql) {
    var handler = new PrepareHandler(sql);
    PreparedQuery preparedQuery = _transport.processHandler(handler);
    MySqlQuery q = new SyncMySqlQuery._internal(this, preparedQuery);
    _queries.add(q);
    return q;
  }
}

class MySqlQuery implements Query {
  MySqlConnection _cnx;
  PreparedQuery _preparedQuery;
  List<Dynamic> _values;
  bool _executed = false;

  int get statementId() => _preparedQuery.statementHandlerId;
  
  Dynamic close() {
    return _cnx._closeQuery(this);
  }
  
  Dynamic execute() {
    var handler = new ExecuteQueryHandler(_preparedQuery, _executed, _values);
    return _cnx._transport.processHandler(handler);
  }
  
  Dynamic executeUpdate() {
    
  }

  Dynamic operator [](int pos) {
    return _values[pos];
  }
  
  void operator []=(int index, Dynamic value) {
    _values[index] = value;
    _executed = false;
  }
}

class AsyncMySqlQuery extends MySqlQuery implements AsyncQuery {
  AsyncMySqlQuery._internal(MySqlConnection cnx, PreparedQuery preparedQuery) {
    _cnx = cnx;
    _preparedQuery = preparedQuery;
    _values = new List<Dynamic>(_preparedQuery.parameters.length);
  }
}

class SyncMySqlQuery extends MySqlQuery implements AsyncQuery {
  SyncMySqlQuery._internal(MySqlConnection cnx, PreparedQuery preparedQuery) {
    _cnx = cnx;
    _preparedQuery = preparedQuery;
    _values = new List<Dynamic>(_preparedQuery.parameters.length);
  }
}
