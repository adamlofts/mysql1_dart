library mysql1.auth_handler;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';

import '../constants.dart';
import '../buffer.dart';
import '../handlers/handler.dart';

class AuthHandler extends Handler {
  static const MYSQL_NATIVE_PASSWORD = 'mysql_native_password';
  static const CACHING_SHA2_PASSWORD = "caching_sha2_password";

  final String? username;
  final String? password;
  final String? db;
  final String? plugin;
  final List<int> scrambleBuffer;
  final int clientFlags;
  final int maxPacketSize;
  final int characterSet;
//  final bool _ssl;

  AuthHandler(this.username, this.password, this.db, this.scrambleBuffer,
      this.clientFlags, this.maxPacketSize, this.characterSet, this.plugin,
      {bool ssl = false})
      : /*this._ssl = false,*/
        super(Logger('AuthHandler'));

  List<int> getHash() {
    List<int> hash;
    if (password == null) {
      hash = <int>[];
    } else {
      if (plugin == MYSQL_NATIVE_PASSWORD) {
        final hashedPassword = sha1.convert(utf8.encode(password!)).bytes;
        final doubleHashedPassword = sha1.convert(hashedPassword).bytes;

        final bytes = List<int>.from(scrambleBuffer)
          ..addAll(doubleHashedPassword);
        final hashedSaltedPassword = sha1.convert(bytes).bytes;

        hash = List<int>.generate(hashedSaltedPassword.length,
            (index) => hashedSaltedPassword[index] ^ hashedPassword[index]);
      } else {
        final List<int> shaPwd = sha256.convert(utf8.encode(password!)).bytes;
        final List<int> shaShaPwd = sha256.convert(shaPwd).bytes;
        hash =
            sha256.convert(List.from(shaShaPwd)..addAll(scrambleBuffer)).bytes;
        for (int i = 0; i < hash.length; i++) hash[i] ^= shaPwd[i];
      }
    }
    return hash;
  }

  @override
  Buffer createRequest() {
    // calculate the mysql password hash
    var hash = getHash();

    var encodedUsername = username == null ? <int>[] : utf8.encode(username!);
    late List<int> encodedDb;

    var size = hash.length + encodedUsername.length + 2 + 32;
    var clientFlags = this.clientFlags;
    if (db != null) {
      encodedDb = utf8.encode(db!);
      size += encodedDb.length + 1;
      clientFlags |= CLIENT_CONNECT_WITH_DB;
    }

    var buffer = Buffer(size);
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
