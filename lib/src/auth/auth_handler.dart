library mysql1.auth_handler;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:mysql1/src/auth/handshake_handler.dart';

import '../constants.dart';
import '../buffer.dart';
import '../handlers/handler.dart';

List<int> _makeMysqlNativePassword(List<int> scrambler, String password) {
  // SHA1(password)
  final shaPwd = sha1.convert(utf8.encode(password)).bytes;
  // SHA1(SHA1(password))
  final shaShaPwd = sha1.convert(shaPwd).bytes;

  final bytes = List<int>.from(scrambler)..addAll(shaShaPwd);

  // SHA1(scramble, SHA1(SHA1(password)))
  final hash = sha1.convert(bytes).bytes;

  // XOR(SHA1(password), SHA1(scramble, SHA1(SHA1(password))))
  for (var i = 0; i < hash.length; i++) {
    hash[i] ^= shaPwd[i];
  }
  return hash;
}

/// Hash password using MySQL 8+ method (SHA256)
/// XOR(SHA256(password), SHA256(SHA256(SHA256(password)), scramble))
List<int> _makeCachingSha2Password(List<int> scrambler, String password) {
  // SHA256(password)
  final shaPwd = sha256.convert(utf8.encode(password)).bytes;
  // SHA256(SHA256(password))
  final shaShaPwd = sha256.convert(shaPwd).bytes;
  // SHA256(SHA256(SHA256(password)), scramble)
  final res = sha256.convert(List.from(shaShaPwd)..addAll(scrambler)).bytes;
  // XOR(SHA256(password), SHA256(SHA256(SHA256(password)), scramble))
  for (var i = 0; i < res.length; i++) {
    res[i] ^= shaPwd[i];
  }
  return res;
}

class AuthHandler extends Handler {
  final String? username;
  final String? password;
  final String? db;
  final List<int> scrambleBuffer;
  final int clientFlags;
  final int maxPacketSize;
  final int characterSet;
  final AuthPlugin authPlugin;
//  final bool _ssl;

  AuthHandler(this.username, this.password, this.db, this.scrambleBuffer,
      this.clientFlags, this.maxPacketSize, this.characterSet, this.authPlugin,
      {bool ssl = false})
      : /*this._ssl = false,*/
        super(Logger('AuthHandler'));

  List<int> getHash() {
    List<int> hash;
    if (password == null) {
      hash = <int>[];
    } else if (authPlugin == AuthPlugin.cachingSha2Password) {
      hash = _makeCachingSha2Password(scrambleBuffer, password!);
    } else {
      hash = _makeMysqlNativePassword(scrambleBuffer, password!);
    }
    return hash;
  }

  @override
  Buffer createRequest() {
    // calculate the mysql password hash
    var hash = getHash();

    var encodedUsername = username == null ? <int>[] : utf8.encode(username!);
    late List<int> encodedDb;
    var encodedAuth = <int>[];

    var size = hash.length + encodedUsername.length + 2 + 32;
    var clientFlags = this.clientFlags;
    if (db != null) {
      encodedDb = utf8.encode(db!);
      size += encodedDb.length + 1;
      clientFlags |= CLIENT_CONNECT_WITH_DB;
    }
    if (clientFlags & CLIENT_PLUGIN_AUTH > 0) {
      encodedAuth = utf8.encode(authPluginToString(authPlugin));
      size += encodedAuth.length + 1;
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
    if (encodedAuth.isNotEmpty) {
      buffer.writeNullTerminatedList(encodedAuth);
    }

    return buffer;
  }
}
