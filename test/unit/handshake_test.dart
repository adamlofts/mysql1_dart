library mysql1.handshake_test;

import 'dart:async';
import 'dart:convert';

import 'package:mysql1/mysql1.dart';
import 'package:mysql1/src/handshake.dart';
import 'package:mysql1/src/buffer.dart';
import 'package:mysql1/src/constants.dart';
import 'package:test/test.dart';

import 'fake_server.dart';

const int MAX_PACKET_SIZE = 16 * 1024 * 1024;

Buffer _createHandshake(protocolVersion, serverVersion, threadId,
    scrambleBuffer, serverCapabilities,
    [serverLanguage,
    serverStatus,
    serverCapabilities2,
    scrambleLength,
    scrambleBuffer2,
    pluginName,
    pluginNameNull]) {
  var length = 1 + (serverVersion.length as int) + 1 + 4 + 8 + 1 + 2;
  if (serverLanguage != null) {
    length += 1 + 2 + 2 + 1 + 10;
    if (scrambleBuffer2 != null) {
      length += (scrambleBuffer2.length as int) + 1;
    }
    if (pluginName != null) {
      length += pluginName.length as int;
      if (pluginNameNull) {
        length++;
      }
    }
  }

  var response = Buffer(length);
  response.writeByte(protocolVersion);
  response.writeNullTerminatedList(serverVersion.codeUnits);
  response.writeInt32(threadId);
  response.writeList(scrambleBuffer.codeUnits);
  response.writeByte(0);
  response.writeInt16(serverCapabilities);
  if (serverLanguage != null) {
    response.writeByte(serverLanguage);
    response.writeInt16(serverStatus);
    response.writeInt16(serverCapabilities2);
    response.writeByte(scrambleLength);
    response.fill(10, 0);
    if (scrambleBuffer2 != null) {
      response.writeNullTerminatedList(scrambleBuffer2.codeUnits);
    }
    if (pluginName != null) {
      response.writeList(pluginName.codeUnits);
      if (pluginNameNull) {
        response.writeByte(0);
      }
    }
  }
  return response;
}

const _scramble1 = 'abcdefgh';
const _scramble2 = 'ijklmnopqrstuvwxyz';

/// A greeting from a server whose default plugin is [plugin].
Buffer _greeting(AuthPlugin plugin) => _createHandshake(
    10,
    'version 1',
    123882394,
    _scramble1,
    CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION,
    9,
    999,
    CLIENT_PLUGIN_AUTH >> 0x10,
    _scramble1.length + _scramble2.length + 1,
    _scramble2,
    authPluginToString(plugin),
    true);

