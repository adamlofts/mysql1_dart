part of sqljocky;

class _Connection {
  static const int HEADER_SIZE = 4;
  static const int STATE_PACKET_HEADER = 0;
  static const int STATE_PACKET_DATA = 1;
  final Logger log;
  final Logger lifecycleLog;

  ConnectionPool _pool;
  _Handler _handler;
  Completer<dynamic> _completer;
  
  BufferedSocket _socket;

  final Buffer _headerBuffer;
  Buffer _dataBuffer;
  bool _readyForHeader = true;
  
  int _packetNumber = 0;

  int _dataSize;

  String _user;
  String _password;
  final int number;
  
  bool _inUse;
  final Map<String, _PreparedQuery> _preparedQueryCache;

  _Connection(this._pool, this.number) :
      log = new Logger("Connection"),
      lifecycleLog = new Logger("Connection.Lifecycle"),
      _headerBuffer = new Buffer(HEADER_SIZE),
      _preparedQueryCache = new Map<String, _PreparedQuery>(),
      _inUse = false;
  
  void close() {
    if (_socket != null) {
      _socket.close();
    }
  }
  
  bool get inUse => _inUse;
  
  void use() {
    lifecycleLog.finest("Use connection #$number");
    _inUse = true;
  }
  
  void release() {
    _inUse = false;
    lifecycleLog.finest("Release connection #$number");
  }
  
  /**
   * Connects to the given [host] on [port], authenticates using [user]
   * and [password] and connects to [db]. Returns a future which completes
   * when this has happened. The future's value is an OkPacket if the connection
   * is succesful.
   */
  Future connect({String host, int port, String user, 
      String password, String db}) {
    if (_socket != null) {
      throw new MySqlClientError._("Cannot connect to server while a connection is already open");
    }
    
    _user = user;
    _password = password;
    _handler = new _HandshakeHandler(user, password, db);
    
    _completer = new Completer();
    log.fine("opening connection to $host:$port/$db");
    BufferedSocket.connect(host, port,
      onDataReady: _readPacket,
      onDone: () {
        release();
        log.fine("done");
      },      
      onError: (error) {
        log.fine("error $error");
        release();
        _completer.completeError(error);
      }).then((socket) {
      _socket = socket;
    });
    return _completer.future;
  }

  void _readPacket() {
    log.fine("readPacket readyForHeader=${_readyForHeader}");
    if (_readyForHeader) {
      _readyForHeader = false;
      _socket.readBuffer(_headerBuffer).then(_handleHeader);      
    }
  }
  
  void _handleHeader(buffer) {
    _dataSize = buffer[0] + (buffer[1] << 8) + (buffer[2] << 16);
    _packetNumber = buffer[3];
    log.fine("about to read $_dataSize bytes for packet ${_packetNumber}");
    _dataBuffer = new Buffer(_dataSize);
    log.fine("buffer size=${_dataBuffer.length}");
    _socket.readBuffer(_dataBuffer).then(_handleData);
  }
  
  void _handleData(buffer) {
    _readyForHeader = true;
    //log.fine("read all data: ${_dataBuffer._list}");
    //log.fine("read all data: ${Buffer.listChars(_dataBuffer._list)}");
    _headerBuffer.reset();

    try {
      var response = _handler.processResponse(buffer);
      if (response.nextHandler != null) {
        // if handler.processResponse() returned a Handler, pass control to that handler now
        _handler = response.nextHandler;
        _sendBuffer(_handler.createRequest());
      }
      if (response.finished) {
        _handler = null;
      }
      if (response.hasResult) {
        if (_completer.isCompleted) {
          _completer.completeError(new StateError("Request has already completed"));
        }
        _completer.complete(response.result);
      }
    } catch (e) {
      _handler = null;
      log.fine("completing with exception: $e");
      _completer.completeError(e);
    }
  }
  
  void _sendBuffer(Buffer buffer) {
    log.fine("sendBuffer header");
    _headerBuffer[0] = buffer.length & 0xFF;
    _headerBuffer[1] = (buffer.length & 0xFF00) >> 8;
    _headerBuffer[2] = (buffer.length & 0xFF0000) >> 16;
    _headerBuffer[3] = ++_packetNumber;
    log.fine("sending header, packet $_packetNumber");
    _socket.writeBuffer(_headerBuffer).then((_) {
      log.fine("sendBuffer body, buffer length=${buffer.length}");
      _socket.writeBuffer(buffer);
    });
  }

  /**
   * Processes a handler, from sending the initial request to handling any packets returned from
   * mysql (unless [noResponse] is true).
   *
   * Returns a future
   */
  Future<dynamic> processHandler(_Handler handler, {bool noResponse:false}) {
    if (_handler != null) {
      throw new MySqlClientError._("Cannot process a request for $handler while a request is already in progress for $_handler");
    }
    _packetNumber = -1;
    _completer = new Completer<dynamic>();
    if (!noResponse) {
      _handler = handler;
    }
    _sendBuffer(handler.createRequest());
    return _completer.future;
  }
  
  _PreparedQuery removePreparedQueryFromCache(String sql) {
    var preparedQuery = null;
    if (_preparedQueryCache.containsKey(sql)) {
      preparedQuery = _preparedQueryCache[sql];
      _preparedQueryCache.remove(sql);
    }
    return preparedQuery;
  }
  
  _PreparedQuery getPreparedQueryFromCache(String sql) {
    return _preparedQueryCache[sql];
  }
  
  putPreparedQueryInCache(String sql, _PreparedQuery preparedQuery) {
    _preparedQueryCache[sql] = preparedQuery;
  }
}
