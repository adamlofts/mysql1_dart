library sqljocky.connection;

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:logging/logging.dart';

import 'auth/handshake_handler.dart';
import 'auth/ssl_handler.dart';
import 'buffer.dart';
import 'buffered_socket.dart';
import 'handlers/handler.dart';
import 'mysql_client_error.dart';
import 'handlers/quit_handler.dart';
import 'prepared_statements/close_statement_handler.dart';
import 'prepared_statements/execute_query_handler.dart';
import 'prepared_statements/prepare_handler.dart';
import 'query/query_stream_handler.dart';
import 'results/field.dart';
import 'results/results.dart';
import 'results/row.dart';

final Logger _log = new Logger("SingleConnection");

/// Represents a connection to the database. Use [connect] to open a connection. You
/// must call [close] when you are done.
class SingleConnection {
  final Duration _timeout;

  ReqRespConnection _conn;
  bool _sentClose = false;

  SingleConnection(this._timeout, this._conn);

  /// Close the connection
  ///
  /// This method will never throw
  Future close() async {
    if (_sentClose) {
      return;
    }
    _sentClose = true;

    try {
      await _conn.processHandlerNoResponse(new QuitHandler())
        .timeout(_timeout);
    } catch (e) {
      _log.info("Error sending quit on connection");
    }

    _conn.close();
  }

  static Future<SingleConnection> _connect(
      Duration timeout,
      {String host,
      int port,
      String user,
      String password,
      String db,
      bool useCompression: false,
      bool useSSL: false,
      int maxPacketSize: 16 * 1024 * 1024,
      }) {

    assert(!useSSL);  // Not implemented
    assert(!useCompression);

    var handshakeCompleter = new Completer();
    ReqRespConnection conn;
    SingleConnection sc;

    _log.fine("opening connection to $host:$port/$db");
    BufferedSocket.connect(host, port,
        onConnection: (socket) {
          conn = new ReqRespConnection(socket, maxPacketSize, user, password, db, useCompression, useSSL, handshakeCompleter);
        },
        onDataReady: () {
          conn?._readPacket();
        },
        onDone: () {
          conn?.close();
          _log.fine("done");
        },
        onError: (error) {
          _log.severe("socket error: $error");
          // If the error happens during connect then propagate in the future.
          // otherwise send to the socket.
          if (!handshakeCompleter.isCompleted) {
            handshakeCompleter.completeError(error);
            return;
          } else {
            conn?.close();
          }
        },
        onClosed: () {
          conn?.close();
        });

    //TODO Only useDatabase if connection actually ended up as an SSL connection?
    //TODO On the other hand, it doesn't hurt to call useDatabase anyway.
//    if (useSSL) {
//      await _completer.future;
//      return _useDatabase(db);
//    } else {
    return handshakeCompleter.future.then((_) {
      sc = new SingleConnection(timeout, conn);
      return sc;
    });
//    }
  }

  /// Connects a MySQL server at the given [host] on [port], authenticates using [user]
  /// and [password] and connects to [db].
  ///
  /// [timeout] is used as the connection timeout and the default timeout for all socket
  /// communication.
  static Future<SingleConnection> connect(
      {String host,
        int port,
        String user,
        String password,
        String db,
        bool useCompression: false,
        bool useSSL: false,
        int maxPacketSize: 16 * 1024 * 1024,
        Duration timeout: const Duration(seconds: 30)
      }) {
    // In dart2 this can be replaced with a timeout parameter to connect
    return
      _connect(timeout, host: host, port: port, user: user, password: password, db: db, useCompression: useCompression, useSSL: useSSL, maxPacketSize: maxPacketSize)
      .timeout(timeout);
  }

