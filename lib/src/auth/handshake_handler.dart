library mysql1.handshake_handler;

import 'dart:math' as math;

import 'package:logging/logging.dart';

import '../buffer.dart';
import '../handlers/handler.dart';
import '../mysql_client_error.dart';
import '../constants.dart';
import 'ssl_handler.dart';
import 'auth_handler.dart';

class HandshakeHandler extends Handler {
  static const String MYSQL_NATIVE_PASSWORD = 'mysql_native_password';

  final String? _user;
  final String? _password;
  final String? _db;
  final int _maxPacketSize;
  final int _characterSet;

  int? protocolVersion;
  String? serverVersion;
  int? threadId;
  late List<int> scrambleBuffer;
  late int serverCapabilities;
  int? serverLanguage;
  int? serverStatus;
  int? scrambleLength;

  String? pluginName;

  bool useCompression = false;
  bool useSSL = false;

  HandshakeHandler(
      this._user, this._password, this._maxPacketSize, this._characterSet,
      [String? db, bool useCompression = false, bool useSSL = false])
      : _db = db,
        useCompression = useCompression,
        useSSL = useSSL,
        super(Logger('HandshakeHandler'));

  /// The server initiates the handshake after the client connects,
  /// so a request will never be created.
  @override
  Buffer createRequest() {
    throw MySqlClientError('Cannot create a handshake request');
  }

  void readResponseBuffer(Buffer response) {
    response.seek(0);
    protocolVersion = response.readByte();
    if (protocolVersion != 10) {
      throw MySqlClientError('Protocol not supported');
    }
    serverVersion = response.readNullTerminatedString();
    threadId = response.readUint32();
    var scrambleBuffer1 = response.readList(8);
    response.skip(1);
    serverCapabilities = response.readUint16();
    if (response.hasMore) {
      serverLanguage = response.readByte();
      serverStatus = response.readUint16();
      serverCapabilities += (response.readUint16() << 0x10);

      //var secure = serverCapabilities & CLIENT_SECURE_CONNECTION;
      //var plugin = serverCapabilities & CLIENT_PLUGIN_AUTH;

      scrambleLength = response.readByte();
      response.skip(10);
      if (serverCapabilities & CLIENT_SECURE_CONNECTION > 0) {
        var scrambleBuffer2 =
            response.readList(math.max(13, scrambleLength! - 8) - 1);

        // read null-terminator
        response.readByte();
        scrambleBuffer = List<int>.generate(
          scrambleBuffer1.length + scrambleBuffer2.length,
          (index) => 0,
        );
        scrambleBuffer.setRange(0, 8, scrambleBuffer1);
        scrambleBuffer.setRange(8, 8 + scrambleBuffer2.length, scrambleBuffer2);
      } else {
        scrambleBuffer = scrambleBuffer1;
      }

      if (serverCapabilities & CLIENT_PLUGIN_AUTH > 0) {
        pluginName = response.readStringToEnd();
        if (pluginName?.codeUnitAt((pluginName?.length ?? 0) - 1) == 0) {
          pluginName = pluginName!.substring(0, pluginName!.length - 1);
        }
      }
    }
  }

  /// After receiving the handshake packet, if all is well, an [_AuthHandler]
  /// is created and returned to handle authentication.
  ///
  /// Currently, if the client protocol version is not 4.1, an
  /// exception is thrown.
  @override
  HandlerResponse processResponse(Buffer response) {
    checkResponse(response);

    readResponseBuffer(response);

    if ((serverCapabilities & CLIENT_PROTOCOL_41) == 0) {
      throw MySqlClientError('Unsupported protocol (must be 4.1 or newer');
    }

    if ((serverCapabilities & CLIENT_SECURE_CONNECTION) == 0) {
      throw MySqlClientError('Old Password AUthentication is not supported');
    }

    if ((serverCapabilities & CLIENT_PLUGIN_AUTH) != 0 &&
        pluginName != MYSQL_NATIVE_PASSWORD) {
      throw MySqlClientError(
          'Authentication plugin not supported: $pluginName');
    }

    var clientFlags = CLIENT_PROTOCOL_41 |
        CLIENT_LONG_PASSWORD |
        CLIENT_LONG_FLAG |
        CLIENT_TRANSACTIONS |
        CLIENT_SECURE_CONNECTION |
        CLIENT_MULTI_RESULTS;

    if (useCompression && (serverCapabilities & CLIENT_COMPRESS) != 0) {
      log.shout('Compression enabled');
      clientFlags |= CLIENT_COMPRESS;
    } else {
      useCompression = false;
    }

    if (useSSL && (serverCapabilities & CLIENT_SSL) != 0) {
      log.shout('SSL enabled');
      clientFlags |= CLIENT_SSL | CLIENT_SECURE_CONNECTION;
    } else {
      useSSL = false;
    }

    if (useSSL) {
      return HandlerResponse(
          nextHandler: SSLHandler(
              clientFlags,
              _maxPacketSize,
              _characterSet,
              AuthHandler(
                _user,
                _password,
                _db,
                scrambleBuffer,
                clientFlags,
                _maxPacketSize,
                _characterSet,
              )));
    }

    return HandlerResponse(
        nextHandler: AuthHandler(_user, _password, _db, scrambleBuffer,
            clientFlags, _maxPacketSize, _characterSet));
  }
}
