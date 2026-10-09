library mysql1.handshake;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'constants.dart';
import 'mysql_client_error.dart';
import 'mysql_exception.dart';
import 'payload.dart';
import 'protocol_connection.dart';
import 'rsa.dart';

/// The states caching_sha2_password sends in an [Packet.authMoreData] packet,
/// and the request the client sends for the server's public key.
///
/// https://dev.mysql.com/doc/dev/mysql-server/latest/page_caching_sha2_authentication_exchanges.html
const int cachingSha2FastAuthSuccess = 0x03;
const int cachingSha2PerformFullAuthentication = 0x04;
const int cachingSha2RequestPublicKey = 0x02;

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
ServerGreeting parseGreeting(Uint8List payload) {
  if (payload.isNotEmpty && payload[0] == Packet.error) {
    throw createMySqlException(payload);
  }

  final packet = PayloadReader(payload);
  final protocolVersion = packet.readByte();
  if (protocolVersion != 10) {
    throw MySqlClientError('Protocol not supported');
  }
  final serverVersion = packet.readNullTerminatedString();
  final threadId = packet.readUint32();
  List<int> scrambleBuffer = packet.readBytes(8);
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
    if (serverCapabilities & Capability.secureConnection.bit > 0) {
      final rest = packet.readBytes(math.max(13, scrambleLength - 8) - 1);
      // The null terminator.
      packet.readByte();
      scrambleBuffer = [...scrambleBuffer, ...rest];
    }

    if (serverCapabilities & Capability.pluginAuth.bit > 0) {
      var pluginName = packet.readRestAsString();
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
/// Capability.ssl.bit is among them if [useSSL], and that is how the caller knows to
/// start TLS.
///
/// Throws [MySqlClientError] for a server too old to talk to, and for one
/// which cannot do TLS when [useSSL] asks for it. Carrying on without would
/// let anyone between the client and the server turn TLS off, by taking the
/// flag out of a greeting which is sent in the clear.
int clientCapabilities(ServerGreeting greeting, {required bool useSSL}) {
  final serverCapabilities = greeting.serverCapabilities;
  if ((serverCapabilities & Capability.protocol41.bit) == 0) {
    throw MySqlClientError('Unsupported protocol (must be 4.1 or newer');
  }
  if ((serverCapabilities & Capability.secureConnection.bit) == 0) {
    throw MySqlClientError('Old Password AUthentication is not supported');
  }

  var clientFlags = Capability.protocol41.bit |
      Capability.longPassword.bit |
      Capability.longFlag.bit |
      Capability.transactions.bit |
      Capability.secureConnection.bit |
      Capability.multiResults.bit;
  if (serverCapabilities & Capability.pluginAuth.bit != 0) {
    clientFlags |= Capability.pluginAuth.bit;
  }
  if (useSSL) {
    if ((serverCapabilities & Capability.ssl.bit) == 0) {
      throw MySqlClientError(
          'TLS was asked for and the server does not support it');
    }
    clientFlags |= Capability.ssl.bit;
  }
  return clientFlags;
}

/// The packet which asks for TLS. It is the start of the handshake response,
/// sent in the clear; the whole response follows once TLS is up.
Uint8List sslRequest(int clientFlags, int maxPacketSize, int characterSet) {
  final request = BytesBuilder(copy: false)
    ..addUint32(clientFlags)
    ..addUint32(maxPacketSize)
    ..addByte(characterSet)
    ..addZeros(23);
  return request.takeBytes();
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
Uint8List handshakeResponse(
    {required int clientFlags,
    required int maxPacketSize,
    required int characterSet,
    required String? username,
    required List<int> hash,
    required String? db,
    required AuthPlugin authPlugin}) {
  if (db != null) {
    clientFlags |= Capability.connectWithDb.bit;
  }
  final response = BytesBuilder(copy: false)
    ..addUint32(clientFlags)
    ..addUint32(maxPacketSize)
    ..addByte(characterSet)
    ..addZeros(23)
    ..addNullTerminated(username == null ? const [] : utf8.encode(username))
    ..addByte(hash.length)
    ..add(hash);
  if (db != null) {
    response.addNullTerminated(utf8.encode(db));
  }
  if (clientFlags & Capability.pluginAuth.bit > 0) {
    response.addNullTerminated(utf8.encode(authPluginToString(authPlugin)));
  }
  return response.takeBytes();
}

/// The password as it is sent on a connection which others can read: null
/// terminated, mixed with the [scramble] the server sent so that it is
/// different every time, and encrypted with the server's public [key].
List<int> encryptedPassword(
    String? password, List<int> scramble, RsaPublicKey key) {
  final plain = [...utf8.encode(password ?? ''), 0];
  for (var i = 0; i < plain.length; i++) {
    plain[i] ^= scramble[i % scramble.length];
  }
  return rsaEncryptOaep(key, plain);
}

/// Ask the server for its RSA public key, in the middle of full
/// authentication.
///
/// The key comes back over the same connection it is about to protect, so
/// this keeps the password from someone who is listening and not from
/// someone who can change what is sent: they can answer with a key of their
/// own.
Future<RsaPublicKey> _requestPublicKey(ProtocolConnection conn) async {
  conn.send(Uint8List.fromList([cachingSha2RequestPublicKey]));
  final reply = (await conn.next()).payload;
  if (reply.isNotEmpty && reply[0] == Packet.error) {
    throw createMySqlException(reply);
  }
  if (reply.isEmpty || reply[0] != Packet.authMoreData) {
    throw MySqlClientError(
        'Expected the server\'s public key and got a packet of type '
        '${reply.isEmpty ? 'none' : reply[0]}');
  }
  return parseRsaPublicKeyPem(ascii.decode(reply.sublist(1)));
}

/// The password itself, null terminated: the answer to a request for full
/// authentication on a connection nobody else can read.
Uint8List cleartextPassword(String? password) =>
    Uint8List.fromList([if (password != null) ...utf8.encode(password), 0]);

/// Open the conversation on a new connection and log in. Call this inside
/// [ProtocolConnection.exchange].
///
/// The server greets, the client answers with who it is, and then the server
/// either accepts, refuses, or asks for something more - a different plugin,
/// or the password itself - until it does one of the first two.
///
/// [isSecure] is whether nobody else can read the connection as it stands,
/// which is true of a unix socket. Starting TLS makes it so. If the server
/// asks for the password itself it is sent in the clear on such a connection,
/// and otherwise encrypted with the server's RSA public key: [serverPublicKey]
/// in PEM if that is given, and if not the key the server sends when asked.
///
/// If TLS is started the server's certificate has to be for [host] and
/// trusted by [securityContext], or accepted by [onBadCertificate]: see
/// [ProtocolConnection.startTls].
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
    required bool isSecure,
    String? host,
    SecurityContext? securityContext,
    bool Function(X509Certificate certificate)? onBadCertificate,
    String? serverPublicKey}) async {
  final greeting = parseGreeting((await conn.next()).payload);
  var clientFlags = clientCapabilities(greeting, useSSL: useSSL);
  if (db != null) {
    // Here and not only in the response: the request for TLS carries the
    // flags too, and the server goes by the ones it saw first. Without this
    // a connection over TLS logs in and has no database selected.
    clientFlags |= Capability.connectWithDb.bit;
  }

  if (clientFlags & Capability.ssl.bit != 0) {
    conn.send(sslRequest(clientFlags, maxPacketSize, characterSet));
    await conn.startTls(
        host: host,
        context: securityContext,
        onBadCertificate: onBadCertificate);
    isSecure = true;
  }

  var authPlugin = greeting.authPlugin;
  var scramble = greeting.scrambleBuffer;
  conn.send(handshakeResponse(
      clientFlags: clientFlags,
      maxPacketSize: maxPacketSize,
      characterSet: characterSet,
      username: user,
      hash: authHash(authPlugin, scramble, password),
      db: db,
      authPlugin: authPlugin));

  // Only an ok or an error packet ends this. Taking anything else for the
  // end leaves the real one unread, and every reply after it is then the
  // reply to the request before.
  while (true) {
    final reply = (await conn.next()).payload;
    switch (reply[0]) {
      case Packet.ok:
        return;

      case Packet.error:
        throw createMySqlException(reply);

      case Packet.authSwitch:
        // The account does not use the plugin named in the greeting, so the
        // server names the one it does use and sends a new seed. The answer
        // is the bare hash, with no header of its own.
        if (reply.length == 1) {
          // A bare 0xfe asks for mysql_old_password, the pre-4.1 hash.
          throw MySqlClientError(
              'Old Password Authentication is not supported');
        }
        final request = PayloadReader(reply)..skip(1);
        authPlugin = authPluginFromString(request.readNullTerminatedString());
        scramble = request.readRest();
        if (scramble.isNotEmpty && scramble.last == 0) {
          scramble = scramble.sublist(0, scramble.length - 1);
        }
        conn.send(Uint8List.fromList(authHash(authPlugin, scramble, password)));
        break;

      case Packet.authMoreData:
        // Data which only the plugin in use can interpret, and only
        // caching_sha2_password sends any.
        if (authPlugin != AuthPlugin.cachingSha2Password) {
          throw MySqlClientError('Unexpected auth data for '
              '${authPluginToString(authPlugin)} authentication');
        }
        final status = (PayloadReader(reply)..skip(1)).readByte();
        if (status == cachingSha2FastAuthSuccess) {
          // The server had the password cached. The ok packet comes next.
          break;
        }
        if (status != cachingSha2PerformFullAuthentication) {
          throw MySqlClientError(
              'Unknown caching_sha2_password auth status $status');
        }
        // The server wants the password itself. In the clear is only safe if
        // nobody else can read the connection.
        if (isSecure) {
          conn.send(cleartextPassword(password));
          break;
        }
        // Otherwise it is encrypted with the server's public key - the one
        // the caller vouches for, or failing that the one the server sends.
        final key = serverPublicKey != null
            ? parseRsaPublicKeyPem(serverPublicKey)
            : await _requestPublicKey(conn);
        conn.send(
            Uint8List.fromList(encryptedPassword(password, scramble, key)));
        break;

      default:
        throw MySqlClientError(
            'Unexpected packet type ${reply[0]} during authentication');
    }
  }
}
