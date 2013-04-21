part of sqljocky;

typedef _ErrorHandler(AsyncError);
typedef _DoneHandler();
typedef _DataReadyHandler();

class _BufferedSocket {
  final Logger log;

  RawSocket _socket;
  _ErrorHandler onError;
  _DoneHandler onDone;
  _DataReadyHandler onDataReady;

  _BufferedSocket._internal(this._socket, this.onDataReady, this.onDone, this.onError)
      : log = new Logger("BufferedSocket") {
    _socket.listen(_onData, onError: (error) {
      if (onError != null) {
        onError(error);
      }
    }, onDone: () {
      if (onDone != null) {
        onDone();
      }
    }, cancelOnError: true);
  }

  static Future<_BufferedSocket> connect(String host, int port, {_DataReadyHandler onDataReady,
      _DoneHandler onDone, _ErrorHandler onError}) {
    var c = new Completer<_BufferedSocket>();
    RawSocket.connect(host, port).then((socket) {
      c.complete(new _BufferedSocket._internal(socket, onDataReady, onDone, onError));
    }, onError: onError);
    return c.future;
  }

  _onData(RawSocketEvent event) {
    if (event == RawSocketEvent.READ) {
      if (_readingBuffer == null) {
        if (onDataReady != null) {
          onDataReady();
        }
      } else {
        int bytesRead = _readingBuffer.readFromSocket(_socket, _readingBuffer.length - _readOffset);
        _readOffset += bytesRead;
        if (_readOffset == _readingBuffer.length) {
          var buffer = _readingBuffer;
          _readingBuffer = null;
          _readCompleter.complete(buffer);
        }
      }
    } else if (event == RawSocketEvent.READ_CLOSED) {

    } else if (event == RawSocketEvent.WRITE) {
      if (_writingBuffer != null) {
        _writeBuffer();
      }
    }
  }

  _Buffer _writingBuffer;
  int _writeOffset;
  Completer<_Buffer> _writeCompleter;

  /**
   * Writes [buffer] to the socket, and returns the same buffer in a [Future] which
   * completes when it has all been written.
   */
  Future<_Buffer> writeBuffer(_Buffer buffer) {
    if (_writingBuffer != null) {
      throw new MySqlClientError._("Cannot write to socket, already writing");
    }
    _writingBuffer = buffer;
    _writeCompleter = new Completer<_Buffer>();
    _writeOffset = 0;

    _writeBuffer();

    return _writeCompleter.future;
  }

  void _writeBuffer() {
    int bytesWritten = _writingBuffer.writeToSocket(_socket, _writeOffset, _writingBuffer.length - _writeOffset);
    log.fine("Wrote $bytesWritten bytes");
    _writeOffset += bytesWritten;
    if (_writeOffset == _writingBuffer.length) {
      var buffer = _writingBuffer;
      _writingBuffer = null;
      _writeCompleter.complete(buffer);
    }
  }

  _Buffer _readingBuffer;
  int _readOffset;
  Completer<_Buffer> _readCompleter;

  /**
   * Reads into [buffer] from the socket, and returns the same buffer in a [Future] which
   * completes when enough bytes have been read to fill the buffer. 
   */
  Future<_Buffer> readBuffer(_Buffer buffer) {
    if (_readingBuffer != null) {
      throw new MySqlClientError._("Cannot read from socket, already reading");
    }
    _readingBuffer = buffer;
    _readOffset = 0;
    _readCompleter = new Completer<_Buffer>();
    return _readCompleter.future;
  }

  close() {
    _socket.close();
  }
}