void main() {
  group('parseGreeting', () {
    test('throws if handshake protocol is not 10', () {
      var response = Buffer.fromList([9]);
      expect(() {
        parseGreeting(response);
      }, throwsA(isA<MySqlClientError>()));
    });

    test('set values and does not throw if handshake protocol is 10', () {
      var serverVersion = 'version 1';
      var threadId = 123882394;
      var serverLanguage = 9;
      var serverStatus = 999;
      var serverCapabilities1 = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;
      var serverCapabilities2 = 0;
      var scrambleBuffer1 = 'abcdefgh';
      var scrambleBuffer2 = 'ijklmnopqrstuvwxyz';
      var scrambleLength = scrambleBuffer1.length + scrambleBuffer2.length + 1;
      var responseBuffer = _createHandshake(
          10,
          serverVersion,
          threadId,
          scrambleBuffer1,
          serverCapabilities1,
          serverLanguage,
          serverStatus,
          serverCapabilities2,
          scrambleLength,
          scrambleBuffer2);
      final greeting = parseGreeting(responseBuffer);

      expect(greeting.serverVersion, equals(serverVersion));
      expect(greeting.threadId, equals(threadId));
      expect(greeting.serverLanguage, equals(serverLanguage));
      expect(greeting.serverStatus, equals(serverStatus));
      expect(greeting.serverCapabilities, equals(serverCapabilities1));
      expect(greeting.scrambleLength, equals(scrambleLength));
      expect(greeting.scrambleBuffer,
          equals((scrambleBuffer1 + scrambleBuffer2).codeUnits));
    });

    test('should cope with no data past first capability flags', () {
      var serverVersion = 'version 1';
      var scrambleBuffer1 = 'abcdefgh';
      var threadId = 123882394;
      var serverCapabilities = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;

      var responseBuffer = _createHandshake(
          10, serverVersion, threadId, scrambleBuffer1, serverCapabilities);

      final greeting = parseGreeting(responseBuffer);

      expect(greeting.serverVersion, equals(serverVersion));
      expect(greeting.threadId, equals(threadId));
      expect(greeting.serverCapabilities, equals(serverCapabilities));
      expect(greeting.serverLanguage, equals(null));
      expect(greeting.serverStatus, equals(null));
    });

    test('should read plugin name', () {
      var serverVersion = 'version 1';
      var threadId = 123882394;
      var serverLanguage = 9;
      var serverStatus = 999;
      var serverCapabilities1 = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;
      var serverCapabilities2 = CLIENT_PLUGIN_AUTH >> 0x10;
      var scrambleBuffer1 = 'abcdefgh';
      var scrambleBuffer2 = 'ijklmnopqrstuvwxyz';
      var scrambleLength = scrambleBuffer1.length + scrambleBuffer2.length + 1;
      var pluginName = 'mysql_native_password';
      var responseBuffer = _createHandshake(
          10,
          serverVersion,
          threadId,
          scrambleBuffer1,
          serverCapabilities1,
          serverLanguage,
          serverStatus,
          serverCapabilities2,
          scrambleLength,
          scrambleBuffer2,
          pluginName,
          false);
      final greeting = parseGreeting(responseBuffer);

      expect(greeting.authPlugin, equals(AuthPlugin.mysqlNativePassword));
    });

    test('should read plugin name with null', () {
      var serverVersion = 'version 1';
      var threadId = 123882394;
      var serverLanguage = 9;
      var serverStatus = 999;
      var serverCapabilities1 = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;
      var serverCapabilities2 = CLIENT_PLUGIN_AUTH >> 0x10;
      var scrambleBuffer1 = 'abcdefgh';
      var scrambleBuffer2 = 'ijklmnopqrstuvwxyz';
      var scrambleLength = scrambleBuffer1.length + scrambleBuffer2.length + 1;
      var pluginName = 'mysql_native_password';
      var responseBuffer = _createHandshake(
          10,
          serverVersion,
          threadId,
          scrambleBuffer1,
          serverCapabilities1,
          serverLanguage,
          serverStatus,
          serverCapabilities2,
          scrambleLength,
          scrambleBuffer2,
          pluginName,
          true);
      final greeting = parseGreeting(responseBuffer);

      expect(greeting.authPlugin, equals(AuthPlugin.mysqlNativePassword));
    });

    test('should read buffer without scramble data', () {
      var serverVersion = 'version 1';
      var threadId = 123882394;
      var serverLanguage = 9;
      var serverStatus = 999;
      var serverCapabilities1 = CLIENT_PROTOCOL_41;
      var serverCapabilities2 = CLIENT_PLUGIN_AUTH >> 0x10;
      var scrambleBuffer1 = 'abcdefgh';
      String? scrambleBuffer2;
      var scrambleLength = scrambleBuffer1.length;
      var pluginName = 'caching_sha2_password';
      var responseBuffer = _createHandshake(
          10,
          serverVersion,
          threadId,
          scrambleBuffer1,
          serverCapabilities1,
          serverLanguage,
          serverStatus,
          serverCapabilities2,
          scrambleLength,
          scrambleBuffer2,
          pluginName,
          true);
      final greeting = parseGreeting(responseBuffer);

      expect(greeting.authPlugin, equals(AuthPlugin.cachingSha2Password));
    });

    test('should read buffer with short scramble data length', () {
      var serverVersion = 'version 1';
      var threadId = 123882394;
      var serverLanguage = 9;
      var serverStatus = 999;
      var serverCapabilities1 = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;
      var serverCapabilities2 = CLIENT_PLUGIN_AUTH >> 0x10;
      var scrambleBuffer1 = 'abcdefgh';
      var scrambleBuffer2 = 'ijklmnopqrst';
      var scrambleLength = 5;
      var pluginName = 'mysql_native_password';
      var responseBuffer = _createHandshake(
          10,
          serverVersion,
          threadId,
          scrambleBuffer1,
          serverCapabilities1,
          serverLanguage,
          serverStatus,
          serverCapabilities2,
          scrambleLength,
          scrambleBuffer2,
          pluginName,
          true);
      final greeting = parseGreeting(responseBuffer);

      expect(greeting.authPlugin, equals(AuthPlugin.mysqlNativePassword));
    });
  });

  group('clientCapabilities', () {
    ServerGreeting greeting(int capabilities1, [int capabilities2 = 0]) =>
        parseGreeting(_createHandshake(10, 'version 1', 123, 'abcdefgh',
            capabilities1, 9, 999, capabilities2, 21, 'ijklmnopqrstuvwxyz'));

    const base = CLIENT_PROTOCOL_41 |
        CLIENT_LONG_PASSWORD |
        CLIENT_LONG_FLAG |
        CLIENT_TRANSACTIONS |
        CLIENT_SECURE_CONNECTION |
        CLIENT_MULTI_RESULTS;

    test('throws if server protocol is not 4.1', () {
      expect(() => clientCapabilities(greeting(0), useSSL: false),
          throwsA(isA<MySqlClientError>()));
    });

    test('throws if old password authentication is requested', () {
      expect(
          () => clientCapabilities(greeting(CLIENT_PROTOCOL_41), useSSL: false),
          throwsA(isA<MySqlClientError>()));
    });

    test('the flags for a server with nothing optional', () {
      final flags = clientCapabilities(
          greeting(CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION),
          useSSL: false);
      expect(flags, equals(base));
    });

    test('names the plugin if the server does', () {
      final flags = clientCapabilities(
          parseGreeting(_greeting(AuthPlugin.mysqlNativePassword)),
          useSSL: false);
      expect(flags, equals(base | CLIENT_PLUGIN_AUTH));
    });

    test('asks for ssl if it is wanted and the server has it', () {
      final flags = clientCapabilities(
          greeting(CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION | CLIENT_SSL),
          useSSL: true);
      expect(flags, equals(base | CLIENT_SSL));
    });

    test('does not ask for ssl if it is not wanted', () {
      final flags = clientCapabilities(
          greeting(CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION | CLIENT_SSL),
          useSSL: false);
      expect(flags, equals(base));
    });

    // Not a connection without it: the greeting is sent in the clear, and
    // whoever can change it could turn TLS off.
    test('throws if ssl is wanted and the server does not have it', () {
      expect(
          () => clientCapabilities(
              greeting(CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION),
              useSSL: true),
          throwsA(isA<MySqlClientError>()
              .having((e) => e.message, 'message', contains('TLS'))));
    });
  });

  group('packets', () {
    test('the hash for mysql_native_password', () {
      expect(
          authHash(AuthPlugin.mysqlNativePassword, [1, 2, 3, 4], 'password'),
          equals([
            211, 136, 65, 109, 153, 241, 227, 117, 168, 83, //
            80, 136, 188, 116, 50, 54, 235, 225, 54, 225
          ]));
    });

    test('the hash for caching_sha2_password is a sha256', () {
      final hash =
          authHash(AuthPlugin.cachingSha2Password, [1, 2, 3, 4], 'password');
      expect(hash, hasLength(32));
      expect(
          hash,
          isNot(equals(authHash(
              AuthPlugin.cachingSha2Password, [4, 3, 2, 1], 'password'))));
    });

    test('no password is no hash', () {
      expect(authHash(AuthPlugin.cachingSha2Password, [1, 2, 3, 4], null),
          isEmpty);
    });

    test('a handshake response with no database', () {
      var clientFlags = 12345;
      var hash = authHash(AuthPlugin.mysqlNativePassword, [1, 2, 3, 4], 'Pass');
      var buffer = handshakeResponse(
          clientFlags: clientFlags,
          maxPacketSize: 9898,
          characterSet: 56,
          username: 'Boris',
          hash: hash,
          db: null,
          authPlugin: AuthPlugin.mysqlNativePassword);

      buffer.seek(0);
      expect(buffer.readUint32(), equals(clientFlags));
      expect(buffer.readUint32(), equals(9898));
      expect(buffer.readByte(), equals(56));
      buffer.skip(23);
      expect(buffer.readNullTerminatedString(), equals('Boris'));
      expect(buffer.readByte(), equals(hash.length));
      expect(buffer.readList(hash.length), equals(hash));
      expect(buffer.hasMore, isFalse);
    });

    test('a handshake response with a database', () {
      var clientFlags = 2435623 & ~CLIENT_CONNECT_WITH_DB;
      var hash = authHash(AuthPlugin.mysqlNativePassword,
          [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], 'wibblededee');
      var buffer = handshakeResponse(
          clientFlags: clientFlags,
          maxPacketSize: 34536,
          characterSet: 255,
          username: 'iamtheuserwantingtologin',
          hash: hash,
          db: 'thisisthenameofthedatabase',
          authPlugin: AuthPlugin.mysqlNativePassword);

      buffer.seek(0);
      expect(buffer.readUint32(), equals(clientFlags | CLIENT_CONNECT_WITH_DB));
      expect(buffer.readUint32(), equals(34536));
      expect(buffer.readByte(), equals(255));
      buffer.skip(23);
      expect(buffer.readNullTerminatedString(),
          equals('iamtheuserwantingtologin'));
      expect(buffer.readByte(), equals(hash.length));
      expect(buffer.readList(hash.length), equals(hash));
      expect(buffer.readNullTerminatedString(),
          equals('thisisthenameofthedatabase'));
      expect(buffer.hasMore, isFalse);
    });

    test('a handshake response in utf8', () {
      var hash =
          authHash(AuthPlugin.mysqlNativePassword, [1, 2, 3, 4], 'здрасти');
      var buffer = handshakeResponse(
          clientFlags: 0,
          maxPacketSize: 100,
          characterSet: 0,
          username: 'Борис',
          hash: hash,
          db: 'дтабасе',
          authPlugin: AuthPlugin.mysqlNativePassword);

      buffer.seek(0);
      buffer.skip(32);
      expect(buffer.readNullTerminatedString(), equals('Борис'));
      expect(buffer.readByte(), equals(hash.length));
      expect(buffer.readList(hash.length), equals(hash));
      expect(buffer.readNullTerminatedString(), equals('дтабасе'));
      expect(buffer.hasMore, isFalse);
    });

    test('an ssl request is the start of a handshake response', () {
      var buffer = sslRequest(12345, 9898, 56);
      expect(buffer.length, equals(32));
      buffer.seek(0);
      expect(buffer.readUint32(), equals(12345));
      expect(buffer.readUint32(), equals(9898));
      expect(buffer.readByte(), equals(56));
      expect(buffer.readList(23), everyElement(0));
    });

    test('a cleartext password is null terminated', () {
      expect(cleartextPassword('password').list,
          equals([...utf8.encode('password'), 0]));
      expect(cleartextPassword(null).list, equals([0]));
    });
  });

  // The conversation itself, against a server which says what each test
  // wants said. The greeting is packet 0, so the client's answer is 1, the
  // server's reply to that 2, and so on.
  group('handshake', () {
    late FakeServer server;

    setUp(() async {
      server = await FakeServer.start();
    });

    tearDown(() => server.close());

    /// Greet the client as a server whose default is [plugin], and return
    /// the handshake along with the client's answer.
    Future<(Future<void>, Buffer)> greet(
        {AuthPlugin plugin = AuthPlugin.cachingSha2Password,
        String? password = 'password',
        bool isSecure = false}) async {
      final client = server.client;
      final done = client.exchange(
          () => handshake(client,
              user: 'username',
              password: password,
              db: 'db',
              maxPacketSize: MAX_PACKET_SIZE,
              characterSet: CharacterSet.UTF8MB4,
              useSSL: false,
              isSecure: isSecure),
          const Duration(seconds: 5));
      server.send([_greeting(plugin).list], sequenceId: 0);
      final answer = await server.nextRequest();
      expect(answer.sequenceId, equals(1));
      return (done, Buffer.view(answer.payload));
    }

    /// affected rows, insert id, server status, warnings.
    const ok = [PACKET_OK, 0, 0, 2, 0, 0, 0];

    final accessDenied = [
      PACKET_ERROR,
      0x15,
      0x04, // 1045
      0x23, // '#'
      ...utf8.encode('28000'),
      ...utf8.encode('Access denied'),
    ];

    List<int> authMoreData(int status) => [PACKET_AUTH_MORE_DATA, status];

    /// `0xfe`, the plugin name, then a fresh scramble with a null terminator.
    List<int> authSwitchRequest(String plugin, List<int> scramble) => [
          PACKET_AUTH_SWITCH_REQUEST,
          ...utf8.encode(plugin),
          0,
          ...scramble,
          0,
        ];

    test('answers the greeting with who it is', () async {
      final (done, answer) = await greet();
      final hash = authHash(AuthPlugin.cachingSha2Password,
          '$_scramble1$_scramble2'.codeUnits, 'password');

      answer.seek(0);
      final flags = answer.readUint32();
      expect(flags & CLIENT_PLUGIN_AUTH, isNot(0));
      expect(flags & CLIENT_CONNECT_WITH_DB, isNot(0));
      expect(flags & CLIENT_SSL, equals(0));
      expect(answer.readUint32(), equals(MAX_PACKET_SIZE));
      expect(answer.readByte(), equals(CharacterSet.UTF8MB4));
      answer.skip(23);
      expect(answer.readNullTerminatedString(), equals('username'));
      expect(answer.readByte(), equals(hash.length));
      expect(answer.readList(hash.length), equals(hash));
      expect(answer.readNullTerminatedString(), equals('db'));
      expect(
          answer.readNullTerminatedString(), equals('caching_sha2_password'));
      expect(answer.hasMore, isFalse);

      server.send([ok], sequenceId: 2);
      await done;
    });

    test('an ok packet ends authentication', () async {
      final (done, _) = await greet();
      server.send([ok], sequenceId: 2);
      await done;
      expect(server.client.isClosed, isFalse);
    });

    test('an error packet throws', () async {
      final (done, _) = await greet();
      server.send([accessDenied], sequenceId: 2);
      await expectLater(
          done,
          throwsA(isA<MySqlException>()
              .having((e) => e.errorNumber, 'errorNumber', 1045)));
    });

    test('an error in place of the greeting throws', () async {
      final client = server.client;
      final done = client.exchange(
          () => handshake(client,
              user: 'username',
              password: 'password',
              db: 'db',
              maxPacketSize: MAX_PACKET_SIZE,
              characterSet: CharacterSet.UTF8MB4,
              useSSL: false,
              isSecure: false),
          const Duration(seconds: 5));
      server.send([accessDenied], sequenceId: 0);
      await expectLater(done, throwsA(isA<MySqlException>()));
    });

    // Finishing here is what used to leave the connection one packet behind
    // for the rest of its life.
    test('fast auth success waits for the ok packet which follows', () async {
      final (done, _) = await greet();
      var finished = false;
      unawaited(done.then((_) => finished = true));

      server
          .send([authMoreData(CACHING_SHA2_FAST_AUTH_SUCCESS)], sequenceId: 2);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(finished, isFalse);

      server.send([ok], sequenceId: 3);
      await done;
    });

    test('full authentication is refused when anyone could read it', () async {
      final (done, _) = await greet(isSecure: false);
      server.send([authMoreData(CACHING_SHA2_PERFORM_FULL_AUTHENTICATION)],
          sequenceId: 2);
      await expectLater(
          done,
          throwsA(isA<MySqlClientError>().having(
              (e) => e.message, 'message', contains('full authentication'))));
    });

    test('full authentication sends the password when nobody can read it',
        () async {
      final (done, _) = await greet(isSecure: true);
      server.send([authMoreData(CACHING_SHA2_PERFORM_FULL_AUTHENTICATION)],
          sequenceId: 2);

      final password = await server.nextRequest();
      expect(password.sequenceId, equals(3));
      expect(password.payload, equals([...utf8.encode('password'), 0]));

      server.send([ok], sequenceId: 4);
      await done;
    });

    test('full authentication with no password sends just the terminator',
        () async {
      final (done, _) = await greet(password: null, isSecure: true);
      server.send([authMoreData(CACHING_SHA2_PERFORM_FULL_AUTHENTICATION)],
          sequenceId: 2);

      expect((await server.nextRequest()).payload, equals([0]));
      server.send([ok], sequenceId: 4);
      await done;
    });

    test('an unknown auth status throws', () async {
      final (done, _) = await greet();
      server.send([authMoreData(0x09)], sequenceId: 2);
      await expectLater(done, throwsA(isA<MySqlClientError>()));
    });

    test('auth data for a plugin which does not send any throws', () async {
      final (done, _) = await greet(plugin: AuthPlugin.mysqlNativePassword);
      server
          .send([authMoreData(CACHING_SHA2_FAST_AUTH_SUCCESS)], sequenceId: 2);
      await expectLater(done, throwsA(isA<MySqlClientError>()));
    });

    // The account uses mysql_native_password even though the server named
    // caching_sha2_password in the greeting.
    test('an auth switch request is answered with the new plugin and scramble',
        () async {
      final (done, _) = await greet();
      final scramble = [9, 8, 7, 6, 5];
      server.send([authSwitchRequest('mysql_native_password', scramble)],
          sequenceId: 2);

      // The bare hash, built from the new plugin and scramble.
      final answer = await server.nextRequest();
      expect(answer.sequenceId, equals(3));
      expect(
          answer.payload,
          equals(
              authHash(AuthPlugin.mysqlNativePassword, scramble, 'password')));

      server.send([ok], sequenceId: 4);
      await done;
    });

    test('an auth switch request can also switch to caching_sha2_password',
        () async {
      final (done, _) = await greet(plugin: AuthPlugin.mysqlNativePassword);
      final scramble = [9, 8, 7, 6, 5];
      server.send([authSwitchRequest('caching_sha2_password', scramble)],
          sequenceId: 2);

      expect(
          (await server.nextRequest()).payload,
          equals(
              authHash(AuthPlugin.cachingSha2Password, scramble, 'password')));

      // Having switched, the data this plugin sends is understood.
      server
          .send([authMoreData(CACHING_SHA2_FAST_AUTH_SUCCESS)], sequenceId: 4);
      server.send([ok], sequenceId: 5);
      await done;
    });

    test('a switch to an unsupported plugin throws', () async {
      final (done, _) = await greet();
      server.send([
        authSwitchRequest('sha256_password', [1, 2])
      ], sequenceId: 2);
      await expectLater(done, throwsA(isA<MySqlClientError>()));
    });

    test('a bare switch request asks for old password authentication',
        () async {
      final (done, _) = await greet();
      server.send([
        [PACKET_AUTH_SWITCH_REQUEST]
      ], sequenceId: 2);
      await expectLater(
          done,
          throwsA(isA<MySqlClientError>()
              .having((e) => e.message, 'message', contains('Old Password'))));
    });

    test('a packet which is none of these throws', () async {
      final (done, _) = await greet();
      server.send([
        [0x42, 1, 2]
      ], sequenceId: 2);
      await expectLater(done, throwsA(isA<MySqlClientError>()));
    });
  });
}
