library mysql1.auth_handler_test;

import 'dart:convert';

import 'package:mysql1/mysql1.dart' show MySqlClientError, MySqlException;
import 'package:mysql1/src/auth/auth_handler.dart';
import 'package:mysql1/src/auth/handshake_handler.dart';
import 'package:mysql1/src/buffer.dart';
import 'package:mysql1/src/constants.dart';
import 'package:mysql1/src/handlers/ok_packet.dart';

import 'package:test/test.dart';

AuthHandler _handler(
        {AuthPlugin plugin = AuthPlugin.cachingSha2Password,
        String? password = 'password',
        bool isSecure = false}) =>
    AuthHandler('username', password, 'db', [1, 2, 3, 4], 0, 100, 0, plugin,
        isSecure: isSecure);

/// `0xfe`, the plugin name, then a fresh scramble with a null terminator.
Buffer _authSwitchRequest(String plugin, List<int> scramble) =>
    Buffer.fromList([
      PACKET_AUTH_SWITCH_REQUEST,
      ...utf8.encode(plugin),
      0,
      ...scramble,
      0,
    ]);

Buffer _authMoreData(int status) =>
    Buffer.fromList([PACKET_AUTH_MORE_DATA, status]);

/// affected rows, insert id, server status, message.
Buffer _okPacket() => Buffer.fromList([PACKET_OK, 0, 0, 2, 0]);

Buffer _errorPacket() => Buffer.fromList([
      PACKET_ERROR,
      0x15,
      0x04, // 1045
      0x23, // '#'
      ...utf8.encode('28000'),
      ...utf8.encode('Access denied'),
    ]);

