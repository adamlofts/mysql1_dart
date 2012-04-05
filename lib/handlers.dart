interface HandlerResult {
  
}

interface Handler {
  Buffer createRequest();
  
  HandlerResult processResponse(Buffer response);
}

class HandshakeHandler implements Handler {
  int protocolVersion;
  String serverVersion;
  int threadId;
  List<int> scrambleBuffer;
  int serverCapabilities;
  int serverLanguage;
  int serverStatus;
  int scrambleLength;

  Buffer createRequest() {
    throw "Cannot create a handshake request"; 
  }
  
  HandlerResult processResponse(Buffer response) {
    response.seek(0);
    protocolVersion = response.readByte();
    serverVersion = response.readNullTerminatedString();
    threadId = response.readInt32();
    scrambleBuffer = response.readList(8);
    response.skip(1);
    serverCapabilities = response.readInt16();
    serverLanguage = response.readByte();
    serverStatus = response.readInt16();
  }
}

class AuthHandler implements Handler {
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
    print("creating packet");
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
      print("got digest");
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
    
    print("made packet ${buffer._list}");
    return buffer;
  }
  
  HandlerResult processResponse(Buffer response) {
    
  }
}

class UseDbHandler implements Handler {
  String _dbName;
  
  UseDbHandler(String this._dbName);
  
  Buffer createRequest() {
    Buffer buffer = new Buffer(_dbName.length + 1);
    buffer.writeByte(COM_INIT_DB);
    buffer.writeString(_dbName);
    return buffer;
  }
  
  HandlerResult processResponse(Buffer response) {
    
  }
}

class QueryHandler implements Handler {
  String _sql;
  
  QueryHandler(String this._sql);
  
  Buffer createRequest() {
    Buffer buffer = new Buffer(_sql.length + 1);
    buffer.writeByte(COM_QUERY);
    buffer.writeString(_sql);
    return buffer;
  }
  
  HandlerResult processResponse(Buffer response) {
    
  }
}