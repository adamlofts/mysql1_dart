library sqljocky.auth_handler;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';

import '../../constants.dart';
import '../buffer.dart';
import '../handlers/handler.dart';

class AuthHandler extends Handler {
  final String username;
  final String password;
  final String db;
  final List<int> scrambleBuffer;
  final int clientFlags;
  final int maxPacketSize;
  final int characterSet;
//  final bool _ssl;

  AuthHandler(
      String this.username,
      String this.password,
      String this.db,
      List<int> this.scrambleBuffer,
      int this.clientFlags,
      int this.maxPacketSize,
      int this.characterSet,
      {bool ssl: false})
      : /*this._ssl = false,*/
        super(new Logger("AuthHandler"));

  List<int> getHash() {
    List<int> hash;
    if (password == null) {
      hash = <int>[];
    } else {
      final hashedPassword = sha1.convert(UTF8.encode(password)).bytes;
      final doubleHashedPassword = sha1.convert(hashedPassword).bytes;

      final bytes = new List<int>.from(scrambleBuffer)
        ..addAll(doubleHashedPassword);
      final hashedSaltedPassword = sha1.convert(bytes).bytes;

      hash = new List<int>(hashedSaltedPassword.length);
      for (var i = 0; i < hash.length; i++) {
        hash[i] = hashedSaltedPassword[i] ^ hashedPassword[i];
      }
    }
    return hash;
  }

  Buffer createRequest() {
    // calculate the mysql password hash
    var hash = getHash();

    var encodedUsername = username == null ? [] : UTF8.encode(username);
    var encodedDb;

    var size = hash.length + encodedUsername.length + 2 + 32;
    var clientFlags = this.clientFlags;
    if (db != null) {
      encodedDb = UTF8.encode(db);
      size += encodedDb.length + 1;
      clientFlags |= CLIENT_CONNECT_WITH_DB;
    }

    var buffer = new Buffer(size);
    buffer.seekWrite(0);
    buffer.writeUint32(clientFlags);
    buffer.writeUint32(maxPacketSize);
    buffer.writeByte(characterSet);
    buffer.fill(23, 0);
    buffer.writeNullTerminatedList(encodedUsername);
    buffer.writeByte(hash.length);
    buffer.writeList(hash);

    if (db != null) {
      buffer.writeNullTerminatedList(encodedDb);
    }

    return buffer;
  }
}
