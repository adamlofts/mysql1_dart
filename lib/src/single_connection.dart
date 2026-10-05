library mysql1.connection;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import 'handshake.dart';
import 'buffer.dart';
import 'constants.dart';
import 'protocol_connection.dart';
import 'query/query_response.dart';
import 'results/field.dart';
import 'results/row.dart';
import 'substitute_params.dart';

final Logger _log = Logger('MySqlConnection');

class ConnectionSettings {
  String host;
  int port;
  String? user;
  String? password;
  String? db;

  /// Whether to connect over TLS. If the server cannot, the connection fails:
  /// it is not made without.
  bool useSSL;

  /// The certificates to trust when [useSSL] is set. The system's roots if
  /// this is null.
  ///
  /// The server's certificate has to chain to one of them and be for [host].
  /// Dart 3.0 only matches a host which is a name: a certificate which lists
  /// an address is not accepted for that address there, though it is on a
  /// current SDK.
  /// A server with a certificate of its own making - which is what MySQL
  /// generates for itself - needs that certificate, or the authority which
  /// signed it, added to a context given here.
  SecurityContext? securityContext;

  /// Asked about a server certificate which was not trusted or is not for
  /// [host], when [useSSL] is set. Return true to connect anyway.
  ///
  /// With no callback such a certificate fails the connection with a
  /// [HandshakeException]. Returning true for everything is encryption with
  /// no check on who is at the other end.
  bool Function(X509Certificate certificate)? onBadCertificate;

  int maxPacketSize;
  int characterSet;

  /// The timeout for connecting to the database and for all database operations.
  Duration timeout;

  ConnectionSettings(
      {this.host = 'localhost',
      this.port = 3306,
      this.user,
      this.password,
      this.db,
      this.useSSL = false,
      this.securityContext,
      this.onBadCertificate,
      this.maxPacketSize = 16 * 1024 * 1024,
      this.timeout = const Duration(seconds: 30),
      this.characterSet = CharacterSet.UTF8MB4});

  factory ConnectionSettings.socket(
          {required String path,
          String? user,
          String? password,
          String? db,
          bool useSSL = false,
          SecurityContext? securityContext,
          bool Function(X509Certificate certificate)? onBadCertificate,
          int maxPacketSize = 16 * 1024 * 1024,
          Duration timeout = const Duration(seconds: 30),
          int characterSet = CharacterSet.UTF8MB4}) =>
      ConnectionSettings(
          host: path,
          user: user,
          password: password,
          db: db,
          useSSL: useSSL,
          securityContext: securityContext,
          onBadCertificate: onBadCertificate,
          maxPacketSize: maxPacketSize,
          timeout: timeout,
          characterSet: characterSet);

  ConnectionSettings.copy(ConnectionSettings o)
      : host = o.host,
        port = o.port,
        user = o.user,
        password = o.password,
        db = o.db,
        useSSL = o.useSSL,
        securityContext = o.securityContext,
        onBadCertificate = o.onBadCertificate,
        maxPacketSize = o.maxPacketSize,
        timeout = o.timeout,
        characterSet = o.characterSet;
}

/// Represents a connection to the database. Use [connect] to open a connection. You
/// must call [close] when you are done.
class MySqlConnection {
  final Duration _timeout;

  final ProtocolConnection _conn;
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

    if (!_conn.isClosed) {
      try {
        // Queued behind whatever is in progress, like any other request. There
        // is no reply to wait for.
        await _conn.exchange(() async {
          final request = Buffer(1);
          request.writeByte(COM_QUIT);
          _conn.send(request);
          await _conn.flush();
        }, _timeout).timeout(_timeout);
      } catch (e, st) {
        _log.warning('Error sending quit on connection', e, st);
      }
    }

