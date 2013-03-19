part of handlers_lib;

class HandshakeHandler extends Handler {
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
  
  HandshakeHandler(String this._user, String this._password, [String db]) : _db = db {
    log = new Logger("HandshakeHandler");
  }

  /**
   * The server initiates the handshake after the client connects,
   * so a request will never be created.
   */
  Buffer createRequest() {
    throw "Cannot create a handshake request"; 
  }
  
  /**
   * After receiving the handshake packet, if all is well, an [AuthHandler]
   * is created and returned to handle authentication.
   *
   * Currently, if the client protocol version is not 4.1, an
   * exception is thrown.
   */
  dynamic processResponse(Buffer response) {
    response.seek(0);
    protocolVersion = response.readByte();
    serverVersion = response.readNullTerminatedString();
    threadId = response.readInt32();
    var scrambleBuffer1 = response.readList(8);
    response.skip(1);
    serverCapabilities = response.readInt16();
    serverLanguage = response.readByte();
    serverStatus = response.readInt16();
    serverCapabilities += (response.readInt16() << 0x10);
    scrambleLength = response.readByte();
    response.skip(10);
    var scrambleBuffer2 = response.readNullTerminatedList();
    scrambleBuffer = new List<int>.fixedLength(scrambleBuffer1.length + scrambleBuffer2.length);
    scrambleBuffer.setRange(0, 8, scrambleBuffer1);
    scrambleBuffer.setRange(8, scrambleBuffer2.length, scrambleBuffer2);
    
    _finished = true;
    
    if ((serverCapabilities & CLIENT_PROTOCOL_41) == 0) {
      throw "Unsupported protocol (must be 4.1 or newer";
    }
    
    int clientFlags = CLIENT_PROTOCOL_41 | CLIENT_LONG_PASSWORD
      | CLIENT_LONG_FLAG | CLIENT_TRANSACTIONS | CLIENT_SECURE_CONNECTION;
    
    return new AuthHandler(_user, _password, _db, scrambleBuffer, 
      clientFlags, 0, 33);
  }
}

class AuthHandler extends Handler {
  final String _username;
  final String _password;
  final String _db;
  final List<int> _scrambleBuffer;
  final int _clientFlags;
  final int _maxPacketSize;
  final int _collation;
  
  AuthHandler(String this._username, String this._password, String this._db,
    List<int> this._scrambleBuffer, int this._clientFlags,
    int this._maxPacketSize, int this._collation) {
    log = new Logger("AuthHandler");
  }
  
  Buffer createRequest() {
    // calculate the mysql password hash
    List<int> hash;
    if (_password == null) {
      hash = <int>[];
    } else {
      var hasher = new SHA1();
      hasher.add(_password.codeUnits);
      var hashedPassword = hasher.close();
      
      hasher = new SHA1();
      hasher.add(hashedPassword);
      var doubleHashedPassword = hasher.close();
      
      hasher = new SHA1();
      hasher.add(_scrambleBuffer);
      hasher.add(doubleHashedPassword);
      var hashedSaltedPassword = hasher.close();
      
      hash = new List<int>(hashedSaltedPassword.length);
      for (var i = 0; i < hash.length; i++) {
        hash[i] = hashedSaltedPassword[i] ^ hashedPassword[i];
      }
    }

    var size = hash.length + _username.length + 2 + 32;
    var clientFlags = _clientFlags;
    if (_db != null) {
      size += _db.length + 1;
      clientFlags |= CLIENT_CONNECT_WITH_DB;
    }
    
    var buffer = new Buffer(size);
    buffer.seekWrite(0);
    buffer.writeInt32(clientFlags);
    buffer.writeInt32(_maxPacketSize);
    buffer.writeByte(_collation);
    buffer.fill(23, 0);
    buffer.writeNullTerminatedString(_username);
    buffer.writeByte(hash.length);
    buffer.writeList(hash);
    
    if (_db != null) {
      buffer.writeNullTerminatedString(_db);
    }
    
    return buffer;
  }
  
  dynamic processResponse(Buffer response) {
    checkResponse(response);
    _finished = true;
  }
}