void main() {
  group('auth_handler:', () {
    test('hash password correctly', () {
      var handler = AuthHandler('username', 'password', 'db', [1, 2, 3, 4], 0,
          100, 0, AuthPlugin.mysqlNativePassword);

      var hash = handler.getHash();

      expect(
          hash,
          equals([
            211,
            136,
            65,
            109,
            153,
            241,
            227,
            117,
            168,
            83,
            80,
            136,
            188,
            116,
            50,
            54,
            235,
            225,
            54,
            225
          ]));
    });

    test('hash password correctly', () {
      var clientFlags = 12345;
      var maxPacketSize = 9898;
      var characterSet = 56;
      var username = 'Boris';
      var password = 'Password';
      var handler = AuthHandler(
          username,
          password,
          null,
          [1, 2, 3, 4],
          clientFlags,
          maxPacketSize,
          characterSet,
          AuthPlugin.mysqlNativePassword);

      var hash = handler.getHash();
      var buffer = handler.createRequest();

      buffer.seek(0);
      expect(buffer.readUint32(), equals(clientFlags));
      expect(buffer.readUint32(), equals(maxPacketSize));
      expect(buffer.readByte(), equals(characterSet));
      buffer.skip(23);
      expect(buffer.readNullTerminatedString(), equals(username));
      expect(buffer.readByte(), equals(hash.length));
      expect(buffer.readList(hash.length), equals(hash));
      expect(buffer.hasMore, isFalse);
    });

    test('check another set of values', () {
      var clientFlags = 2435623 & ~CLIENT_CONNECT_WITH_DB;
      var maxPacketSize = 34536;
      var characterSet = 255;
      var username = 'iamtheuserwantingtologin';
      var password = 'wibblededee';
      var database = 'thisisthenameofthedatabase';
      var handler = AuthHandler(
          username,
          password,
          database,
          [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
          clientFlags,
          maxPacketSize,
          characterSet,
          AuthPlugin.mysqlNativePassword);

      var hash = handler.getHash();
      var buffer = handler.createRequest();

      buffer.seek(0);
      expect(buffer.readUint32(), equals(clientFlags | CLIENT_CONNECT_WITH_DB));
      expect(buffer.readUint32(), equals(maxPacketSize));
      expect(buffer.readByte(), equals(characterSet));
      buffer.skip(23);
      expect(buffer.readNullTerminatedString(), equals(username));
      expect(buffer.readByte(), equals(hash.length));
      expect(buffer.readList(hash.length), equals(hash));
      expect(buffer.readNullTerminatedString(), equals(database));
      expect(buffer.hasMore, isFalse);
    });
  });

  group('auth_handler responses:', () {
    test('an ok packet ends authentication', () {
      final response = _handler().processResponse(_okPacket());

      expect(response.finished, isTrue);
      expect(response.result, isA<OkPacket>());
    });

    test('an error packet throws', () {
      expect(() => _handler().processResponse(_errorPacket()),
          throwsA(isA<MySqlException>()));
    });

    test('fast auth success waits for the ok packet which follows', () {
      final handler = _handler();

      final response = handler
          .processResponse(_authMoreData(CACHING_SHA2_FAST_AUTH_SUCCESS));

      // Not finished, no result, and nothing more to send: the ok packet is
      // still to come. Finishing here is what used to leave the connection
      // one packet behind for the rest of its life.
      expect(response.finished, isFalse);
      expect(response.hasResult, isFalse);
      expect(response.nextHandler, isNull);
    });

    test('full authentication is refused when anyone could read it', () {
      final handler = _handler(isSecure: false);

      expect(
          () => handler.processResponse(
              _authMoreData(CACHING_SHA2_PERFORM_FULL_AUTHENTICATION)),
          throwsA(isA<MySqlClientError>().having(
              (e) => e.message, 'message', contains('full authentication'))));
    });

    test('full authentication sends the password when nobody can read it', () {
      final handler = _handler(isSecure: true);

      final response = handler.processResponse(
          _authMoreData(CACHING_SHA2_PERFORM_FULL_AUTHENTICATION));
      expect(response.nextHandler, same(handler));

      final request = handler.createRequest();
      expect(request.list, equals([...utf8.encode('password'), 0]));
    });

    test('full authentication with no password sends just the terminator', () {
      final handler = _handler(password: null, isSecure: true);

      handler.processResponse(
          _authMoreData(CACHING_SHA2_PERFORM_FULL_AUTHENTICATION));

      expect(handler.createRequest().list, equals([0]));
    });

    test('an unknown auth status throws', () {
      expect(() => _handler().processResponse(_authMoreData(0x09)),
          throwsA(isA<MySqlClientError>()));
    });

    test('auth data for a plugin which does not send any throws', () {
      expect(
          () => _handler(plugin: AuthPlugin.mysqlNativePassword)
              .processResponse(_authMoreData(CACHING_SHA2_FAST_AUTH_SUCCESS)),
          throwsA(isA<MySqlClientError>()));
    });

    test('an auth switch request answers with the new plugin and scramble', () {
      // The account uses mysql_native_password even though the server named
      // caching_sha2_password in the handshake.
      final handler = _handler();
      final scramble = [9, 8, 7, 6, 5];

      final response = handler.processResponse(
          _authSwitchRequest('mysql_native_password', scramble));
      expect(response.nextHandler, same(handler));
      expect(handler.authPlugin, equals(AuthPlugin.mysqlNativePassword));
      expect(handler.scrambleBuffer, equals(scramble));

      // The reply is the bare hash, built from the new plugin and scramble.
      final expected = AuthHandler('username', 'password', 'db', scramble, 0,
              100, 0, AuthPlugin.mysqlNativePassword)
          .getHash();
      expect(handler.createRequest().list, equals(expected));
    });

    test('an auth switch request can also switch to caching_sha2_password', () {
      final handler = _handler(plugin: AuthPlugin.mysqlNativePassword);
      final scramble = [9, 8, 7, 6, 5];

      handler.processResponse(
          _authSwitchRequest('caching_sha2_password', scramble));

      expect(handler.authPlugin, equals(AuthPlugin.cachingSha2Password));
      final expected = AuthHandler('username', 'password', 'db', scramble, 0,
              100, 0, AuthPlugin.cachingSha2Password)
          .getHash();
      expect(handler.createRequest().list, equals(expected));
    });

    test('a switch to an unsupported plugin throws', () {
      expect(
          () => _handler()
              .processResponse(_authSwitchRequest('sha256_password', [1, 2])),
          throwsA(isA<MySqlClientError>()));
    });

    test('a bare switch request asks for old password authentication', () {
      expect(
          () => _handler()
              .processResponse(Buffer.fromList([PACKET_AUTH_SWITCH_REQUEST])),
          throwsA(isA<MySqlClientError>()
              .having((e) => e.message, 'message', contains('Old Password'))));
    });
  });

  test('check utf8', () {
    var username = 'Борис';
    var password = 'здрасти';
    var database = 'дтабасе';
    var handler = AuthHandler(username, password, database, [1, 2, 3, 4], 0,
        100, 0, AuthPlugin.mysqlNativePassword);

    var hash = handler.getHash();
    var buffer = handler.createRequest();

    buffer.seek(0);
    buffer.readUint32();
    buffer.readUint32();
    buffer.readByte();
    buffer.skip(23);
    expect(buffer.readNullTerminatedString(), equals(username));
    expect(buffer.readByte(), equals(hash.length));
    expect(buffer.readList(hash.length), equals(hash));
    expect(buffer.readNullTerminatedString(), equals(database));
    expect(buffer.hasMore, isFalse);
  });
}
