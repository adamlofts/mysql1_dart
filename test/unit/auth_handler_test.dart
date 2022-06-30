library mysql1.auth_handler_test;

import 'package:mysql1/src/auth/auth_handler.dart';
import 'package:mysql1/src/auth/handshake_handler.dart';
import 'package:mysql1/src/constants.dart';

import 'package:test/test.dart';

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
