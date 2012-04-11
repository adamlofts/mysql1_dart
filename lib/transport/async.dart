class AsyncTransport implements Transport {
  static final int HEADER_SIZE = 4;
  static final int STATE_PACKET_HEADER = 0;
  static final int STATE_PACKET_DATA = 1;
  Log log;

  Handler _handler;
  Completer<Dynamic> _completer;
  
  Socket _socket;

  Buffer _headerBuffer;
  Buffer _dataBuffer;
  
  int _packetNumber = 0;
  int _packetState = STATE_PACKET_HEADER;
  
  int _dataSize;
  int _readPos = 0;
  
  String _user;
  String _password;

  AsyncTransport._internal() {
    log = new Log("AsyncTransport");
    _headerBuffer = new Buffer(HEADER_SIZE);
  }
  
  void close() {
    _socket.close();
  }
  
  Future connect([String host='localhost', int port=3306, String user, String password, String db]) {
    if (_socket != null) {
      throw "connection already open";
    }
    
    _user = user;
    _password = password;
    _handler = new HandshakeHandler(user, password, db);
    
    _completer = new Completer();
    log.debug("opening connection to $host:$port/$db");
    _socket = new Socket(host, port);
    _socket.onClosed = () {
      log.debug("closed");
    };
    _socket.onConnect = () {
      log.debug("connected");
    };
    _socket.onData = _onData;
    _socket.onError = (Exception e) {
      log.debug("exception $e");
    };
    _socket.onWrite = () {
      log.debug("write");
    };
    return _completer.future;
  }
  
  void _sendBuffer(Buffer buffer) {
    _headerBuffer[0] = buffer.length & 0xFF;
    _headerBuffer[1] = (buffer.length & 0xFF00) << 8;
    _headerBuffer[2] = (buffer.length & 0xFF0000) << 16;
    _headerBuffer[3] = ++_packetNumber;
    log.debug("sending header, packet $_packetNumber");
    _headerBuffer.writeTo(_socket, HEADER_SIZE);
    buffer.reset();
    buffer.writeTo(_socket, buffer.length);
  }

  void _onData() {
    log.debug("got data");
    switch (_packetState) {
    case STATE_PACKET_HEADER:
      log.debug("reading header $_readPos");
      int bytes = _headerBuffer.readFrom(_socket, HEADER_SIZE - _readPos);
      _readPos += bytes;
      if (_readPos == HEADER_SIZE) {
        _packetState = STATE_PACKET_DATA;
        _dataSize = _headerBuffer[0] + (_headerBuffer[1] << 8) + (_headerBuffer[2] << 16);
        _packetNumber = _headerBuffer[3];
        _readPos = 0;
        log.debug("about to read $_dataSize bytes for packet ${_headerBuffer[3]}");
        _dataBuffer = new Buffer(_dataSize);
      }
      break;
    case STATE_PACKET_DATA:
      int bytes = _dataBuffer.readFrom(_socket, _dataSize - _readPos);
      log.debug("got $bytes bytes");
      _readPos += bytes;
      if (_readPos == _dataSize) {
        log.debug("read all data: ${_dataBuffer._list}");
        _packetState = STATE_PACKET_HEADER;
        _headerBuffer.reset();
        _readPos = 0;
        
        var result = _handler.processResponse(_dataBuffer);
        if (result is Handler) {
          _handler = result;
          _sendBuffer(_handler.createRequest());
        } else if (_handler.finished) {
          _handler = null;
          _completer.complete(result);
        }
      }
      break;
    }
  }
  
  Dynamic processHandler(Handler handler) {
    if (_handler != null) {
      throw "request already in progress";
    }
    _completer = new Completer<Dynamic>();
    _packetNumber = -1;
    _handler = handler;
    _sendBuffer(handler.createRequest());
    return _completer.future;
  }
}

