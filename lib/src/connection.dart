part of sqljocky;

class _Connection {
  static const int HEADER_SIZE = 4;
  static const int COMPRESSED_HEADER_SIZE = 7;
  static const int STATE_PACKET_HEADER = 0;
  static const int STATE_PACKET_DATA = 1;
  final Logger log;
  final Logger lifecycleLog;

  ConnectionPool _pool;
  _Handler _handler;
  Completer<dynamic> _completer;

  // this is for unit testing, so we can replace this method with a spy
  var _dataHandler;
  
  BufferedSocket _socket;
  var _largePacketBuffers = new List<Buffer>();

  final Buffer _headerBuffer;
  final Buffer _compressedHeaderBuffer;
  Buffer _dataBuffer;
  bool _readyForHeader = true;
  
  int _packetNumber = 0;
  
  int _compressedPacketNumber = 0;
  bool _useCompression = false;
  bool _useSSL = false;
  bool _secure = false;
  int _maxPacketSize;

  int _dataSize;

  String _user;
  String _password;
  final int number;
  
  bool _inUse;
  bool autoRelease;
  bool inTransaction = false;
  final Map<String, _PreparedQuery> _preparedQueryCache;

  _Connection(this._pool, this.number, this._maxPacketSize) :
      log = new Logger("Connection"),
      lifecycleLog = new Logger("Connection.Lifecycle"),
      _headerBuffer = new Buffer(HEADER_SIZE),
      _compressedHeaderBuffer = new Buffer(COMPRESSED_HEADER_SIZE),
      _preparedQueryCache = new Map<String, _PreparedQuery>(),
      _inUse = false {
    _dataHandler = this._handleData;
  }
  
  void close() {
    if (_socket != null) {
      _socket.close();
    }
  }
  
  bool get inUse => _inUse;
  
