class MySqlConnection implements Connection {
  static final int HEADER_SIZE = 4;
  static final int STATE_PACKET_HEADER = 0;
  static final int STATE_PACKET_DATA = 1;
  
  String _host;
  String _user;
  String _password;
  int _port;
  Socket _socket;

  Buffer _headerBuffer;
  Buffer _dataBuffer;
  
  int _packetNumber = 0;
  int _packetState = STATE_PACKET_HEADER;
  
  int _dataSize;
  int _readPos = 0;
  
  Handler handler;
  
  bool connected = false;
  
  MySqlConnection([String host='localhost', String user, String password, int port=3306]) {
    _host = host;
    _user = user;
    _password = password;
    _port = port;
    
    _headerBuffer = new Buffer(HEADER_SIZE);
    handler = new HandshakeHandler();
  }
  
  Completer _completer;
  
  Future connect() {
    _completer = new Completer();
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
    return _completer.future;
  }
  
  void _onData() {
    print("got data");
    switch (_packetState) {
    case STATE_PACKET_HEADER:
      print("reading header $_readPos");
      int bytes = _headerBuffer.readFrom(_socket, HEADER_SIZE - _readPos);
      _readPos += bytes;
      if (_readPos == HEADER_SIZE) {
        _packetState = STATE_PACKET_DATA;
        _dataSize = _headerBuffer[0] + (_headerBuffer[1] << 8) + (_headerBuffer[2] << 16);
        _packetNumber = _headerBuffer[3];
        _readPos = 0;
        print("about to read $_dataSize bytes for packet ${_headerBuffer[3]}");
        _dataBuffer = new Buffer(_dataSize);
      }
      break;
    case STATE_PACKET_DATA:
      int bytes = _dataBuffer.readFrom(_socket, _dataSize - _readPos);
      print("got $bytes bytes");
      _readPos += bytes;
      if (_readPos == _dataSize) {
        print("read all data");
        _packetState = STATE_PACKET_HEADER;
        _headerBuffer.reset();
        _readPos = 0;
        
        print(_dataBuffer._list);
        if (handler is HandshakeHandler) {
          handler.processResponse(_dataBuffer);
          if ((handler.serverCapabilities & CLIENT_PROTOCOL_41) == 0) {
            throw "Unsupported protocol (must be 4.1 or newer";
          }
          
          int clientFlags = CLIENT_PROTOCOL_41 | CLIENT_LONG_PASSWORD
            | CLIENT_LONG_FLAG | CLIENT_TRANSACTIONS | CLIENT_SECURE_CONNECTION;
          List scrambleBuffer = new List();
          
          handler = new AuthHandler(_user, _password, scrambleBuffer, 
            clientFlags, 0, 33);
          _sendBuffer(handler.createRequest());
        } else if (_dataBuffer[0] == 0) {
          OkPacket okPacket = new OkPacket(_dataBuffer);
          okPacket.show();
          if (!connected) {
            connected = true;
          }
          Handler theHandler = handler;
          handler = null;
          _completer.complete(theHandler.processResponse(_dataBuffer));
        } else if (_dataBuffer[0] == 0xFF) {
          ErrorPacket errorPacket = new ErrorPacket(_dataBuffer);
          throw errorPacket;
        }
      }
      break;
    }
  }
  
  void _sendBuffer(Buffer buffer) {
    _headerBuffer[0] = buffer.length & 0xFF;
    _headerBuffer[1] = (buffer.length & 0xFF00) << 8;
    _headerBuffer[2] = (buffer.length & 0xFF0000) << 16;
    _headerBuffer[3] = ++_packetNumber;
    _headerBuffer.writeTo(_socket, HEADER_SIZE);
    buffer.reset();
    buffer.writeTo(_socket, buffer.length);
  }
  
  Future useDatabase(String dbName) {
    if (handler != null) {
      throw "request already in progress";
    }
    _completer = new Completer();
    _packetNumber = -1;
    handler = new UseDbHandler(dbName);
    _sendBuffer(handler.createRequest());
    return _completer.future;
  }
  
  void close() {
    _socket.close();
  }

  Future<Results> query(String sql) {
    if (handler != null) {
      throw "request already in progress";
    }
    _completer = new Completer<Results>();
    _packetNumber = -1;
    handler = new QueryHandler(sql);
    _sendBuffer(handler.createRequest());
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
