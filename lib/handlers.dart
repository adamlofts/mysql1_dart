class OkPacket {
  int _affectedRows;
  int _insertId;
  int _serverStatus;
  String _message;
  
  int get affectedRows() => _affectedRows;
  int get insertId() => _insertId;
  int get serverStatus() => _serverStatus;
  String get message() => _message;
  
  OkPacket(Buffer buffer) {
    buffer.seek(1);
    _affectedRows = buffer.readLengthCodedBinary();
    _insertId = buffer.readLengthCodedBinary();
    _serverStatus = buffer.readInt16();
    _message = buffer.readStringToEnd();
  }
  
  String toString() {
    return "OK: affected rows: $affectedRows, insert id: $insertId, server status: $serverStatus, message: $message";
  }
}

class MySqlError {
  int _errorNumber;
  String _sqlState;
  String _message;
  
  int get errorNumber() => _errorNumber;
  String get sqlState() => _sqlState;
  String get message() => _message;
  
  MySqlError(Buffer buffer) {
    buffer.seek(1);
    _errorNumber = buffer.readInt16();
    buffer.skip(1);
    _sqlState = buffer.readString(5);
    _message = buffer.readStringToEnd();
  }
  
  String toString() {
    return "Error $errorNumber ($sqlState): $message";
  }
}

class Handler {
  bool _finished = false;
  
  abstract Buffer createRequest();
  
  abstract Dynamic processResponse(Buffer response);
  
  /*
   * returns true if handled
   */
  bool checkResponse(Buffer response) {
    if (response[0] == PACKET_OK) {
      OkPacket okPacket = new OkPacket(response);
      print(okPacket);
      return true;
    } else if (response[0] == PACKET_ERROR) {
      throw new MySqlError(response);
    }
    return false;
  }
  
  bool get finished() => _finished;
}

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
  
  HandshakeHandler(String this._user, String this._password);

  Buffer createRequest() {
    throw "Cannot create a handshake request"; 
  }
  
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
    int this._maxPacketSize, int this._collation);
  
  Buffer createRequest() {
    List<int> hash;
    if (_password == null) {
      hash = new List<int>(0);
    } else {
      hash:Hash x = new Sha1();
      x.updateString(_password);
      List<int> digest = x.digest();
      
      hash:Hash x2 = new Sha1();
      x2.update(_scrambleBuffer);
      x2.update(digest);
      
      List<int> newdigest = x2.digest();
      hash = new List<int>(newdigest.length);
      for (int i = 0; i < hash.length; i++) {
        hash[i] = digest[i] ^ newdigest[i];
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

class UseDbHandler extends Handler {
  String _dbName;
  
  UseDbHandler(String this._dbName);
  
  Buffer createRequest() {
    Buffer buffer = new Buffer(_dbName.length + 1);
    buffer.writeByte(COM_INIT_DB);
    buffer.writeString(_dbName);
    return buffer;
  }
  
  Dynamic processResponse(Buffer response) {
    checkResponse(response);
    _finished = true;
  }
}

class QueryHandler extends Handler {
  static final int STATE_HEADER_PACKET = 0;
  static final int STATE_FIELD_PACKETS = 1;
  static final int STATE_ROW_PACKETS = 2;
  String _sql;
  int _state = STATE_HEADER_PACKET;
  
  QueryHandler(String this._sql);
  
  Buffer createRequest() {
    Buffer buffer = new Buffer(_sql.length + 1);
    buffer.writeByte(COM_QUERY);
    buffer.writeString(_sql);
    return buffer;
  }
  
  Dynamic processResponse(Buffer response) {
    print("Query processing response");
    if (!checkResponse(response)) {
      if (response[0] == PACKET_EOF) {
        if (_state == STATE_FIELD_PACKETS) {
          _state = STATE_ROW_PACKETS;
        } else if (_state == STATE_ROW_PACKETS){
          _finished = true;
        }
      } else {
        if (_state == STATE_HEADER_PACKET) {
          _state = STATE_FIELD_PACKETS;
        }
      } 
    }
  }
}