  void use() {
    lifecycleLog.finest("Use connection #$number");
    _inUse = true;
    autoRelease = true;
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
      String password, String db, bool useCompression, bool useSSL}) {
    if (_socket != null) {
      throw new MySqlClientError._("Cannot connect to server while a connection is already open");
    }
    
    _user = user;
    _password = password;
    _handler = new _HandshakeHandler(user, password, _maxPacketSize, db, useCompression, useSSL);

    _completer = new Completer();
    log.fine("opening connection to $host:$port/$db");
    BufferedSocket.connect(host, port,
      onConnection: (socket) {
        _socket = socket;
      },
      onDataReady: _readPacket,
      onDone: () {
        release();
        log.fine("done");
      },      
      onError: (error) {
        log.fine("error $error");
        release();
        if (_completer.isCompleted) {
          throw error;
        } else {
          _completer.completeError(error);
        }
      });
    //TODO Only useDatabase if connection actually ended up as an SSL connection?
    //TODO On the other hand, it doesn't hurt to call useDatabase anyway.
    if (useSSL) {
      return _completer.future
      .then((_) {
        return _useDatabase(db);
      });
    } else {
      return _completer.future;
    }
  }
  
  Future _useDatabase(String dbName) {
    var handler = new _UseDbHandler(dbName);
    return processHandler(handler);
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
    if (_dataSize == 0xffffff || _largePacketBuffers.length > 0) {
      _socket.readBuffer(_dataBuffer).then(_handleMoreData);
    } else {
      _socket.readBuffer(_dataBuffer).then(_dataHandler);
    }
  }

  void _handleMoreData(buffer) {
    _largePacketBuffers.add(buffer);
    if (buffer.length < 0xffffff) {
      var length = _largePacketBuffers.fold(0, (length, buf) {
        return length + buf.length;
      });
      var combinedBuffer = new Buffer(length);
      var start = 0;
      _largePacketBuffers.forEach((aBuffer) {
        combinedBuffer.list.setRange(start, start + aBuffer.length, aBuffer.list);
        start += aBuffer.length;
      });
      _largePacketBuffers.clear();
      _dataHandler(combinedBuffer);
    } else {
      _readyForHeader = true;
      _headerBuffer.reset();
      _readPacket();
    }
  }
  
  void _handleData(buffer) {
    _readyForHeader = true;
    //log.fine("read all data: ${_dataBuffer._list}");
    //log.fine("read all data: ${Buffer.listChars(_dataBuffer._list)}");
    _headerBuffer.reset();

    try {
      var response = _handler.processResponse(buffer);
      if (_handler is _HandshakeHandler) {
        _useCompression = (_handler as _HandshakeHandler).useCompression;
        _useSSL = (_handler as _HandshakeHandler).useSSL;
      }
      if (response.nextHandler != null) {
        // if handler.processResponse() returned a Handler, pass control to that handler now
        _handler = response.nextHandler;
        _sendBuffer(_handler.createRequest()).then((_) {
          if (_useSSL && _handler is _SSLHandler) {
            log.fine("Use SSL");
            _socket.startSSL().then((_) {
              _secure = true;
              _handler = (_handler as _SSLHandler).nextHandler;
              _sendBuffer(_handler.createRequest()).then((_) {
                log.fine("Sent buffer");
              });
            });
            return;
          }
        });
      }
      if (response.finished) {
        _finishAndReuse();
      }
      if (response.hasResult) {
        if (_completer.isCompleted) {
          _completer.completeError(new StateError("Request has already completed"));
        }
        _completer.complete(response.result);
      }
    } catch (e) {
      autoRelease = true;
      _finishAndReuse();
      log.fine("completing with exception: $e");
      _completer.completeError(e);
    }
  }
  
  void _finishAndReuse() {
    if (autoRelease && !inTransaction) { 
      log.finest("Response finished for #$number, setting handler to null and waiting to release and reuse");
      new Future.delayed(new Duration(seconds: 0), () {
        if (_inUse) {
          log.finest("Releasing and reusing connection #$number");
          _inUse = false;
          _handler = null;
          _pool._newReuseConnection(this);
        }
      });
    } else {
      log.finest("Response finished for #$number. Not auto-releasing");
      _handler = null;
    }
  }
  
  Future _sendBuffer(Buffer buffer) {
    if (buffer.length > _maxPacketSize) {
      throw new MySqlClientError._("Buffer length (${buffer.length}) bigger than maxPacketSize ($_maxPacketSize)");
    }
    if (_useCompression) {
      _headerBuffer[0] = buffer.length & 0xFF;
      _headerBuffer[1] = (buffer.length & 0xFF00) >> 8;
      _headerBuffer[2] = (buffer.length & 0xFF0000) >> 16;
      _headerBuffer[3] = ++_packetNumber;
      var encodedHeader = ZLIB.encode(_headerBuffer.list);
      var encodedBuffer = ZLIB.encode(buffer.list);
      _compressedHeaderBuffer.writeUint24(encodedHeader.length + encodedBuffer.length);
      _compressedHeaderBuffer.writeByte(++_compressedPacketNumber);
      _compressedHeaderBuffer.writeUint24(4 + buffer.length);
      _socket.writeBuffer(_compressedHeaderBuffer);
    } else {
      log.fine("sendBuffer header");
      return _sendBufferPart(buffer, 0);
    }
  }

  Future<Buffer> _sendBufferPart(Buffer buffer, int start) {
    var len = math.min(buffer.length - start, 0xFFFFFF);

    _headerBuffer[0] = len & 0xFF;
    _headerBuffer[1] = (len & 0xFF00) >> 8;
    _headerBuffer[2] = (len & 0xFF0000) >> 16;
    _headerBuffer[3] = ++_packetNumber;
    log.fine("sending header, packet $_packetNumber");
    return _socket.writeBuffer(_headerBuffer).then((_) {
      log.fine("sendBuffer body, buffer length=${buffer.length}, start=$start, len=$len");
      return _socket.writeBufferPart(buffer, start, len);
    }).then((_) {
      if (len == 0xFFFFFF) {
        return _sendBufferPart(buffer, start + len);
      } else {
        return buffer;
      }
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
      throw new MySqlClientError._("Connection #$number cannot process a request for $handler while a request is already in progress for $_handler");
    }
    _packetNumber = -1;
    _compressedPacketNumber = -1;
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
  
  bool get usingSSL => _secure; 
}
