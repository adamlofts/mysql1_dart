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
import 'mysql_exception.dart';
import 'handlers/quit_handler.dart';
import 'package:pool/pool.dart';
import 'package:sqljocky5/src/auth/character_set.dart';
import 'package:sqljocky5/src/results/results_impl.dart';
import 'prepared_statements/close_statement_handler.dart';
import 'prepared_statements/execute_query_handler.dart';
import 'prepared_statements/prepare_handler.dart';
import 'query/query_stream_handler.dart';
import 'results/field.dart';
import 'results/row.dart';

final Logger _log = new Logger("SingleConnection");

class ConnectionSettings {
  String host;
  int port;
  String user;
  String password;
  String db;
  bool useCompression;
  bool useSSL;
  int maxPacketSize;
  int characterSet;

  /// The timeout for connecting to the database and for all database operations.
  Duration timeout;

  ConnectionSettings(
      {String this.host: 'localhost',
      int this.port: 3306,
      String this.user,
      String this.password,
      String this.db,
      bool this.useCompression: false,
      bool this.useSSL: false,
      int this.maxPacketSize: 16 * 1024 * 1024,
      Duration this.timeout: const Duration(seconds: 30),
      int this.characterSet: CharacterSet.UTF8MB4});

  ConnectionSettings.copy(ConnectionSettings o) {
    host = o.host;
    port = o.port;
    user = o.user;
    password = o.password;
    db = o.db;
    useCompression = o.useCompression;
    useSSL = o.useSSL;
    maxPacketSize = o.maxPacketSize;
    timeout = o.timeout;
    characterSet = o.characterSet;
  }
}

/// Represents a connection to the database. Use [connect] to open a connection. You
/// must call [close] when you are done.
class MySqlConnection {
  final Duration _timeout;

  ReqRespConnection _conn;
  bool _sentClose = false;

  MySqlConnection(this._timeout, this._conn);

  /// Close the connection
  ///
  /// This method will never throw
  Future close() async {
    if (_sentClose) {
      return;
    }
    _sentClose = true;

    try {
      await _conn.processHandlerNoResponse(new QuitHandler(), _timeout);
    } catch (e) {
      _log.info("Error sending quit on connection");
    }

    _conn.close();
  }

  static Future<MySqlConnection> _connect(ConnectionSettings c) async {
    assert(!c.useSSL); // Not implemented
    assert(!c.useCompression);

    ReqRespConnection conn;
    Completer handshakeCompleter;

    _log.fine("opening connection to ${c.host}:${c.port}/${c.db}");

    BufferedSocket socket =
        await BufferedSocket.connect(c.host, c.port, onDataReady: () {
      conn?._readPacket();
    }, onDone: () {
      _log.fine("done");
    }, onError: (error) {
      _log.warning("socket error: $error");

      // If conn has not been connected there was a connection error.
      if (conn == null) {
        handshakeCompleter.completeError(error);
      } else {
        conn.handleError(error);
      }
    }, onClosed: () {
      conn.handleError(new SocketException.closed());
    });

    Handler handler = new HandshakeHandler(c.user, c.password, c.maxPacketSize,
        c.characterSet, c.db, c.useCompression, c.useSSL);
    handshakeCompleter = new Completer();
    conn = new ReqRespConnection(
        socket, handler, handshakeCompleter, c.maxPacketSize);

    await handshakeCompleter.future;
    return new MySqlConnection(c.timeout, conn);
  }

  /// Connects a MySQL server at the given [host] on [port], authenticates using [user]
  /// and [password] and connects to [db].
  ///
  /// [timeout] is used as the connection timeout and the default timeout for all socket
  /// communication.
  static Future<MySqlConnection> connect(ConnectionSettings c) {
    // In dart2 this can be replaced with a timeout parameter to connect
    return _connect(c).timeout(c.timeout);
  }

  Future<Results> query(String sql, [List values]) async {
    if (values == null || values.isEmpty) {
      return _conn.processHandlerWithResults(
          new QueryStreamHandler(sql), _timeout);
    }

    return (await queryMulti(sql, [values])).first;
  }

  Future<List<Results>> queryMulti(String sql, Iterable<List> values) async {
    var prepared;
    var ret = <Results>[];
    try {
      prepared = await _conn.processHandler(new PrepareHandler(sql), _timeout);
      _log.fine("Prepared queryMulti query for: $sql");

      for (List v in values) {
        var handler =
            new ExecuteQueryHandler(prepared, false /* executed */, v);
        ret.add(await _conn.processHandlerWithResults(handler, _timeout));
      }
    } finally {
      if (prepared != null) {
        await _conn.processHandlerNoResponse(
            new CloseStatementHandler(prepared.statementHandlerId), _timeout);
      }
    }
    return ret;
  }

