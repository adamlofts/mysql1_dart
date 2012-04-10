interface Transport {
  Dynamic connect([String host, int port, String user, String password]);
  Dynamic processHandler(Handler handler);
  void close();
}

class AsyncTransport implements Transport {
  static final int HEADER_SIZE = 4;
  static final int STATE_PACKET_HEADER = 0;
  static final int STATE_PACKET_DATA = 1;
  static Log log;

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
  
  Future connect([String host='localhost', int port=3306, String user, String password]) {
    if (_socket != null) {
      throw "connection already open";
    }
    
    _user = user;
    _password = password;
    _handler = new HandshakeHandler(user, password);
    
    _completer = new Completer();
    log.debug("opening connection to $host:$port");
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

class SyncTransport implements Transport {
  static final int HEADER_SIZE = 4;

  Log log;
  Socket _socket;
  InputStream _inputStream;
  OutputStream _outputStream;
  
  int _packetNumber = 0;
  
  List<int> _headerBuffer;
  
  SyncTransport._internal() {
    log = new Log("SyncTransport");
    _headerBuffer = new List<int>(HEADER_SIZE);
  }
  
  Future connect([String host, int port, String user, String password]) {
    _socket = new Socket(host, port);
    Completer completer = new Completer();
    _socket.onConnect = () {
      log.debug("connected");
      _inputStream = _socket.inputStream;
      _outputStream = _socket.outputStream;
      
      HandshakeHandler handler = new HandshakeHandler(user, password);

      var result = handler.processResponse(new Buffer.fromList(readPacket()));
      if (result is Handler) {
        processHandler(result, false);
      }

      completer.complete(null);
    };
    return completer.future;
  }
  
  List<int> blockingRead(int bytes, [List<int> list]) {
    if (list == null) {
      list = new List<int>(bytes);      
    }
    
    int read = 0;
    while (read < bytes) {
      int bytesRead = _inputStream.readInto(list, read, bytes - read);
      if (bytesRead != null) {
        read += bytesRead;
      }
    }
    
    return list;
  }
  
  List<int> readPacket() {
    blockingRead(HEADER_SIZE, _headerBuffer);
    
    int dataSize = _headerBuffer[0] + (_headerBuffer[1] << 8) + (_headerBuffer[2] << 16);
    int packetNumber = _headerBuffer[3];
    
    List<int> packet = blockingRead(dataSize);
    return packet;
  }
  
  void sendPacket(List<int> list) {
    _headerBuffer[0] = list.length & 0xFF;
    _headerBuffer[1] = (list.length & 0xFF00) << 8;
    _headerBuffer[2] = (list.length & 0xFF0000) << 16;
    _headerBuffer[3] = ++_packetNumber;
    log.debug("sending header, packet $_packetNumber");
    _outputStream.write(_headerBuffer);
    log.debug("sending packet");
    _outputStream.write(list);
  }

  void close() {
    _socket.close();
  }
  
  Dynamic processHandler(Handler handler, [bool resetPacket=true]) {
    log.debug(handler.toString());
    if (resetPacket) {
      _packetNumber = -1;
    }
    sendPacket(handler.createRequest()._list);
    
    var result;
    do {
      Buffer buffer = new Buffer.fromList(readPacket());
      result = handler.processResponse(buffer);
      log.debug("got result $result");
      if (result is Handler) {
        log.debug("result is handler");
        result = processHandler(handler);
      }
    } while (!handler.finished);
    log.debug("handler finished");
    return result;
  }
}

