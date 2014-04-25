part of sqljocky;

class _HandshakeHandler extends _Handler {
  static const String MYSQL_NATIVE_PASSWORD = "mysql_native_password";

  final String _user;
  final String _password;
  final String _db;
  final int _maxPacketSize;

  int protocolVersion;
  String serverVersion;
  int threadId;
  List<int> scrambleBuffer;
  int serverCapabilities;
  int serverLanguage;
  int serverStatus;
  int scrambleLength;
  String pluginName;
  bool useCompression = false;
  bool useSSL = false;

  _HandshakeHandler(String this._user, String this._password, int this._maxPacketSize,
                    [String db, bool useCompression, bool useSSL])
      : _db = db, this.useCompression = useCompression,
      this.useSSL = useSSL {
    log = new Logger("HandshakeHandler");
  }

  /**
   * The server initiates the handshake after the client connects,
   * so a request will never be created.
   */
  Buffer createRequest() {
    throw new MySqlClientError._("Cannot create a handshake request"); 
  }

  _readResponseBuffer(Buffer response) {
    response.seek(0);
    protocolVersion = response.readByte();
    if (protocolVersion != 10) {
      throw new MySqlClientError._("Protocol not supported");
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

      var secure = serverCapabilities & CLIENT_SECURE_CONNECTION;
      var plugin = serverCapabilities & CLIENT_PLUGIN_AUTH;

      scrambleLength = response.readByte();
      response.skip(10);
      if (serverCapabilities & CLIENT_SECURE_CONNECTION > 0) {
        var scrambleBuffer2 = response.readList(math.max(13, scrambleLength - 8) - 1);
        var nullTerminator = response.readByte();
        scrambleBuffer = new List<int>(scrambleBuffer1.length + scrambleBuffer2.length);
        scrambleBuffer.setRange(0, 8, scrambleBuffer1);
        scrambleBuffer.setRange(8, 8 + scrambleBuffer2.length, scrambleBuffer2);
      } else {
        scrambleBuffer = scrambleBuffer1;
      }

      if (serverCapabilities & CLIENT_PLUGIN_AUTH > 0) {
        pluginName = response.readStringToEnd();
        if (pluginName.codeUnitAt(pluginName.length - 1) == 0) {
          pluginName = pluginName.substring(0, pluginName.length - 1);
        }
      }
    }
  }
  
  /**
   * After receiving the handshake packet, if all is well, an [_AuthHandler]
   * is created and returned to handle authentication.
   *
   * Currently, if the client protocol version is not 4.1, an
   * exception is thrown.
   */
  _HandlerResponse processResponse(Buffer response) {
    _readResponseBuffer(response);

    if ((serverCapabilities & CLIENT_PROTOCOL_41) == 0) {
      throw new MySqlClientError._("Unsupported protocol (must be 4.1 or newer");
    }

    if ((serverCapabilities & CLIENT_SECURE_CONNECTION) == 0) {
      throw new MySqlClientError._("Old Password AUthentication is not supported");
    }

    if ((serverCapabilities & CLIENT_PLUGIN_AUTH) != 0 && pluginName != MYSQL_NATIVE_PASSWORD) {
      throw new MySqlClientError._("Authentication plugin not supported: $pluginName");
    }
    
    int clientFlags = CLIENT_PROTOCOL_41 | CLIENT_LONG_PASSWORD
      | CLIENT_LONG_FLAG | CLIENT_TRANSACTIONS | CLIENT_SECURE_CONNECTION;
    
    if (useCompression && (serverCapabilities & CLIENT_COMPRESS) != 0) {
      log.shout("Compression enabled");
      clientFlags |= CLIENT_COMPRESS;
    } else {
      useCompression = false;
    }
    
    if (useSSL && (serverCapabilities & CLIENT_SSL) != 0) {
      log.shout("SSL enabled");
      clientFlags |= CLIENT_SSL | CLIENT_SECURE_CONNECTION;
    } else {
      useSSL = false;
    }
    
    if (useSSL) {
      return new _HandlerResponse(nextHandler: new _SSLHandler(clientFlags, _maxPacketSize, CharacterSet.UTF8,
          new _AuthHandler(_user, _password, _db, scrambleBuffer, clientFlags, _maxPacketSize, CharacterSet.UTF8, ssl: true)));
    }
    
    return new _HandlerResponse(nextHandler: new _AuthHandler(_user, _password, _db, scrambleBuffer,
      clientFlags, _maxPacketSize, CharacterSet.UTF8));
  }
}