  Future transaction(Future queryBlock(TransactionContext connection)) async {
    await query("start transaction");
    try {
      await queryBlock(new TransactionContext._(this));
    } catch (e) {
      await query("rollback");
      if (e is! _RollbackError) {
        rethrow;
      }
      return e;
    }
    await query("commit");
  }
}

class TransactionContext {
  final MySqlConnection _conn;
  TransactionContext._(this._conn);

  Future<Results> query(String sql, [List values]) => _conn.query(sql, values);
  Future<List<Results>> queryMulti(String sql, Iterable<List> values) =>
      _conn.queryMulti(sql, values);
  void rollback() => throw new _RollbackError();
}

class _RollbackError {}

class Results extends IterableBase<Row> {
  final int insertId;
  final int affectedRows;
  final List<Field> fields;
  final List<Row> _rows;

  Results(this._rows, this.fields, this.insertId, this.affectedRows);

  static Future<Results> read(ResultsStream r) async {
    var rows = await r.toList();
    return new Results(rows, r.fields, r.insertId, r.affectedRows);
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

  ReqRespConnection(this._socket, this._handler, Completer handshakeCompleter,
      this._maxPacketSize)
      : _headerBuffer = new Buffer(HEADER_SIZE),
        _compressedHeaderBuffer = new Buffer(COMPRESSED_HEADER_SIZE),
        _completer = handshakeCompleter;

  void close() => _socket.close();

  void handleError(e, {bool keepOpen: false, st}) {
    if (_completer != null) {
      if (_completer.isCompleted) {
        _log.warning("Ignoring error because no response", e, st);
      } else {
        _completer.completeError(e, st);
      }
    }
    if (!keepOpen) {
      close();
    }
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
        await sendBuffer(_handler.createRequest());
        if (_useSSL && _handler is SSLHandler) {
          _log.fine("Use SSL");
          await _socket.startSSL();
          _handler = (_handler as SSLHandler).nextHandler;
          await sendBuffer(_handler.createRequest());
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
    } on MySqlException catch (e, st) {
      // This clause means mysql returned an error on the wire. It is not a fatal error
      // and the connection can stay open.
      _log.fine("completing with MySqlException: $e");
      _finishAndReuse();
      handleError(e, st: st, keepOpen: true);
    } catch (e, st) {
      // Errors here are fatal_finishAndReuse();
      handleError(e, st: st);
    }
  }

  void _finishAndReuse() {
    _handler = null;
  }

  Future sendBuffer(Buffer buffer) {
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
  Future _processHandlerNoResponse(Handler handler) {
    if (_handler != null) {
      throw createMySqlClientError(
          "Connection cannot process a request for $handler while a request is already in progress for $_handler");
    }
    _packetNumber = -1;
    _compressedPacketNumber = -1;
    return sendBuffer(handler.createRequest());
  }

  /**
   * Processes a handler, from sending the initial request to handling any packets returned from
   * mysql
   */
  Future _processHandler(Handler handler) async {
    if (_handler != null) {
      throw createMySqlClientError(
          "Connection cannot process a request for $handler while a request is already in progress for $_handler");
    }
    _log.fine("start handler $handler");
    _packetNumber = -1;
    _compressedPacketNumber = -1;
    _completer = new Completer<dynamic>();
    _handler = handler;
    await sendBuffer(handler.createRequest());
    return _completer.future;
  }

  final Pool pool = new Pool(1);

  Future processHandler(Handler handler, Duration timeout) {
    return pool.withResource(() async {
      var ret = await _processHandler(handler).timeout(timeout);
      return ret;
    });
  }

  Future<Results> processHandlerWithResults(Handler handler, Duration timeout) {
    return pool.withResource(() async {
      ResultsStream results = await _processHandler(handler).timeout(timeout);

      // Read all of the results. This is so we can close the handler before returning to the
      // user. Obviously this is not super efficient but it guarantees correct api use.
      Results ret = await Results.read(results).timeout(timeout);

      return ret;
    });
  }

  Future processHandlerNoResponse(Handler handler, Duration timeout) {
    return pool.withResource(() {
      return _processHandlerNoResponse(handler).timeout(timeout);
    });
  }
}
