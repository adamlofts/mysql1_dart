import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:mysql1/mysql1.dart';
import 'package:mysql1/src/bridge/bridge_protocol.dart';
import 'package:mysql1/src/bridge/mysql_bridge.dart';
import 'package:mysql1/src/net/bridge_client.dart';
import 'package:mysql1/src/net/connector.dart';
import 'package:mysql1/src/net/web_guard.dart';
import 'package:test/test.dart';

const _token = '0123456789abcdef';

void main() {
  group('what the browser is allowed to ask for', () {
    test('a direct connection is refused', () {
      expect(
        () => requireBridge(
          isUnixSocket: false,
          useSSL: false,
          bridgeUrl: null,
          bridgeToken: null,
        ),
        throwsA(isA<MySqlClientError>()),
      );
    });

    test('MySQL TLS is refused', () {
      expect(
        () => requireBridge(
          isUnixSocket: false,
          useSSL: true,
          bridgeUrl: 'ws://127.0.0.1:1/mysql',
          bridgeToken: _token,
        ),
        throwsA(isA<MySqlClientError>()),
      );
    });

    test('the url has to be a websocket', () {
      expect(
        () => requireBridge(
          isUnixSocket: false,
          useSSL: false,
          bridgeUrl: 'http://127.0.0.1:1/mysql',
          bridgeToken: _token,
        ),
        throwsA(isA<MySqlClientError>()),
      );
    });

    test('useSSL with a bridge fails before any socket is opened', () {
      expect(
        MySqlConnection.connect(
          ConnectionSettings(
            bridgeUrl: 'ws://127.0.0.1:9/mysql',
            bridgeToken: _token,
            useSSL: true,
          ),
        ),
        throwsA(isA<MySqlClientError>()),
      );
    });
  });

  group('the bridge handshake', () {
    test('bytes which arrive before ok are kept', () async {
      final frames = StreamController<dynamic>();
      final sent = <Object>[];
      final opened = openBridgeChannel(
        frames: frames.stream,
        sendText: sent.add,
        sendBytes: sent.add,
        close: () {},
        done: Completer<void>().future,
        token: _token,
        timeout: const Duration(seconds: 2),
      );
      expect(sent, ['$bridgeAuthPrefix$_token']);

      frames.add(Uint8List.fromList([1, 2, 3]));
      frames.add(bridgeAuthOk);
      final channel = await opened;
      addTearDown(channel.destroy);
      expect(await channel.stream.first, [1, 2, 3]);
    });

    test('a refusal fails the connection', () async {
      final frames = StreamController<dynamic>();
      final opened = openBridgeChannel(
        frames: frames.stream,
        sendText: (_) {},
        sendBytes: (_) {},
        close: () {},
        done: Completer<void>().future,
        token: _token,
        timeout: const Duration(seconds: 2),
      );
      frames.add('no');
      await expectLater(opened, throwsA(isA<MySqlClientError>()));
    });
  });

  group('MysqlBridge', () {
    late ServerSocket database;
    late List<Socket> accepted;
    late MysqlBridge bridge;

    setUp(() async {
      database = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      accepted = <Socket>[];
      database.listen(accepted.add);
      bridge = await MysqlBridge.start(
        token: _token,
        mysqlHost: '127.0.0.1',
        mysqlPort: database.port,
        port: 0,
        mysqlTimeout: const Duration(seconds: 2),
      );
    });

    tearDown(() async {
      for (final socket in accepted) {
        socket.destroy();
      }
      await bridge.close();
      await database.close();
    });

    test('a wrong token never reaches the database', () async {
      final ws = await WebSocket.connect(bridge.url);
      // done does not complete unless the stream is being listened to: a
      // close frame with no listener is never processed.
      ws.listen((_) {});
      ws.add('$bridgeAuthPrefix not-the-token');
      await ws.done.timeout(const Duration(seconds: 5));
      expect(ws.closeCode, 1008);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(accepted, isEmpty);
    });

    test('an unknown path is not a websocket', () async {
      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.get('127.0.0.1', bridge.urlPort, '/other');
      final response = await request.close();
      expect(response.statusCode, 404);
      await response.drain<void>();
    });

    test('bytes pass in both directions', () async {
      final channel = await openByteChannel(
        host: 'db.internal',
        port: 3306,
        timeout: const Duration(seconds: 5),
        isUnixSocket: false,
        bridgeUrl: bridge.url,
        bridgeToken: _token,
      );
      addTearDown(channel.destroy);

      final server = await _waitFor(accepted);
      // Written before the client listens, which is how a greeting arrives.
      server.add([10, 20, 30]);
      expect(await channel.stream.first.timeout(const Duration(seconds: 5)), [
        10,
        20,
        30,
      ]);

      final fromClient = server.first.timeout(const Duration(seconds: 5));
      channel.add(Uint8List.fromList([7, 8, 9]));
      expect(await fromClient, [7, 8, 9]);
    });

    test('a frame over the limit closes the connection', () async {
      final limited = await MysqlBridge.start(
        token: _token,
        mysqlHost: '127.0.0.1',
        mysqlPort: database.port,
        port: 0,
        maxFrameSize: 4,
      );
      addTearDown(limited.close);
      final ws = await WebSocket.connect(limited.url);
      final first = Completer<Object?>();
      ws.listen((data) {
        if (!first.isCompleted) {
          first.complete(data);
        }
      });
      ws.add('$bridgeAuthPrefix$_token');
      expect(
        await first.future.timeout(const Duration(seconds: 5)),
        bridgeAuthOk,
      );
      ws.add(Uint8List.fromList([1, 2, 3, 4, 5]));
      await ws.done.timeout(const Duration(seconds: 5));
      expect(ws.closeCode, 1009);
    });
  });

  test('the database being down is reported and not left open', () async {
    final bridge = await MysqlBridge.start(
      token: _token,
      mysqlHost: '127.0.0.1',
      mysqlPort: 1,
      port: 0,
      mysqlTimeout: const Duration(milliseconds: 500),
    );
    addTearDown(bridge.close);
    final ws = await WebSocket.connect(bridge.url);
    ws.listen((_) {});
    ws.add('$bridgeAuthPrefix$_token');
    await ws.done.timeout(const Duration(seconds: 5));
    expect(ws.closeCode, 1011);
  });
}

extension on MysqlBridge {
  int get urlPort => int.parse(url.split(':').last.split('/').first);
}

Future<Socket> _waitFor(List<Socket> accepted) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (accepted.isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('the database was not dialed');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return accepted.first;
}
