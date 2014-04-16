part of sqljocky;

class _HandshakeHandler extends _Handler {
  final String _user;
  final String _password;
  final String _db;
  
  int protocolVersion;
  String serverVersion;
  int threadId;
  List<int> scrambleBuffer;
  int serverCapabilities;
  int serverLanguage;
  int serverStatus;
  int scrambleLength;
  bool useCompression = false;
  bool useSSL = false;
  
  _HandshakeHandler(String this._user, String this._password, [String db, bool useCompression, bool useSSL])
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
  
  /**
   * After receiving the handshake packet, if all is well, an [_AuthHandler]
   * is created and returned to handle authentication.
   *
   * Currently, if the client protocol version is not 4.1, an
   * exception is thrown.
   */
  _HandlerResponse processResponse(Buffer response) {
    response.seek(0);
    protocolVersion = response.readByte();
    if (protocolVersion != 10) {
      throw new MySqlProtocolError._("Protocol not supported");
    }
    serverVersion = response.readNullTerminatedString();
    threadId = response.readUint32();
    var scrambleBuffer1 = response.readList(8);
    response.skip(1);
    serverCapabilities = response.readUint16();
    serverLanguage = response.readByte();
    serverStatus = response.readUint16();
    serverCapabilities += (response.readUint16() << 0x10);
    scrambleLength = response.readByte();
    response.skip(10);
    var scrambleBuffer2 = response.readNullTerminatedList();
    scrambleBuffer = new List<int>(scrambleBuffer1.length + scrambleBuffer2.length);
    scrambleBuffer.setRange(0, 8, scrambleBuffer1);
    scrambleBuffer.setRange(8, 8 + scrambleBuffer2.length, scrambleBuffer2);
    
    if ((serverCapabilities & CLIENT_PROTOCOL_41) == 0) {
      throw new MySqlClientError._("Unsupported protocol (must be 4.1 or newer");
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
      return new _HandlerResponse(nextHandler: new _SSLHandler(clientFlags, 16777216, 33, 
          new _AuthHandler(_user, _password, _db, scrambleBuffer, clientFlags, 16777216, 33, ssl: true)));
    }
    
    return new _HandlerResponse(nextHandler: new _AuthHandler(_user, _password, _db, scrambleBuffer,
      clientFlags, 0, 33));
  }
}
