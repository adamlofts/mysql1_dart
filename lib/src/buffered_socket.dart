library buffered_socket;

import 'dart:io';
import 'dart:async';
import 'package:logging/logging.dart';
import 'buffer.dart';

typedef ErrorHandler = Function(Object err);
typedef DoneHandler = Function();
typedef DataReadyHandler = Function();
typedef ClosedHandler = Function();

typedef SocketFactory = Function(String host, int port, Duration timeout,
    {bool isUnixSocket});

class BufferedSocket {
  final Logger log;

  ErrorHandler? onError;
  DoneHandler? onDone;
  ClosedHandler? onClosed;

  /// When data arrives and there is no read currently in progress, the onDataReady handler is called.
  DataReadyHandler? onDataReady;

  RawSocket _socket;

  Buffer? _writingBuffer;
  late int _writeOffset;
  late int _writeLength;
  late Completer<Buffer> _writeCompleter;

  Buffer? _readingBuffer;

  late int _readOffset;

  late Completer<Buffer> _readCompleter;

  late StreamSubscription<RawSocketEvent> _subscription;
  bool _closed = false;

  bool get closed => _closed;

  BufferedSocket._(
      this._socket, this.onDataReady, this.onDone, this.onError, this.onClosed)
      : log = Logger('BufferedSocket') {
    _subscription = _socket.listen(_onData,
        onError: _onSocketError, onDone: _onSocketDone, cancelOnError: true);
  }

  void _onSocketError(Object error) {
    if (onError != null) {
      onError!(error);
    }
  }

  void _onSocketDone() {
    if (onDone != null) {
      onDone!();
      _closed = true;
    }
  }

  static Future<RawSocket> defaultSocketFactory(
      String host, int port, Duration timeout,
      {bool isUnixSocket = false}) {
    if (isUnixSocket) {
      return RawSocket.connect(
          InternetAddress(host, type: InternetAddressType.unix), port,
          timeout: timeout);
    } else {
      return RawSocket.connect(host, port, timeout: timeout);
    }
  }

  static Future<BufferedSocket> connect(
    String host,
    int port,
    Duration timeout, {
    DataReadyHandler? onDataReady,
    DoneHandler? onDone,
    ErrorHandler? onError,
    ClosedHandler? onClosed,
    SocketFactory socketFactory = defaultSocketFactory,
    bool isUnixSocket = false,
  }) async {
    RawSocket socket;
    socket =
        await socketFactory(host, port, timeout, isUnixSocket: isUnixSocket);
    if (!isUnixSocket) {
      socket.setOption(SocketOption.tcpNoDelay, true);
    }
    return BufferedSocket._(socket, onDataReady, onDone, onError, onClosed);
  }

  void _onData(RawSocketEvent event) {
    if (_closed) {
      return;
    }

    if (event == RawSocketEvent.read) {
      log.fine('READ data');
      if (_readingBuffer == null) {
        log.fine('READ data: no buffer');
        onDataReady?.call();
      } else {
        _readBuffer();
      }
    } else if (event == RawSocketEvent.readClosed) {
      log.fine('READ_CLOSED');
      if (onClosed != null) {
        onClosed!();
      }
    } else if (event == RawSocketEvent.closed) {
      log.fine('CLOSED');
    } else if (event == RawSocketEvent.write) {
      log.fine('WRITE data');
      if (_writingBuffer != null) {
        _writeBuffer();
      }
    }
  }

  /// Writes [buffer] to the socket, and returns the same buffer in a [Future] which
  /// completes when it has all been written.
  Future<Buffer> writeBuffer(Buffer buffer) {
    return writeBufferPart(buffer, 0, buffer.length);
  }

  Future<Buffer> writeBufferPart(Buffer buffer, int start, int length) {
    log.fine('writeBuffer length=${buffer.length}');
    if (_closed) {
      throw StateError('Cannot write to socket, it is closed');
    }
    if (_writingBuffer != null) {
      throw StateError('Cannot write to socket, already writing');
    }
    _writingBuffer = buffer;
    _writeCompleter = Completer<Buffer>();
    _writeOffset = start;
    _writeLength = length + start;

    _writeBuffer();

    return _writeCompleter.future;
  }

  void _writeBuffer() {
    log.fine('_writeBuffer offset=$_writeOffset');
    var bytesWritten = _writingBuffer!
        .writeToSocket(_socket, _writeOffset, _writeLength - _writeOffset);
    log.fine('Wrote $bytesWritten bytes');
    if (log.isLoggable(Level.FINE)) {
      log.fine('\n${Buffer.debugChars(_writingBuffer!.list)}');
    }
    _writeOffset += bytesWritten;
    if (_writeOffset == _writeLength) {
      _writeCompleter.complete(_writingBuffer);
      _writingBuffer = null;
    } else {
      _socket.writeEventsEnabled = true;
    }
  }

  /// Reads into [buffer] from the socket, and returns the same buffer in a [Future] which
  /// completes when enough bytes have been read to fill the buffer.
  ///
  /// This must not be called while there is still a read ongoing, but may be called before
  /// onDataReady is called, in which case onDataReady will not be called when data arrives,
  /// and the read will start instead.
  Future<Buffer> readBuffer(Buffer buffer) {
    log.fine('readBuffer, length=${buffer.length}');
    if (_closed) {
      throw StateError('Cannot read from socket, it is closed');
    }
    if (_readingBuffer != null) {
      throw StateError('Cannot read from socket, already reading');
    }
    _readingBuffer = buffer;
    _readOffset = 0;
    _readCompleter = Completer<Buffer>();

    if (_socket.available() > 0) {
      log.fine('readBuffer, data already ready');
      _readBuffer();
    }

    return _readCompleter.future;
  }

  void _readBuffer() {
    var bytesRead = _readingBuffer!
        .readFromSocket(_socket, _readingBuffer!.length - _readOffset);
    log.fine('read $bytesRead bytes');
    if (log.isLoggable(Level.FINE)) {
      log.fine('\n${Buffer.debugChars(_readingBuffer!.list)}');
    }
    _readOffset += bytesRead;
    if (_readOffset == _readingBuffer!.length) {
      _readCompleter.complete(_readingBuffer);
      _readingBuffer = null;
    }
  }

  void close() {
    _socket.close();
    _closed = true;
  }

  Future startSSL() async {
    log.fine('Securing socket');
    var socket = await RawSecureSocket.secure(_socket,
        subscription: _subscription, onBadCertificate: (cert) => true);
    log.fine('Socket is secure');
    _socket = socket;
    _socket.setOption(SocketOption.tcpNoDelay, true);
    _subscription = _socket.listen(_onData,
        onError: _onSocketError, onDone: _onSocketDone, cancelOnError: true);
    _socket.writeEventsEnabled = true;
    _socket.readEventsEnabled = true;
  }
}
