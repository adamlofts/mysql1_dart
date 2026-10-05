library mysql1.handshake;

import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import '../buffer.dart';
import '../constants.dart';
import '../mysql_client_error.dart';
import '../mysql_exception.dart';
import '../protocol_connection.dart';

enum AuthPlugin {
  none,
  mysqlNativePassword,
  cachingSha2Password,
}

AuthPlugin authPluginFromString(String v) {
  switch (v) {
    case 'mysql_native_password':
      return AuthPlugin.mysqlNativePassword;
    case 'caching_sha2_password':
      return AuthPlugin.cachingSha2Password;
    default:
      throw MySqlClientError('Authentication plugin not supported: $v');
  }
}

String authPluginToString(AuthPlugin v) {
  switch (v) {
    case AuthPlugin.mysqlNativePassword:
      return 'mysql_native_password';
    case AuthPlugin.cachingSha2Password:
      return 'caching_sha2_password';
    default:
      return '';
  }
}

/// What the server says about itself when a connection opens. It speaks
/// first.
class ServerGreeting {
  final int protocolVersion;
  final String serverVersion;
  final int threadId;

  /// The seed the password hash is built from.
  final List<int> scrambleBuffer;
  final int serverCapabilities;
  final int? serverLanguage;
  final int? serverStatus;
  final int? scrambleLength;

  /// The server's default plugin, which is not necessarily the one the
  /// account uses.
  final AuthPlugin authPlugin;

  ServerGreeting(
      this.protocolVersion,
      this.serverVersion,
      this.threadId,
      this.scrambleBuffer,
      this.serverCapabilities,
      this.serverLanguage,
      this.serverStatus,
      this.scrambleLength,
      this.authPlugin);
}

/// Read the packet a connection opens with.
///
/// Throws [MySqlException] if it is an error instead, which is how the server
/// turns a connection away, and [MySqlClientError] if it is a protocol this
/// driver does not speak.
ServerGreeting parseGreeting(Buffer packet) {
  if (packet[0] == PACKET_ERROR) {
    throw createMySqlException(packet);
  }

  packet.seek(0);
  final protocolVersion = packet.readByte();
  if (protocolVersion != 10) {
    throw MySqlClientError('Protocol not supported');
  }
  final serverVersion = packet.readNullTerminatedString();
  final threadId = packet.readUint32();
  var scrambleBuffer = packet.readList(8);
  packet.skip(1);
  var serverCapabilities = packet.readUint16();

  int? serverLanguage;
  int? serverStatus;
  int? scrambleLength;
  var authPlugin = AuthPlugin.none;
  if (packet.hasMore) {
    serverLanguage = packet.readByte();
    serverStatus = packet.readUint16();
    serverCapabilities += (packet.readUint16() << 0x10);
    scrambleLength = packet.readByte();
    packet.skip(10);
    if (serverCapabilities & CLIENT_SECURE_CONNECTION > 0) {
      final rest = packet.readList(math.max(13, scrambleLength - 8) - 1);
      // The null terminator.
      packet.readByte();
      scrambleBuffer = [...scrambleBuffer, ...rest];
    }

    if (serverCapabilities & CLIENT_PLUGIN_AUTH > 0) {
      var pluginName = packet.readStringToEnd();
      if (pluginName.codeUnitAt(pluginName.length - 1) == 0) {
        pluginName = pluginName.substring(0, pluginName.length - 1);
      }
      authPlugin = authPluginFromString(pluginName);
    }
  }

  return ServerGreeting(
      protocolVersion,
      serverVersion,
      threadId,
      scrambleBuffer,
      serverCapabilities,
      serverLanguage,
      serverStatus,
      scrambleLength,
      authPlugin);
}

