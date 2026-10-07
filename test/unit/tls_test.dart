library mysql1.tls_test;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mysql1/mysql1.dart' show MySqlClientError, MySqlProtocolError;
import 'package:mysql1/src/constants.dart';
import 'package:mysql1/src/handshake.dart';
import 'package:mysql1/src/payload.dart';
import 'package:test/test.dart';

import 'fake_server.dart';

const _timeout = Duration(seconds: 5);

// A certificate signed by nobody but itself, for localhost and 127.0.0.1.
// This is the position a MySQL server is in with the certificate it makes
// for itself: a client only trusts it if it has been told to.
const _certificate = 'test/unit/tls/test_server_cert_intentionally_public.pem';
const _key = 'test/unit/tls/test_server_key_intentionally_public.pem';

/// The greeting of a server which can do TLS, or says it cannot.
List<int> _greeting({bool tls = true}) {
  final capabilities = Capability.protocol41.bit |
      Capability.secureConnection.bit |
      (tls ? Capability.ssl.bit : 0) |
      Capability.pluginAuth.bit;
  return [
    10, // protocol version
    ...utf8.encode('version 1'), 0,
    1, 0, 0, 0, // thread id
    ...utf8.encode('abcdefgh'), 0, // the first of the scramble
    capabilities & 0xff, (capabilities >> 8) & 0xff,
    9, // language
    2, 0, // status
    (capabilities >> 16) & 0xff, (capabilities >> 24) & 0xff,
    21, // scramble length
    ...List.filled(10, 0),
    ...utf8.encode('ijklmnopqrst'), 0, // the rest of the scramble
    ...utf8.encode('caching_sha2_password'), 0,
  ];
}

