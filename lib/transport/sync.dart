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
  
  Future connect([String host, int port, String user, String password, String db]) {
    _socket = new Socket(host, port);
    Completer completer = new Completer();
    _socket.onConnect = () {
      log.debug("connected");
      _inputStream = _socket.inputStream;
      _outputStream = _socket.outputStream;
      
      HandshakeHandler handler = new HandshakeHandler(user, password, db);

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