/// The capabilities to claim, given what the server has.
///
/// CLIENT_SSL is among them if [useSSL] and the server can do it, and that is
/// how the caller knows whether to start TLS.
///
/// Throws [MySqlClientError] for a server too old to talk to.
int clientCapabilities(ServerGreeting greeting, {required bool useSSL}) {
  final serverCapabilities = greeting.serverCapabilities;
  if ((serverCapabilities & CLIENT_PROTOCOL_41) == 0) {
    throw MySqlClientError('Unsupported protocol (must be 4.1 or newer');
  }
  if ((serverCapabilities & CLIENT_SECURE_CONNECTION) == 0) {
    throw MySqlClientError('Old Password AUthentication is not supported');
  }

  var clientFlags = CLIENT_PROTOCOL_41 |
      CLIENT_LONG_PASSWORD |
      CLIENT_LONG_FLAG |
      CLIENT_TRANSACTIONS |
      CLIENT_SECURE_CONNECTION |
      CLIENT_MULTI_RESULTS;
  if (serverCapabilities & CLIENT_PLUGIN_AUTH != 0) {
    clientFlags |= CLIENT_PLUGIN_AUTH;
  }
  if (useSSL && (serverCapabilities & CLIENT_SSL) != 0) {
    clientFlags |= CLIENT_SSL;
  }
  return clientFlags;
}

/// The packet which asks for TLS. It is the start of the handshake response,
/// sent in the clear; the whole response follows once TLS is up.
Buffer sslRequest(int clientFlags, int maxPacketSize, int characterSet) {
  final buffer = Buffer(32);
  buffer.seekWrite(0);
  buffer.writeUint32(clientFlags);
  buffer.writeUint32(maxPacketSize);
  buffer.writeByte(characterSet);
  buffer.fill(23, 0);
  return buffer;
}

/// What proves the client knows [password], for [plugin] and the seed the
/// server sent. Empty for no password.
List<int> authHash(AuthPlugin plugin, List<int> scramble, String? password) {
  if (password == null) {
    return <int>[];
  }
  if (plugin == AuthPlugin.cachingSha2Password) {
    return _cachingSha2Hash(scramble, password);
  }
  return _mysqlNativeHash(scramble, password);
}

/// XOR(SHA1(password), SHA1(scramble, SHA1(SHA1(password))))
List<int> _mysqlNativeHash(List<int> scramble, String password) {
  final shaPwd = sha1.convert(utf8.encode(password)).bytes;
  final shaShaPwd = sha1.convert(shaPwd).bytes;
  final hash = sha1.convert([...scramble, ...shaShaPwd]).bytes;
  for (var i = 0; i < hash.length; i++) {
    hash[i] ^= shaPwd[i];
  }
  return hash;
}

/// XOR(SHA256(password), SHA256(SHA256(SHA256(password)), scramble))
List<int> _cachingSha2Hash(List<int> scramble, String password) {
  final shaPwd = sha256.convert(utf8.encode(password)).bytes;
  final shaShaPwd = sha256.convert(shaPwd).bytes;
  final hash = sha256.convert([...shaShaPwd, ...scramble]).bytes;
  for (var i = 0; i < hash.length; i++) {
    hash[i] ^= shaPwd[i];
  }
  return hash;
}

