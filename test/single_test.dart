import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:mockito/mockito.dart';
import 'package:options_file/options_file.dart';
import 'package:sqljocky5/sqljocky.dart';
import 'package:sqljocky5/src/buffered_socket.dart';
import 'package:sqljocky5/src/handlers/handler.dart';
import 'package:sqljocky5/src/single_connection.dart';
import 'package:sqljocky5/utils.dart';
import 'package:test/test.dart';

void main() {
  hierarchicalLoggingEnabled = true;
  Logger.root.level = Level.OFF;
//  new Logger("ConnectionPool").level = Level.ALL;
//  new Logger("Connection.Lifecycle").level = Level.ALL;
//  new Logger("Query").level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord r) {
    print("${r.time}: ${r.loggerName}: ${r.message}");
  });

  test('connection test', () async {
    var options = new OptionsFile('connection.options');
    var user = options.getString('user');
    var password = options.getString('password');
    var port = options.getInt('port', 3306);
    var db = options.getString('db');
    var host = options.getString('host', 'localhost');

    // create a connection
    var conn = await SingleConnection.connect(
        host: host,
        port: port,
        user: user,
        password: password,
        db: db);

    await conn.query("DROP TABLE IF EXISTS t1");
    await conn.query("CREATE TABLE IF NOT EXISTS t1 (a INT)");
    var r = await conn.query("INSERT INTO `t1` (a) VALUES (?)", [1]);

    r = await conn.query("SELECT * FROM `t1` WHERE a = ?", [1]);
    expect(r.length, 1);

    r = await conn.query("SELECT * FROM `t1` WHERE a = ?", [2]);
    expect(r.length, 0);

    await conn.close();
  });

  test('connection fail connect test', () async {
    try {
      await SingleConnection.connect(
          host: 'localhost',
          port: 12345);
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
      await SingleConnection.connect(
          host: 'localhost',
          port: 12346,
          timeout: new Duration(microseconds: 5));
    } on TimeoutException catch (e) {
      thrown = true;
    } finally {
      sock?.close();
    }
    expect(thrown, true);
  });

  test('calling close on a broken socket should respect the socket timeout. close never throws.', () async {
    _MockReqResp m = new _MockReqResp();
    when(m.processHandlerNoResponse(any)).thenReturn(new Completer().future);

    SingleConnection conn = new SingleConnection(const Duration(microseconds: 5), m);
    await conn.close();  // does not timeout the test.
  });

  test('calling query on a broken socket should respect the socket timeout', () async {
    _MockReqResp m = new _MockReqResp();
    when(m.processHandler(any)).thenReturn(new Completer().future);

    SingleConnection conn = new SingleConnection(const Duration(microseconds: 5), m);
    expect(conn.query("SELECT 1"), throwsA(timeoutMatcher));
  });
}

class _MockReqResp extends Mock implements ReqRespConnection {}

final Matcher timeoutMatcher = const _TimeoutException();
class _TimeoutException extends TypeMatcher {
  const _TimeoutException() : super("TimeoutException");
  bool matches(item, Map matchState) => item is TimeoutException;
}
