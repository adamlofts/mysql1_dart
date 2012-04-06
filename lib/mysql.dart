class OkPacket {
  int affectedRows;
  int insertId;
  int serverStatus;
  String message;
  
  OkPacket(Buffer buffer) {
    buffer.seek(1);
    affectedRows = buffer.readLengthCodedBinary();
    insertId = buffer.readLengthCodedBinary();
    serverStatus = buffer.readInt16();
    message = buffer.readStringToEnd();
  }
  
  void show() {
    print("OK PACKET");
    print("affected rows $affectedRows");
    print("insert id $insertId");
    print("server status $serverStatus");
    print("message $message");
  }
}

class ErrorPacket {
  int errorNumber;
  String sqlState;
  String message;
  
  ErrorPacket(Buffer buffer) {
    buffer.seek(1);
    errorNumber = buffer.readInt16();
    buffer.skip(1);
    sqlState = buffer.readString(5);
    message = buffer.readStringToEnd();
  }
  
  void show() {
    print("ERROR PACKET");
    print("error number $errorNumber");
    print("sqlState $sqlState");
    print("message $message");
  }
  
  String toString() {
    return "Error $errorNumber ($sqlState): $message";
  }
}


class MySqlConnection implements Connection {
  static final int HEADER_SIZE = 4;
  static final int STATE_PACKET_HEADER = 0;
  static final int STATE_PACKET_DATA = 1;
  
  Transport _transport;
  
  MySqlConnection.async() {
    _transport = new AsyncTransport._internal();
  }
  
  MySqlConnection.sync() {
    _transport = new SyncTransport._internal();
  }
  
  Dynamic connect([String host='localhost', int port=3306, String user, String password]) {
    return _transport.connect(host, port, user, password);
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
  
  Future<int> update(String sql) {
    
  }
  
  Query prepare(String sql) {
    return new MySqlQuery._prepare(sql);
  }
}

class MySqlQuery implements Query {
  MySqlQuery._prepare(String sql) {
    
  }
  
  Future<Results> execute() {
    
  }
  
  Future<int> executeUpdate() {
    
  }
  
  operator [](int pos) {
    
  }
  
  void operator []=(int index, value) {
    
  }
}