/// The client's answer to the greeting: who it is, the proof of its password
/// as [hash], and the database to use.
Buffer handshakeResponse(
    {required int clientFlags,
    required int maxPacketSize,
    required int characterSet,
    required String? username,
    required List<int> hash,
    required String? db,
    required AuthPlugin authPlugin}) {
  final encodedUsername = username == null ? <int>[] : utf8.encode(username);
  var encodedDb = <int>[];
  var encodedAuth = <int>[];

  var size = hash.length + encodedUsername.length + 2 + 32;
  if (db != null) {
    encodedDb = utf8.encode(db);
    size += encodedDb.length + 1;
    clientFlags |= CLIENT_CONNECT_WITH_DB;
  }
  if (clientFlags & CLIENT_PLUGIN_AUTH > 0) {
    encodedAuth = utf8.encode(authPluginToString(authPlugin));
    size += encodedAuth.length + 1;
  }

  final buffer = Buffer(size);
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

/// The password itself, null terminated: the answer to a request for full
/// authentication on a connection nobody else can read.
Buffer cleartextPassword(String? password) {
  final encoded = password == null ? <int>[] : utf8.encode(password);
  final buffer = Buffer(encoded.length + 1);
  buffer.writeNullTerminatedList(encoded);
  return buffer;
}

/// Open the conversation on a new connection and log in. Call this inside
/// [ProtocolConnection.exchange].
///
/// The server greets, the client answers with who it is, and then the server
/// either accepts, refuses, or asks for something more - a different plugin,
/// or the password itself - until it does one of the first two.
///
/// [isSecure] is whether nobody else can read the connection as it stands,
/// which is true of a unix socket. Starting TLS makes it so.
///
/// Throws [MySqlException] if the server refuses, and [MySqlClientError] if
/// it asks for something this driver cannot do.
Future<void> handshake(ProtocolConnection conn,
    {required String? user,
    required String? password,
    required String? db,
    required int maxPacketSize,
    required int characterSet,
    required bool useSSL,
    required bool isSecure}) async {
  final greeting = parseGreeting(Buffer.view((await conn.next()).payload));
  final clientFlags = clientCapabilities(greeting, useSSL: useSSL);

  if (clientFlags & CLIENT_SSL != 0) {
    conn.send(sslRequest(clientFlags, maxPacketSize, characterSet));
    await conn.startTls();
    isSecure = true;
  }

  var authPlugin = greeting.authPlugin;
  conn.send(handshakeResponse(
      clientFlags: clientFlags,
      maxPacketSize: maxPacketSize,
      characterSet: characterSet,
      username: user,
      hash: authHash(authPlugin, greeting.scrambleBuffer, password),
      db: db,
      authPlugin: authPlugin));

  // Only an ok or an error packet ends this. Taking anything else for the
  // end leaves the real one unread, and every reply after it is then the
  // reply to the request before.
  while (true) {
    final reply = Buffer.view((await conn.next()).payload);
    switch (reply[0]) {
      case PACKET_OK:
        return;

      case PACKET_ERROR:
        throw createMySqlException(reply);

      case PACKET_AUTH_SWITCH_REQUEST:
        // The account does not use the plugin named in the greeting, so the
        // server names the one it does use and sends a new seed. The answer
        // is the bare hash, with no header of its own.
        reply.seek(1);
        if (!reply.hasMore) {
          // A bare 0xfe asks for mysql_old_password, the pre-4.1 hash.
          throw MySqlClientError(
              'Old Password Authentication is not supported');
        }
        authPlugin = authPluginFromString(reply.readNullTerminatedString());
        var scramble = reply.readListToEnd();
        if (scramble.isNotEmpty && scramble.last == 0) {
          scramble = scramble.sublist(0, scramble.length - 1);
        }
        conn.send(Buffer.fromList(authHash(authPlugin, scramble, password)));
        break;

      case PACKET_AUTH_MORE_DATA:
        // Data which only the plugin in use can interpret, and only
        // caching_sha2_password sends any.
        if (authPlugin != AuthPlugin.cachingSha2Password) {
          throw MySqlClientError('Unexpected auth data for '
              '${authPluginToString(authPlugin)} authentication');
        }
        reply.seek(1);
        final status = reply.readByte();
        if (status == CACHING_SHA2_FAST_AUTH_SUCCESS) {
          // The server had the password cached. The ok packet comes next.
          break;
        }
        if (status != CACHING_SHA2_PERFORM_FULL_AUTHENTICATION) {
          throw MySqlClientError(
              'Unknown caching_sha2_password auth status $status');
        }
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
        conn.send(cleartextPassword(password));
        break;

      default:
        throw MySqlClientError(
            'Unexpected packet type ${reply[0]} during authentication');
    }
  }
}
