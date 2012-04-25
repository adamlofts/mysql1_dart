class MySqlConnection implements Connection {
  final Transport _transport;
  final List<MySqlQuery> _queries;

  MySqlConnection() : _transport = new Transport(),
                      _queries = <MySqlQuery>[];

  Future connect([String host='localhost', int port=3306, String user, String password, String db]) {
    return _transport.connect(host, port, user, password, db);
  }
  
  Future useDatabase(String dbName) {
    var handler = new UseDbHandler(dbName);
    return _transport.processHandler(handler);
  }
  
  void close() {
    var handler = new QuitHandler();
    _transport.processHandler(handler, noResponse:true);
    _transport.close();
  }

  Future<Results> query(String sql) {
    var handler = new QueryHandler(sql);
    return _transport.processHandler(handler);
  }
  
  Future<int> update(String sql) {
  }
  
  Future ping() {
    var handler = new PingHandler();
    return _transport.processHandler(handler);
  }
  
  Future debug() {
    var handler = new DebugHandler();
    return _transport.processHandler(handler);
  }
  
  void _closeQuery(MySqlQuery q) {
    int index = _queries.indexOf(q);
    if (index != -1) {
      _queries.removeRange(index, 1);
    }
    var handler = new CloseStatementHandler(q.statementId);
    _transport.processHandler(handler, noResponse:true);
  }
  
  Future<Query> prepare(String sql) {
    var handler = new PrepareHandler(sql);
    Future<PreparedQuery> future = _transport.processHandler(handler);
    Completer<Query> c = new Completer<Query>();
    future.then((preparedQuery) {
      MySqlQuery q = new MySqlQuery._internal(this, preparedQuery);
      _queries.add(q);
      c.complete(q);
    });
    return c.future;
  }
  
  Future<Results> prepareExecute(String sql, List<Dynamic> parameters) {
    Completer<Results> completer = new Completer<Results>();
    Future<Query> future = prepare(sql);
    future.then((Query q) {
      for (int i = 0; i < parameters.length; i++) {
        q[i] = parameters[i];
      }
      q.execute().then((Results results) {
        completer.complete(results);
      });
    });
    return completer.future;
  }
}

class MySqlQuery implements Query {
  final MySqlConnection _cnx;
  final PreparedQuery _preparedQuery;
  final List<Dynamic> _values;
  bool _executed = false;

  int get statementId() => _preparedQuery.statementHandlerId;
  
  MySqlQuery._internal(MySqlConnection cnx, PreparedQuery preparedQuery) :
      _cnx = cnx,
      _preparedQuery = preparedQuery,
      _values = new List<Dynamic>(preparedQuery.parameters.length);

  void close() {
    _cnx._closeQuery(this);
  }
  
  Future<Results> execute() {
    var handler = new ExecuteQueryHandler(_preparedQuery, _executed, _values);
    return _cnx._transport.processHandler(handler);
  }
  
  Future<List<Results>> executeMulti(List<List<Dynamic>> parameters) {
    Completer<List<Results>> completer = new Completer<List<Results>>();
    List<Results> resultList = new List<Results>();
    exec(int i) {
      _values.setRange(0, _values.length, parameters[i]);
      execute().then((Results results) {
        resultList.add(results);
        if (i < parameters.length - 1) {
          exec(i + 1);
        } else {
          completer.complete(resultList);
        }
      });
    }
    exec(0);
    return completer.future;
  } 
  
  Future<int> executeUpdate() {
    
  }

  Dynamic operator [](int pos) => _values[pos];
  
  void operator []=(int index, Dynamic value) {
    _values[index] = value;
    _executed = false;
  }
}
