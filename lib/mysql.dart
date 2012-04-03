class MySqlConnection implements Connection {
  Map<String, Database> _dbs;
  String _host;
  String _user;
  String _password;
  int _port;
  Socket _socket;
  
  MySqlConnection([String host='localhost', String user, String password, int port=3306]) {
    _host = host;
    _user = user;
    _password = password;
    _port = port;
    _socket = new Socket(host, port);
  }
  
  Database openDatabase(String dbName) {
    if (_dbs.containsKey(dbName)) {
      return _dbs[dbName];
    }
    Database db = new MySqlDatabase._internal(this, dbName);
    _dbs[dbName] = db;
    return db;
  }
  
  void _dbClosed(String dbName) {
    _dbs.remove(dbName);
  }
  
  void close() {
    for (Database db in _dbs.getValues()) {
      db.close();
    }
    _socket.close();
  }
}

class MySqlDatabase implements Database {
  MySqlConnection _connection;
  String _dbName;
  
  MySqlDatabase._internal(MySqlConnection this._connection, String this._dbName) {
    
  }
  
  Results query(String sql) {
    
  }
  
  int update(String sql) {
    
  }
  
  void close() {
    _connection._dbClosed(_dbName);
  }
  
  Query prepare(String sql) {
    return new MySqlQuery._prepare(sql);
  }
}

class MySqlQuery implements Query {
  MySqlQuery._prepare(String sql) {
    
  }
  
  Results execute() {
    
  }
  
  int executeUpdate() {
    
  }
  
  operator [](int pos) {
    
  }
  
  void operator []=(int index, value) {
    
  }
}
