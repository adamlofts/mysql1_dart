library buffered_socket;

import 'dart:io';
import 'dart:async';
import 'package:logging/logging.dart';
import 'buffer.dart';

typedef ErrorHandler(AsyncError);
typedef DoneHandler();
typedef DataReadyHandler();

typedef Future<RawSocket> SocketFactory(host, int port);
typedef OnConnection(BufferedSocket);

class BufferedSocket {
  final Logger log;

  ErrorHandler onError;
  DoneHandler onDone;
  /**
   * When data arrives and there is no read currently in progress, the onDataReady handler is called.
   */
  DataReadyHandler onDataReady;

  RawSocket _socket;

  Buffer _writingBuffer;
  int _writeOffset;
  int _writeLength;
  Completer<Buffer> _writeCompleter;

  Buffer _readingBuffer;
  int _readOffset;
  Completer<Buffer> _readCompleter;
  StreamSubscription _subscription;
  bool _closed = false;

  BufferedSocket._(this._socket, this.onDataReady, this.onDone, this.onError)
      : log = new Logger("BufferedSocket") {
    _subscription = _socket.listen(_onData, onError: _onSocketError, 
        onDone: _onSocketDone, cancelOnError: true);
  }
  
  _onSocketError(error) {
    if (onError != null) {
      onError(error);
    }
  }
  
  _onSocketDone() {
    if (onDone != null) {
      onDone();
      _closed = true;
    }
  }
  
  /**
   * [socketFactory] is for unit testing.
   */
  static Future<BufferedSocket> connect(String host, int port,
      {DataReadyHandler onDataReady,
      DoneHandler onDone, 
      ErrorHandler onError, 
      SocketFactory socketFactory,
      OnConnection onConnection}) {
    var c = new Completer<BufferedSocket>();
    var future;
    if (socketFactory != null) {
      future = socketFactory(host, port);
    } else {
      future = RawSocket.connect(host, port);
    }
    future.then((socket) {
        var bufferedSocket = new BufferedSocket._(socket, onDataReady, onDone, onError);
        if (onConnection != null) {
          onConnection(bufferedSocket);
        }
        return c.complete(bufferedSocket);
      }, onError: onError);
    return c.future;
  }

  void _onData(RawSocketEvent event) {
    if (event == RawSocketEvent.READ) {
      log.fine("READ data");
      if (_readingBuffer == null) {
        log.fine("READ data: no buffer");
        if (onDataReady != null) {
          onDataReady();
        }
      } else {
        _readBuffer();
      }
    } else if (event == RawSocketEvent.READ_CLOSED) {
    } else if (event == RawSocketEvent.WRITE) {
      log.fine("WRITE data");
      if (_writingBuffer != null) {
        _writeBuffer();
      }
    }
  }

  /**
   * Writes [buffer] to the socket, and returns the same buffer in a [Future] which
   * completes when it has all been written.
   */
  Future<Buffer> writeBuffer(Buffer buffer) {
    return writeBufferPart(buffer, 0, buffer.length);
  }

  Future<Buffer> writeBufferPart(Buffer buffer, int start, int length) {
    log.fine("writeBuffer length=${buffer.length}");
    if (_closed) {
      throw new StateError("Cannot write to socket, it is closed");
    }
    if (_writingBuffer != null) {
      throw new StateError("Cannot write to socket, already writing");
    }
    _writingBuffer = buffer;
    _writeCompleter = new Completer<Buffer>();
    _writeOffset = start;
    _writeLength = length + start;

    _writeBuffer();

    return _writeCompleter.future;
  }

  void _writeBuffer() {
    log.fine("_writeBuffer offset=${_writeOffset}");
    int bytesWritten = _writingBuffer.writeToSocket(_socket, _writeOffset, _writeLength - _writeOffset);
    log.fine("Wrote $bytesWritten bytes");
    if (log.isLoggable(Level.FINE)) {
      log.fine("\n${Buffer.debugChars(_writingBuffer.list)}");
    }
    _writeOffset += bytesWritten;
    if (_writeOffset == _writeLength) {
      _writeCompleter.complete(_writingBuffer);
      _writingBuffer = null;
    } else {
      _socket.writeEventsEnabled = true;
    }
  }

  /**
   * Reads into [buffer] from the socket, and returns the same buffer in a [Future] which
   * completes when enough bytes have been read to fill the buffer.
   *  
   * This must not be called while there is still a read ongoing, but may be called before
   * onDataReady is called, in which case onDataReady will not be called when data arrives,
   * and the read will start instead.
   */
  Future<Buffer> readBuffer(Buffer buffer) {
    log.fine("readBuffer, length=${buffer.length}");
    if (_closed) {
      throw new StateError("Cannot read from socket, it is closed");
    }
    if (_readingBuffer != null) {
      throw new StateError("Cannot read from socket, already reading");
    }
    _readingBuffer = buffer;
    _readOffset = 0;
    _readCompleter = new Completer<Buffer>();

    if (_socket.available() > 0) {
      log.fine("readBuffer, data already ready");
      _readBuffer();
    }

    return _readCompleter.future;
  }

  void _readBuffer() {
    int bytesRead = _readingBuffer.readFromSocket(_socket, _readingBuffer.length - _readOffset);
    log.fine("read $bytesRead bytes");
    if (log.isLoggable(Level.FINE)) {
      log.fine("\n${Buffer.debugChars(_readingBuffer.list)}");
    }
    _readOffset += bytesRead;
    if (_readOffset == _readingBuffer.length) {
      _readCompleter.complete(_readingBuffer);
      _readingBuffer = null;
    }
  }

  void close() {
    _socket.close();
    _closed = true;
  }
  
  Future startSSL() {
    log.fine("Securing socket");
    return RawSecureSocket.secure(_socket, subscription: _subscription,
        onBadCertificate: (cert) => true).then((socket) {
      log.fine("Socket is secure");
      _socket = socket;
      _subscription = _socket.listen(_onData, onError: _onSocketError, 
          onDone: _onSocketDone, cancelOnError: true);
      _socket.writeEventsEnabled = true;
      _socket.readEventsEnabled = true;
    });
  }
}
