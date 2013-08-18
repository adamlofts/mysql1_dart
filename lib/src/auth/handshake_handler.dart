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
  
  _HandshakeHandler(String this._user, String this._password, [String db]) : _db = db {
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

    return new _HandlerResponse(nextHandler: new _AuthHandler(_user, _password, _db, scrambleBuffer,
      clientFlags, 0, 33));
  }
}
