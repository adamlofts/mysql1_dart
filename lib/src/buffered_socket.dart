library buffered_socket;

import 'dart:io';
import 'dart:async';
import 'package:logging/logging.dart';
import 'buffer.dart';

typedef ErrorHandler(AsyncError);
typedef DoneHandler();
typedef DataReadyHandler();

class BufferedSocket {
  final Logger log;

  RawSocket _socket;
  ErrorHandler onError;
  DoneHandler onDone;
  DataReadyHandler onDataReady;

  BufferedSocket._internal(this._socket, this.onDataReady, this.onDone, this.onError)
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

  static Future<BufferedSocket> connect(String host, int port, {DataReadyHandler onDataReady,
      DoneHandler onDone, ErrorHandler onError}) {
    var c = new Completer<BufferedSocket>();
    RawSocket.connect(host, port).then((socket) {
      c.complete(new BufferedSocket._internal(socket, onDataReady, onDone, onError));
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

  Buffer _writingBuffer;
  int _writeOffset;
  Completer<Buffer> _writeCompleter;

  /**
   * Writes [buffer] to the socket, and returns the same buffer in a [Future] which
   * completes when it has all been written.
   */
  Future<Buffer> writeBuffer(Buffer buffer) {
    if (_writingBuffer != null) {
      throw new StateError("Cannot write to socket, already writing");
    }
    _writingBuffer = buffer;
    _writeCompleter = new Completer<Buffer>();
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

  Buffer _readingBuffer;
  int _readOffset;
  Completer<Buffer> _readCompleter;

  /**
   * Reads into [buffer] from the socket, and returns the same buffer in a [Future] which
   * completes when enough bytes have been read to fill the buffer. 
   */
  Future<Buffer> readBuffer(Buffer buffer) {
    if (_readingBuffer != null) {
      throw new StateError("Cannot read from socket, already reading");
    }
    _readingBuffer = buffer;
    _readOffset = 0;
    _readCompleter = new Completer<Buffer>();
    return _readCompleter.future;
  }

  close() {
    _socket.close();
  }
}