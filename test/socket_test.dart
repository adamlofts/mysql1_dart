// ignore_for_file: strong_mode_implicit_dynamic_list_literal, strong_mode_implicit_dynamic_parameter, argument_type_not_assignable, invalid_assignment, non_bool_condition, strong_mode_implicit_dynamic_variable, deprecated_member_use

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:mockito/mockito.dart';
import 'package:mysql1/mysql1.dart';
import 'package:mysql1/src/buffered_socket.dart';
import 'package:mysql1/src/single_connection.dart';
import 'package:test/test.dart';

void main() {
  hierarchicalLoggingEnabled = true;
  Logger.root.level = Level.OFF;
//  new Logger("BufferedSocket").level = Level.ALL;

  Logger.root.onRecord.listen((LogRecord r) {
    print("${r.time}: ${r.loggerName}: ${r.message}");
  });

  test('connection fail connect test', () async {
    try {
      await MySqlConnection.connect(new ConnectionSettings(port: 12345));
    } on SocketException catch (e) {
      expect(e.osError.errorCode, 111);
    }
  });

  test('timeout connect test', () async {
    // The connect call should raise a timeout.
    var sock;
    bool thrown = false;
    try {
      sock = await ServerSocket.bind("localhost", 12346);
      await MySqlConnection.connect(new ConnectionSettings(
          port: 12346, timeout: new Duration(microseconds: 5)));
    } on TimeoutException {
      thrown = true;
    } on SocketException {
      thrown = true;
    } finally {
      sock?.close();
    }
    expect(thrown, true);
  });

  test(
      'calling close on a broken socket should respect the socket timeout. close never throws.',
      () async {
    _MockBufferedSocket m = new _MockBufferedSocket();
    ReqRespConnection r = new ReqRespConnection(m, null, null, 1024);
    MySqlConnection conn =
        new MySqlConnection(const Duration(microseconds: 5), r);
    await conn.close(); // does not timeout the test.
  });

  test('calling query on a broken socket should respect the socket timeout',
      () async {
    _MockBufferedSocket m = new _MockBufferedSocket();
    ReqRespConnection r = new ReqRespConnection(m, null, null, 1024);
    MySqlConnection conn =
        new MySqlConnection(const Duration(microseconds: 5), r);
    expect(conn.query("SELECT 1"), throwsA(timeoutMatcher));
  });

  test('socket closed before handshake', () async {
    var sock;
    bool thrown = false;
    try {
      sock = await ServerSocket.bind("localhost", 12347);
      sock.listen((socket) {
        socket.close();
      });
      await MySqlConnection.connect(new ConnectionSettings(
        port: 12347,
      ));
    } on SocketException catch (e) {
      thrown = true;
      expect(e.message, "Socket has been closed");
    } finally {
      sock?.close();
    }
    expect(thrown, true);
  });

  test('socket too many connections on connect', () async {
    var sock;
    bool thrown = false;
    try {
      sock = await ServerSocket.bind("localhost", 12348);
      sock.listen((socket) async {
        socket.add([23, 0, 0, 0]);
        socket.add([
          255,
          16,
          4,
          84,
          111,
          111,
          32,
          109,
          97,
          110,
          121,
          32,
          99,
          111,
          110,
          110,
          101,
          99,
          116,
          105,
          111,
          110,
          115
        ]);
        socket.close();
      });
      await MySqlConnection.connect(new ConnectionSettings(
        port: 12348,
      ));
    } on MySqlException catch (e) {
      thrown = true;
      expect(e.message, "ny connections");
    } finally {
      sock?.close();
    }
    expect(thrown, true);
  });

  test('bad protocol', () async {
    var sock;
    bool thrown = false;
    try {
      sock = await ServerSocket.bind("localhost", 12348);
      sock.listen((socket) async {
        socket.add([1, 0, 0, 0]);
        socket.add([9]);
        socket.close();
      });
      await MySqlConnection.connect(new ConnectionSettings(
        port: 12348,
      ));
    } on MySqlClientError catch (e) {
      thrown = true;
      expect(e.message, "Protocol not supported");
    } finally {
      sock?.close();
    }
    expect(thrown, true);
  });
}

class _MockBufferedSocket extends Mock implements BufferedSocket {}

final Matcher timeoutMatcher = const _TimeoutException();

class _TimeoutException extends TypeMatcher<TimeoutException> {
  const _TimeoutException() : super("TimeoutException");
  bool matches(item, Map matchState) => item is TimeoutException;
}

Matcher socketExceptionMatcher(int code) => new _SocketException(code);

class _SocketException extends TypeMatcher<SocketException> {
  final int errorCode;
  const _SocketException(this.errorCode) : super("SocketException");
  bool matches(item, Map matchState) =>
      item is SocketException && item.osError.errorCode == errorCode;
}
