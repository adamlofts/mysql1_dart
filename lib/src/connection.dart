part of sqljocky;

typedef void Callback();

class _Connection {
  static const int HEADER_SIZE = 4;
  static const int STATE_PACKET_HEADER = 0;
  static const int STATE_PACKET_DATA = 1;
  final Logger log;
  final Logger lifecycleLog;

  ConnectionPool _pool;
  Handler _handler;
  Completer<dynamic> _completer;
  
  BufferedSocket _socket;

  final Buffer _headerBuffer;
  Buffer _dataBuffer;
  
  int _packetNumber = 0;

  int _dataSize;

  String _user;
  String _password;
  final int number;
  
  bool _inUse;
  final Map<String, PreparedQuery> _preparedQueryCache;

  _Connection(this._pool, this.number) :
      log = new Logger("Connection"),
      lifecycleLog = new Logger("Connection.Lifecycle"),
      _headerBuffer = new Buffer(HEADER_SIZE),
      _preparedQueryCache = new Map<String, PreparedQuery>(),
      _inUse = false;
  
  void close() {
    _socket.close();
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
  
  Future connect({String host, int port, String user, 
      String password, String db}) {
    if (_socket != null) {
      throw "connection already open";
    }
    
    _user = user;
    _password = password;
    _handler = new HandshakeHandler(user, password, db);
    
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
    _socket.readBuffer(_headerBuffer).then((x) {
      _dataSize = _headerBuffer[0] + (_headerBuffer[1] << 8) + (_headerBuffer[2] << 16);
      _packetNumber = _headerBuffer[3];
      log.fine("about to read $_dataSize bytes for packet ${_packetNumber}");
      _dataBuffer = new Buffer(_dataSize);
      _socket.readBuffer(_dataBuffer).then((xx) {
        //log.fine("read all data: ${_dataBuffer._list}");
        //log.fine("read all data: ${Buffer.listChars(_dataBuffer._list)}");
        _headerBuffer.reset();

        try {
          var result = _handler.processResponse(_dataBuffer);
          if (result is Handler) {
            // if handler.processResponse() returned a Handler, pass control to that handler now
            _handler = result;
            _sendBuffer(_handler.createRequest());
          } else if (_handler.finished) {
            // otherwise, complete using the result, and that result will be  passed back to the future.
            _handler = null;
            _completer.complete(result);
          }
        } catch (e) {
          _handler = null;
          log.fine("completing with exception: $e");
          _completer.completeError(e);
        }
      });
    });
  }
  
  void _sendBuffer(Buffer buffer) {
    _headerBuffer[0] = buffer.length & 0xFF;
    _headerBuffer[1] = (buffer.length & 0xFF00) >> 8;
    _headerBuffer[2] = (buffer.length & 0xFF0000) >> 16;
    _headerBuffer[3] = ++_packetNumber;
    log.fine("sending header, packet $_packetNumber");
    _socket.writeBuffer(_headerBuffer).then((x) {
      _socket.writeBuffer(buffer);
    });
  }

  /**
   * Processes a handler, from sending the initial request to handling any packets returned from
   * mysql (unless [noResponse] is true).
   *
   * Returns a future
   */
  Future<dynamic> processHandler(Handler handler, {bool noResponse:false}) {
    if (_handler != null) {
      throw "request already in progress";
    }
    _packetNumber = -1;
    _completer = new Completer<dynamic>();
    if (!noResponse) {
      _handler = handler;
    }
    _sendBuffer(handler.createRequest());
    return _completer.future;
  }
  
  PreparedQuery removePreparedQueryFromCache(String sql) {
    var preparedQuery = null;
    if (_preparedQueryCache.containsKey(sql)) {
      preparedQuery = _preparedQueryCache[sql];
      _preparedQueryCache.remove(sql);
    }
    return preparedQuery;
  }
  
  PreparedQuery getPreparedQueryFromCache(String sql) {
    return _preparedQueryCache[sql];
  }
  
  putPreparedQueryInCache(String sql, PreparedQuery preparedQuery) {
    _preparedQueryCache[sql] = preparedQuery;
  }
}

