library mysql1.protocol_connection_test;

import 'dart:async';
import 'dart:typed_data';
import 'dart:io';

import 'package:mysql1/mysql1.dart' show MySqlClientError, MySqlException;
import 'package:mysql1/src/mysql_exception.dart';
import 'package:test/test.dart';

import 'fake_server.dart';

const _timeout = Duration(seconds: 5);

/// An error packet: the marker, an error number, and a state and message.
final _error = [0xff, 0x48, 0x04, ...'#HY000No'.codeUnits];

void main() {
  late FakeServer server;

  setUp(() async {
    server = await FakeServer.start(maxPacketSize: 1024);
  });

  tearDown(() => server.close());

  test('a request starts the numbering again, and a reply carries it on',
      () async {
    final client = server.client;
    for (var i = 0; i < 2; i++) {
      final exchange = client.exchange(() async {
        client.send(Uint8List.fromList([1]));
        await client.next();
        client.send(Uint8List.fromList([2]));
        await client.next();
      }, _timeout);

      expect((await server.nextRequest()).sequenceId, equals(0));
      server.send([
        [10]
      ], sequenceId: 1);
      expect((await server.nextRequest()).sequenceId, equals(2));
      server.send([
        [11]
      ], sequenceId: 3);
      await exchange;
    }
  });

  test('exchanges take turns', () async {
    final client = server.client;
    final events = <String>[];
    Future<void> exchange(int n) => client.exchange(() async {
          events.add('start $n');
          client.send(Uint8List.fromList([n]));
          await client.next();
          events.add('end $n');
        }, _timeout);

    final both = Future.wait([exchange(1), exchange(2)]);
    await server.nextRequest();
    await pumpEventQueue();
    expect(events, equals(['start 1']));
    server.send([
      [0]
    ]);
    await server.nextRequest();
    server.send([
      [0]
    ]);
    await both;
    expect(events, equals(['start 1', 'end 1', 'start 2', 'end 2']));
  });

  test('a packet too big to send is refused, and nothing else is lost',
      () async {
    final client = server.client;
    await expectLater(
        client.exchange(() async => client.send(Uint8List(1025)), _timeout),
        throwsA(isA<MySqlClientError>()));
    expect(client.isClosed, isFalse);
  });

  // The server ended the response by sending the error, so the wire is where
  // the next request expects it to be.
  test('an error from the server leaves the connection open', () async {
    final client = server.client;
    final exchange = client.exchange(() async {
      client.send(Uint8List.fromList([1]));
      final packet = await client.next();
      throw createMySqlException(packet.payload);
    }, _timeout);
    await server.nextRequest();
    server.send([_error]);
    await expectLater(exchange, throwsA(isA<MySqlException>()));
    expect(client.isClosed, isFalse);
  });

  // Part of the response may still be on its way, and the next request would
  // be answered with it.
  test('an exchange which times out closes the connection', () async {
    final client = server.client;
    await expectLater(
        client.exchange(() async {
          client.send(Uint8List.fromList([1]));
          await client.next();
        }, const Duration(milliseconds: 20)),
        throwsA(isA<TimeoutException>()));
    expect(client.isClosed, isTrue);
    await expectLater(
        client.exchange(() async {}, _timeout), throwsA(isA<StateError>()));
  });

  test('an exchange which fails part way closes the connection', () async {
    final client = server.client;
    final exchange = client.exchange(() async {
      client.send(Uint8List.fromList([1]));
      await client.next();
      throw const FormatException('nonsense');
    }, _timeout);
    await server.nextRequest();
    server.send([
      [0]
    ]);
    await expectLater(exchange, throwsA(isA<FormatException>()));
    expect(client.isClosed, isTrue);
  });

  test('the server going away fails whoever is reading', () async {
    final client = server.client;
    final exchange = client.exchange(() async {
      client.send(Uint8List.fromList([1]));
      await client.next();
    }, _timeout);
    await server.nextRequest();
    server.hangUp();
    await expectLater(exchange, throwsA(isA<SocketException>()));
    expect(client.isClosed, isTrue);
  });
}
