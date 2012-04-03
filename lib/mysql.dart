class MySqlConnection implements Connection {
  static final int HEADER_SIZE = 4;
  static final int STATE_PACKET_HEADER = 0;
  static final int STATE_PACKET_DATA = 1;
  
  Map<String, Database> _dbs;
  String _host;
  String _user;
  String _password;
  int _port;
  Socket _socket;

  List _headerBuffer;
  List _dataBuffer;
  
  int _dataSize;
  int _readPos = 0;
  
  int _state = STATE_PACKET_HEADER;
  
  MySqlConnection([String host='localhost', String user, String password, int port=3306]) {
    _host = host;
    _user = user;
    _password = password;
    _port = port;
    
    _headerBuffer = new List(HEADER_SIZE);
    
    _dbs = new Map<String, Database>();

    _openConnection();
  }
  
  void _openConnection() {
    print("opening connection to $_host:$_port");
    _socket = new Socket(_host, _port);
    _socket.onClosed = () {
      print("closed");
    };
    _socket.onConnect = () {
      print("connected");
    };
    _socket.onData = _onData;
    _socket.onError = (Exception e) {
      print("exception $e");
    };
    _socket.onWrite = () {
      print("write");
    };
  }
  
  void _onData() {
    print("got data");
    switch (_state) {
    case STATE_PACKET_HEADER:
      int bytes = _socket.readList(_headerBuffer, _readPos, HEADER_SIZE - _readPos);
      _readPos += bytes;
      if (_readPos == HEADER_SIZE) {
        _state = STATE_PACKET_DATA;
        _dataSize = _headerBuffer[0] + (_headerBuffer[1] << 8) + (_headerBuffer[2] << 16);
        _readPos = 0;
        print("about to read $_dataSize bytes for packet ${_headerBuffer[3]}");
        _dataBuffer = new List(_dataSize);
      }
      break;
    case STATE_PACKET_DATA:
      int bytes = _socket.readList(_dataBuffer, _readPos, _dataSize - _readPos);
      print("got $bytes bytes");
      _readPos += bytes;
      if (_readPos == _dataSize) {
        print("read all data");
        _state = STATE_PACKET_HEADER;
      }
      break;
    }
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
