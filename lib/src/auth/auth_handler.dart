library mysql1.auth_handler;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:mysql1/src/auth/handshake_handler.dart';

import '../constants.dart';
import '../buffer.dart';
import '../handlers/handler.dart';
import '../mysql_client_error.dart';

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

/// Which packet [AuthHandler.createRequest] should build next.
enum _Stage {
  handshakeResponse,
  authSwitchResponse,
  cleartextPassword,
}

class AuthHandler extends Handler {
  final String? username;
  final String? password;
  final String? db;
  final int clientFlags;
  final int maxPacketSize;
  final int characterSet;

  /// The seed the hash is built from. Replaced if the server sends an auth
  /// switch request, which carries a fresh one.
  List<int> scrambleBuffer;

  /// Replaced if the server sends an auth switch request. The plugin named in
  /// the initial handshake is the server's default, which is not necessarily
  /// the one the account uses.
  AuthPlugin authPlugin;

  /// Whether a third party can read the connection. False for plain TCP, and
  /// the reason full authentication cannot send the password in the clear
  /// there.
  final bool isSecure;

  _Stage _stage = _Stage.handshakeResponse;

  AuthHandler(this.username, this.password, this.db, this.scrambleBuffer,
      this.clientFlags, this.maxPacketSize, this.characterSet, this.authPlugin,
      {this.isSecure = false})
      : super(Logger('AuthHandler'));

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
    switch (_stage) {
      case _Stage.handshakeResponse:
        return _createHandshakeResponse();
      case _Stage.authSwitchResponse:
        return _createAuthSwitchResponse();
      case _Stage.cleartextPassword:
        return _createCleartextPassword();
    }
  }

  /// The reply to an auth switch request is the bare authentication data for
  /// the plugin the server named, with no header of its own.
  Buffer _createAuthSwitchResponse() {
    final hash = getHash();
    final buffer = Buffer(hash.length);
    buffer.writeList(hash);
    return buffer;
  }

  /// The reply to a full authentication request on a connection nobody else
  /// can read: the password itself, null terminated.
  Buffer _createCleartextPassword() {
    final encoded = password == null ? <int>[] : utf8.encode(password!);
    final buffer = Buffer(encoded.length + 1);
    buffer.writeNullTerminatedList(encoded);
    return buffer;
  }

  Buffer _createHandshakeResponse() {
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

  /// Authentication is not one request and one response. The server can also
  /// ask for a different plugin, or for more data from the one in use, and
  /// only an ok or an error packet ends the exchange - so this must not use
  /// the default [processResponse], which treats anything it does not
  /// recognise as the end.
  @override
  HandlerResponse processResponse(Buffer response) {
    switch (response[0]) {
      case PACKET_OK:
      case PACKET_ERROR:
        // Returns the ok packet, or throws for an error packet.
        return HandlerResponse(finished: true, result: checkResponse(response));
      case PACKET_AUTH_SWITCH_REQUEST:
        return _handleAuthSwitchRequest(response);
      case PACKET_AUTH_MORE_DATA:
        return _handleAuthMoreData(response);
      default:
        throw MySqlClientError(
            'Unexpected packet type ${response[0]} during authentication');
    }
  }

  /// The account does not use the plugin named in the initial handshake, so
  /// the server has named the one it does use and sent a new seed.
  HandlerResponse _handleAuthSwitchRequest(Buffer response) {
    response.seek(1);

    if (!response.hasMore) {
      // A bare 0xfe asks for mysql_old_password, the pre-4.1 hash.
      throw MySqlClientError('Old Password Authentication is not supported');
    }

    // Throws for a plugin this driver cannot speak.
    authPlugin = authPluginFromString(response.readNullTerminatedString());

    var scramble = response.readListToEnd();
    if (scramble.isNotEmpty && scramble.last == 0) {
      scramble = scramble.sublist(0, scramble.length - 1);
    }
    scrambleBuffer = scramble;

    log.fine('Switching to ${authPluginToString(authPlugin)}');
    _stage = _Stage.authSwitchResponse;
    return HandlerResponse(nextHandler: this);
  }

  /// Data which only the plugin in use can interpret. Only
  /// caching_sha2_password sends any.
  HandlerResponse _handleAuthMoreData(Buffer response) {
    if (authPlugin != AuthPlugin.cachingSha2Password) {
      throw MySqlClientError('Unexpected auth data for '
          '${authPluginToString(authPlugin)} authentication');
    }

    response.seek(1);
    final status = response.readByte();

    switch (status) {
      case CACHING_SHA2_FAST_AUTH_SUCCESS:
        // The server had the password cached. It sends an ok packet next, so
        // this handler is not finished yet.
        log.fine('Fast authentication succeeded');
        return HandlerResponse.notFinished;

      case CACHING_SHA2_PERFORM_FULL_AUTHENTICATION:
        // The server wants the password itself. In the clear is only safe if
        // nobody else can read the connection; otherwise it has to be RSA
        // encrypted with the server's public key, which this driver cannot
        // do.
        if (!isSecure) {
          throw MySqlClientError(
              'The server asked for full authentication, which this driver '
              'can only do over a connection nobody else can read. Connect '
              'over a unix socket, or give the account the '
              'mysql_native_password plugin. A caching_sha2_password account '
              'with a password is asked for this until the server has cached '
              'it.');
        }
        log.fine('Sending cleartext password for full authentication');
        _stage = _Stage.cleartextPassword;
        return HandlerResponse(nextHandler: this);

      default:
        throw MySqlClientError(
            'Unknown caching_sha2_password auth status $status');
    }
  }
}