  Future<ReadResults> query(String sql, [List values]) async {
    if (values == null || values.isEmpty) {
      // Run the query without preparing it since we have no arguments.
      var results = await _conn.processHandler(new QueryStreamHandler(sql))
        .timeout(_timeout);
      _log.fine("Got query results on for: ${sql}");
      return await ReadResults.read(results);
    }

    var prepared;
    var results;
    try {
      prepared = await _conn.processHandler(new PrepareHandler(sql))
        .timeout(_timeout);
      _log.fine("Prepared new query for: $sql");

      var handler = new ExecuteQueryHandler(prepared, false /* executed */, values);
      results = await _conn.processHandler(handler)
          .timeout(_timeout);

      _log.finest("Prepared query got results");

      // Read all of the results. This is so we can close the handler before returning to the
      // user. Obviously this is not super efficient but it guarantees correct api use.
      return await ReadResults.read(results);

    } finally {
      if (prepared != null) {
        await _conn.processHandlerNoResponse(new CloseStatementHandler(prepared.statementHandlerId))
            .timeout(_timeout);
      }
    }
  }
}

class ReadResults extends IterableBase<Row> {
  final int insertId;
  final int affectedRows;
  final List<Field> fields;
  final List<Row> _rows;

  ReadResults(this._rows, this.fields, this.insertId, this.affectedRows);

  static Future<ReadResults> read(Results r) async {
    var rows = await r.toList();
    return new ReadResults(rows, r.fields, r.insertId, r.affectedRows);
  }

  @override
  Iterator<Row> get iterator {
    return _rows.iterator;
  }
}

class ReqRespConnection {
  static const int HEADER_SIZE = 4;
  static const int COMPRESSED_HEADER_SIZE = 7;
  static const int STATE_PACKET_HEADER = 0;
  static const int STATE_PACKET_DATA = 1;

  Handler _handler;
  Completer _completer;


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
  final int _maxPacketSize;


  ReqRespConnection(this._socket, this._maxPacketSize, user, password, db, useCompression, useSSL, Completer handshakeCompleter) :
        _headerBuffer = new Buffer(HEADER_SIZE),
        _compressedHeaderBuffer = new Buffer(COMPRESSED_HEADER_SIZE),
        _handler = new HandshakeHandler(
            user, password, _maxPacketSize, db, useCompression, useSSL),
        _completer = handshakeCompleter;

  void close() => _socket.close();

  void socketError(e) {
    if (_completer != null) {
      _completer.completeError(e);
    }
    close();
  }

  Future _readPacket() async {
    _log.fine("readPacket readyForHeader=${_readyForHeader}");
    if (_readyForHeader) {
      _readyForHeader = false;
      var buffer = await _socket.readBuffer(_headerBuffer);
      _handleHeader(buffer);
    }
  }