void main() {
  late FakeServer server;

  setUp(() async {
    server = await FakeServer.start();
  });

  tearDown(() => server.close());

  /// Start TLS at both ends. Fails as it failed for the client.
  Future<void> startTls(
      {String? host,
      SecurityContext? context,
      bool Function(X509Certificate)? onBadCertificate}) async {
    final serverContext = SecurityContext(withTrustedRoots: false)
      ..useCertificateChain(_certificate)
      ..usePrivateKey(_key);
    final serverSide = server.startTls(serverContext);
    // If the client refuses, the server fails too, and nobody is waiting.
    serverSide.then((_) {}, onError: (_) {});

    final client = server.client;
    await client.exchange(
        () => client.startTls(
            host: host, context: context, onBadCertificate: onBadCertificate),
        _timeout);
    await serverSide;
  }

  /// Send a packet each way, to show the connection works.
  Future<void> expectConnectionWorks() async {
    final client = server.client;
    final exchange = client.exchange(() async {
      client.send(Uint8List.fromList([1, 2, 3]));
      return (await client.next()).payload;
    }, _timeout);
    expect((await server.nextRequest()).payload, equals([1, 2, 3]));
    server.send([
      [4, 5, 6]
    ]);
    expect(await exchange, equals([4, 5, 6]));
  }

  SecurityContext trusting(String certificate) =>
      SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificates(certificate);

  test('a certificate nobody vouches for is refused', () async {
    await expectLater(
        startTls(host: 'localhost'), throwsA(isA<HandshakeException>()));
  });

  test('a certificate the context trusts is accepted', () async {
    await startTls(host: 'localhost', context: trusting(_certificate));
    await expectConnectionWorks();
  });

  test('a trusted certificate for another host is refused', () async {
    await expectLater(
        startTls(host: 'db.example.com', context: trusting(_certificate)),
        throwsA(isA<HandshakeException>()));
  });

  test('a refused certificate is put to onBadCertificate', () async {
    final asked = <X509Certificate>[];
    await startTls(
        host: 'localhost',
        onBadCertificate: (certificate) {
          asked.add(certificate);
          return true;
        });
    expect(asked.single.subject, contains('localhost'));
    await expectConnectionWorks();
  });

  test('onBadCertificate can refuse it too', () async {
    await expectLater(
        startTls(host: 'localhost', onBadCertificate: (_) => false),
        throwsA(isA<HandshakeException>()));
  });

  test('a trusted certificate is not put to onBadCertificate', () async {
    var asked = false;
    await startTls(
        host: 'localhost',
        context: trusting(_certificate),
        onBadCertificate: (_) {
          asked = true;
          return false;
        });
    expect(asked, isFalse);
  });

  // The whole of a login which asks for TLS: the greeting and the request
  // for TLS in the clear, and everything after it inside.
  group('a handshake which asks for TLS', () {
    SecurityContext serverContext() => SecurityContext(withTrustedRoots: false)
      ..useCertificateChain(_certificate)
      ..usePrivateKey(_key);

    Future<void> logIn(
        {String? db,
        SecurityContext? context,
        bool Function(X509Certificate)? onBadCertificate}) {
      final client = server.client;
      return client.exchange(
          () => handshake(client,
              user: 'username',
              password: 'password',
              db: db,
              maxPacketSize: 1024,
              characterSet: CharacterSet.UTF8MB4,
              useSSL: true,
              isSecure: false,
              host: 'localhost',
              securityContext: context,
              onBadCertificate: onBadCertificate),
          _timeout);
    }

    test('logs in over TLS when the certificate is trusted', () async {
      final done = logIn(context: trusting(_certificate));
      server.send([_greeting()], sequenceId: 0);

      // Asked for in the clear: the start of a handshake response, with the
      // flag set and nothing about who is logging in.
      final request = await server.nextRequest();
      expect(request.sequenceId, equals(1));
      expect(request.payload, hasLength(32));
      final flags = PayloadReader(request.payload).readUint32();
      expect(flags & Capability.ssl.bit, isNot(0));

      await server.startTls(serverContext());

      final response = PayloadReader((await server.nextRequest()).payload);
      response.skip(32);
      expect(response.readNullTerminatedString(), equals('username'));

      // The connection is now one nobody else can read, so the password
      // itself can be asked for and is sent.
      server.send([
        [Packet.authMoreData, cachingSha2PerformFullAuthentication]
      ], sequenceId: 3);
      final password = await server.nextRequest();
      expect(password.payload, equals([...utf8.encode('password'), 0]));

      server.send([
        [Packet.ok, 0, 0, 2, 0, 0, 0]
      ], sequenceId: 5);
      await done;
    });

    // The server goes by the flags in the request for TLS, so a database
    // which is only flagged in the response after it is not selected.
    test('says in both packets that it names a database', () async {
      final done = logIn(db: 'db', context: trusting(_certificate));
      server.send([_greeting()], sequenceId: 0);

      final request = PayloadReader((await server.nextRequest()).payload);
      final requestFlags = request.readUint32();
      expect(requestFlags & Capability.connectWithDb.bit, isNot(0));

      await server.startTls(serverContext());
      final response = PayloadReader((await server.nextRequest()).payload);
      expect(response.readUint32(), equals(requestFlags));

      server.send([
        [Packet.ok, 0, 0, 2, 0, 0, 0]
      ], sequenceId: 3);
      await done;
    });

    test('does not log in to a server which cannot do TLS', () async {
      final done = logIn(context: trusting(_certificate));
      server.send([_greeting(tls: false)], sequenceId: 0);

      await expectLater(
          done,
          throwsA(isA<MySqlClientError>()
              .having((e) => e.message, 'message', contains('TLS'))));

      // Nothing was sent: not who is logging in, and not a hash of the
      // password.
      server.client.close();
      await expectLater(server.nextRequest(), throwsA(isA<SocketException>()));
    });

    // The client begins the TLS handshake as soon as it has asked for TLS,
    // so the start of the handshake can be in the same read as the request.
    // The server has to hand what it has read ahead to TLS, or the handshake
    // waits forever at both ends. The wait is what lets the client get ahead.
    test('logs in when the server reads the request for TLS late', () async {
      final done = logIn(context: trusting(_certificate));
      server.send([_greeting()], sequenceId: 0);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await server.nextRequest();
      await server.startTls(serverContext());
      await server.nextRequest();
      server.send([
        [Packet.ok, 0, 0, 2, 0, 0, 0]
      ], sequenceId: 3);
      await done;
    });

    // The client has the same problem the other way round. A server never
    // sends more than the greeting before TLS, so rather than hand anything
    // over the client refuses to go on.
    test('does not start TLS if the server has sent more than the greeting',
        () async {
      final done = logIn(context: trusting(_certificate));
      server.send([
        _greeting(),
        [1, 2, 3]
      ], sequenceId: 0);

      await expectLater(done, throwsA(isA<MySqlProtocolError>()));
      expect(server.client.isClosed, isTrue);
    });

    test('does not log in when the certificate is not trusted', () async {
      final done = logIn();
      server.send([_greeting()], sequenceId: 0);
      await server.nextRequest();
      server.startTls(serverContext()).then((_) {}, onError: (_) {});

      await expectLater(done, throwsA(isA<HandshakeException>()));
      expect(server.client.isClosed, isTrue);
    });

    test('logs in when onBadCertificate accepts the certificate', () async {
      final done = logIn(onBadCertificate: (_) => true);
      server.send([_greeting()], sequenceId: 0);
      await server.nextRequest();
      await server.startTls(serverContext());
      await server.nextRequest();
      server.send([
        [Packet.ok, 0, 0, 2, 0, 0, 0]
      ], sequenceId: 3);
      await done;
    });
  });
}
