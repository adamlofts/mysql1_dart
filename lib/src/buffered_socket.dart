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
    });
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
          _readingBuffer = null;
          _readCompleter.complete(null);
        }
      }
    } else if (event == RawSocketEvent.READ_CLOSED) {

    } else if (event == RawSocketEvent.WRITE) {
      if (_writingBuffer != null) {
        _writeBuffer();
      }
    }
  }

  Buffer _writingBuffer;
  int _writeOffset;
  Completer _writeCompleter;

  Future writeBuffer(Buffer buffer) {
    if (_writingBuffer != null) {
      throw "Already writing";
    }
    _writingBuffer = buffer;
    _writeCompleter = new Completer();
    _writeOffset = 0;

    _writeBuffer();

    return _writeCompleter.future;
  }

  void _writeBuffer() {
    int bytesWritten = _writingBuffer.writeToSocket(_socket, _writeOffset, _writingBuffer.length - _writeOffset);
    log.fine("Wrote $bytesWritten bytes");
    _writeOffset += bytesWritten;
    if (_writeOffset == _writingBuffer.length) {
      _writingBuffer = null;
      _writeCompleter.complete(null);
    }
  }

  Buffer _readingBuffer;
  int _readOffset;
  Completer _readCompleter;

  Future readBuffer(Buffer buffer) {
    if (_readingBuffer != null) {
      throw "Already reading";
    }
    _readingBuffer = buffer;
    _readOffset = 0;
    _readCompleter = new Completer();
    return _readCompleter.future;
  }

  close() {
    _socket.close();
  }
}