  _handleHeader(buffer) async {
    int _dataSize = buffer[0] + (buffer[1] << 8) + (buffer[2] << 16);
    _packetNumber = buffer[3];
    _log.fine("about to read $_dataSize bytes for packet ${_packetNumber}");
    _dataBuffer = new Buffer(_dataSize);
    _log.fine("buffer size=${_dataBuffer.length}");
    if (_dataSize == 0xffffff || _largePacketBuffers.length > 0) {
      var buffer = await _socket.readBuffer(_dataBuffer);
      _handleMoreData(buffer);
    } else {
      var buffer = await _socket.readBuffer(_dataBuffer);
      _handleData(buffer);
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
        combinedBuffer.list
            .setRange(start, start + aBuffer.length, aBuffer.list);
        start += aBuffer.length;
      });
      _largePacketBuffers.clear();
      _handleData(combinedBuffer);
    } else {
      _readyForHeader = true;
      _headerBuffer.reset();
      _readPacket();
    }
  }

  _handleData(buffer) async {
    _readyForHeader = true;
    _headerBuffer.reset();

    try {
      var response = _handler.processResponse(buffer);
      if (_handler is HandshakeHandler) {
        _useCompression = (_handler as HandshakeHandler).useCompression;
        _useSSL = (_handler as HandshakeHandler).useSSL;
      }
      if (response.nextHandler != null) {
        // if handler.processResponse() returned a Handler, pass control to that handler now
        _handler = response.nextHandler;
        await _sendBuffer(_handler.createRequest());
        if (_useSSL && _handler is SSLHandler) {
          _log.fine("Use SSL");
          await _socket.startSSL();
          _handler = (_handler as SSLHandler).nextHandler;
          await _sendBuffer(_handler.createRequest());
          _log.fine("Sent buffer");
          return;
        }
      }
      if (response.finished) {
        _log.fine("Finished $_handler");
        _finishAndReuse();
      }
      if (response.hasResult) {
        if (_completer.isCompleted) {
          _completer
              .completeError(new StateError("Request has already completed"));
        }
        _completer.complete(response.result);
      }
    } catch (e, st) {
      _finishAndReuse();
      _log.fine("completing with exception: $e");
      if (_completer.isCompleted) {
        throw e;
      }
      _completer.completeError(e, st);
    }
  }

  void _finishAndReuse() {
    _handler = null;
  }

  Future _sendBuffer(Buffer buffer) {
    if (buffer.length > _maxPacketSize) {
      throw createMySqlClientError(
          "Buffer length (${buffer.length}) bigger than maxPacketSize ($_maxPacketSize)");
    }
    if (_useCompression) {
      _headerBuffer[0] = buffer.length & 0xFF;
      _headerBuffer[1] = (buffer.length & 0xFF00) >> 8;
      _headerBuffer[2] = (buffer.length & 0xFF0000) >> 16;
      _headerBuffer[3] = ++_packetNumber;
      var encodedHeader = ZLIB.encode(_headerBuffer.list);
      var encodedBuffer = ZLIB.encode(buffer.list);
      _compressedHeaderBuffer
          .writeUint24(encodedHeader.length + encodedBuffer.length);
      _compressedHeaderBuffer.writeByte(++_compressedPacketNumber);
      _compressedHeaderBuffer.writeUint24(4 + buffer.length);
      return _socket.writeBuffer(_compressedHeaderBuffer);
    } else {
      _log.fine("sendBuffer header");
      return _sendBufferPart(buffer, 0);
    }
  }

  Future<Buffer> _sendBufferPart(Buffer buffer, int start) async {
    var len = math.min(buffer.length - start, 0xFFFFFF);

    _headerBuffer[0] = len & 0xFF;
    _headerBuffer[1] = (len & 0xFF00) >> 8;
    _headerBuffer[2] = (len & 0xFF0000) >> 16;
    _headerBuffer[3] = ++_packetNumber;
    _log.fine("sending header, packet $_packetNumber");
    await _socket.writeBuffer(_headerBuffer);
    _log.fine(
        "sendBuffer body, buffer length=${buffer.length}, start=$start, len=$len");
    await _socket.writeBufferPart(buffer, start, len);
    if (len == 0xFFFFFF) {
      return _sendBufferPart(buffer, start + len);
    } else {
      return buffer;
    }
  }

  /// This method just sends the handler data.
  Future processHandlerNoResponse(Handler handler) {
    if (_handler != null) {
      throw createMySqlClientError(
          "Connection cannot process a request for $handler while a request is already in progress for $_handler");
    }
    _packetNumber = -1;
    _compressedPacketNumber = -1;
    return _sendBuffer(handler.createRequest());
  }

  /**
   * Processes a handler, from sending the initial request to handling any packets returned from
   * mysql
   */
  Future processHandler(Handler handler) async {
    if (_handler != null) {
      throw createMySqlClientError(
          "Connection cannot process a request for $handler while a request is already in progress for $_handler");
    }
    _log.fine("start handler $handler");
    _packetNumber = -1;
    _compressedPacketNumber = -1;
    _completer = new Completer<dynamic>();
    _handler = handler;
    await _sendBuffer(handler.createRequest());
    return _completer.future;
  }
}