    _conn.close();
  }

  /// Connects a MySQL server at the given [host] on [port], authenticates using [user]
  /// and [password] and connects to [db].
  ///
  /// [c.timeout] is used as the connection timeout and the default timeout for all socket
  /// communication.
  ///
  /// A [SocketException] is thrown on connection failure or a socket timeout connecting the
  /// socket.
  /// A [TimeoutException] is thrown if there is a timeout in the handshake with the
  /// server.
  static Future<MySqlConnection> connect(ConnectionSettings c,
      {bool isUnixSocket = false}) async {
    _log.fine('opening connection to ${c.host}:${c.port}/${c.db}');

    final conn = await ProtocolConnection.connect(
        c.host, c.port, c.timeout, c.maxPacketSize,
        isUnixSocket: isUnixSocket);
    try {
      await conn.exchange(
          () => handshake(conn,
              user: c.user,
              password: c.password,
              db: c.db,
              maxPacketSize: c.maxPacketSize,
              characterSet: c.characterSet,
              useSSL: c.useSSL,
              host: c.host,
              securityContext: c.securityContext,
              onBadCertificate: c.onBadCertificate,
              // Nobody can get between the client and the server on a unix
              // socket, which is what lets full authentication send a
              // cleartext password.
              isSecure: isUnixSocket),
          c.timeout);
    } catch (_) {
      conn.close();
      rethrow;
    }
    return MySqlConnection(c.timeout, conn);
  }

  Future<Results> _query(String sql) async {
    final response =
        await _conn.exchange(() => runQuery(_conn, utf8.encode(sql)), _timeout);
    // Outside the exchange: the response has been read in full, so a value
    // which cannot be decoded fails this query and nothing else.
    return Results._(response.decodeRows(), response.fields, response.insertId,
        response.affectedRows);
  }

  /// Run [sql] query on the database using [values] as positional sql parameters.
  ///
  /// eg. ```query('SELECT FROM users WHERE id = ?', [userId])```.
  ///
  /// [values] are substituted into [sql] as literals before it is sent, so the
  /// server receives one statement with no parameters - see
  /// [substituteParams] for what that buys and what it assumes.
  Future<Results> query(String sql, [List<Object?>? values]) async {
    if (values == null || values.isEmpty) {
      return _query(sql);
    }

    return _query(substituteParams(sql, values));
  }

  /// Run [sql] query multiple times for each set of positional sql parameters in [values].
  ///
  /// e.g. ```queryMulti('INSERT INTO USERS (name) VALUES (?)', ['Adam', 'Eve'])```.
  ///
  /// Each set of values is substituted into [sql] and sent as its own
  /// statement. Nothing is shared between them beyond the connection.
  Future<List<Results>> queryMulti(
      String sql, Iterable<List<Object?>> values) async {
    var ret = <Results>[];
    for (final v in values) {
      ret.add(await _query(substituteParams(sql, v)));
    }
    return ret;
  }

  Future<T?> transaction<T>(
    Future<T> Function(TransactionContext) queryBlock, {
    Function(Object)? onError,
  }) async {
    await query('start transaction');
    try {
      final result = await queryBlock(TransactionContext._(this));
      await query('commit');
      return result;
    } catch (e) {
      await query('rollback');
      if (e is! _RollbackError) {
        rethrow;
      }
      onError?.call(e);
      return null;
    }
  }
}

class TransactionContext {
  final MySqlConnection _conn;
  TransactionContext._(this._conn);

  Future<Results> query(String sql, [List<Object?>? values]) =>
      _conn.query(sql, values);
  Future<List<Results>> queryMulti(
          String sql, Iterable<List<Object?>> values) =>
      _conn.queryMulti(sql, values);
  void rollback() => throw _RollbackError();
}

class _RollbackError {}

/// An iterable of result rows returned by [MySqlConnection.query] or [MySqlConnection.queryMulti].
class Results extends IterableBase<ResultRow> {
  final int? insertId;
  final int? affectedRows;
  final List<Field> fields;
  final List<ResultRow> _rows;

  Results._(this._rows, this.fields, this.insertId, this.affectedRows);

  @override
  Iterator<ResultRow> get iterator => _rows.iterator;
}
