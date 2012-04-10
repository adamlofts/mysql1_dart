class HandshakeHandler extends Handler {
  String _user;
  String _password;
  
  int protocolVersion;
  String serverVersion;
  int threadId;
  List<int> scrambleBuffer;
  int serverCapabilities;
  int serverLanguage;
  int serverStatus;
  int scrambleLength;
  
  HandshakeHandler(String this._user, String this._password) {
    log = new Log("HandshakeHandler");
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
  Dynamic processResponse(Buffer response) {
    response.seek(0);
    protocolVersion = response.readByte();
    serverVersion = response.readNullTerminatedString();
    threadId = response.readInt32();
    scrambleBuffer = response.readList(8);
    response.skip(1);
    serverCapabilities = response.readInt16();
    serverLanguage = response.readByte();
    serverStatus = response.readInt16();
    _finished = true;
    
    if ((serverCapabilities & CLIENT_PROTOCOL_41) == 0) {
      throw "Unsupported protocol (must be 4.1 or newer";
    }
    
    int clientFlags = CLIENT_PROTOCOL_41 | CLIENT_LONG_PASSWORD
      | CLIENT_LONG_FLAG | CLIENT_TRANSACTIONS | CLIENT_SECURE_CONNECTION;
    
    return new AuthHandler(_user, _password, scrambleBuffer, 
      clientFlags, 0, 33);
  }
}

class AuthHandler extends Handler {
  String _username;
  String _password;
  List<int> _scrambleBuffer;
  int _clientFlags;
  int _maxPacketSize;
  int _collation;
  
  AuthHandler(String this._username, String this._password, 
    List<int> this._scrambleBuffer, int this._clientFlags,
    int this._maxPacketSize, int this._collation) {
    log = new Log("AuthHandler");
  }
  
  Buffer createRequest() {
    // calculate the mysql password hash
    List<int> hash;
    if (_password == null) {
      hash = new List<int>(0);
    } else {
      hash:Hash hasher = new Sha1();
      hasher.updateString(_password);
      List<int> hashedPassword = hasher.digest();
      
      hash:Hash hasher2 = new Sha1();
      hasher2.update(_scrambleBuffer);
      hasher2.update(hashedPassword);
      List<int> hashedSaltedPassword = hasher2.digest();
      
      hash = new List<int>(hashedSaltedPassword.length);
      for (int i = 0; i < hash.length; i++) {
        hash[i] = hashedPassword[i] ^ hashedSaltedPassword[i];
      }
    }
    
    int size = hash.length + _username.length + 2 + 32;;
    
    Buffer buffer = new Buffer(size);
    buffer.seekWrite(0);
    buffer.writeInt32(_clientFlags);
    buffer.writeInt32(_maxPacketSize);
    buffer.writeByte(_collation);
    buffer.fill(23, 0);
    buffer.writeNullTerminatedString(_username);
    buffer.writeByte(hash.length);
    buffer.writeList(hash);
    
    return buffer;
  }
  
  Dynamic processResponse(Buffer response) {
    checkResponse(response);
    _finished = true;
  }
}
