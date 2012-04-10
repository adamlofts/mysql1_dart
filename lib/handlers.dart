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
  
  /**
   * Create a [MySqlError] based on an error response from the mysql server
   */
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

/**
 * Each command which the mysql protocol implements is handled with a [Handler] object.
 * A handler is created with the appropriate parameters when the command is invoked
 * from the connection. The transport is then responsible for sending the
 * request which the handler creates, and then parsing the result returned by 
 * the mysql server, either synchronously or asynchronously.
 */
class Handler {
  Log log;
  bool _finished = false;
  
  /**
   * Returns a [Buffer] containing the command packet.
   */
  abstract Buffer createRequest();
  
  /**
   * Parses a [Buffer] containing the response to the command.
   * Returns a [Handler] if that handler should take over and
   * process subsequent packets from the server, or [:null:]
   * in all other cases.
   */
  abstract Dynamic processResponse(Buffer response);
  
  /**
   * Parses the response packet to recognise Ok and Error packets.
   * Returns an [OkPacket] if the packet was an Ok packet, throws
   * a [MySqlError] if it was an Error packet, or returns [:null:] 
   * if the packet has not been handled by this method.
   */
  Dynamic checkResponse(Buffer response) {
    if (response[0] == PACKET_OK) {
      OkPacket okPacket = new OkPacket(response);
      log.debug(okPacket.toString());
      return okPacket;
    } else if (response[0] == PACKET_ERROR) {
      throw new MySqlError(response);
    }
    return null;
  }

  /**
   * When [finished] is true, this handler has finished processing responses.
   */
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

class UseDbHandler extends Handler {
  String _dbName;
  
  UseDbHandler(String this._dbName) {
    log = new Log("UseDbHandler");
  }
  
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

class ResultSetHeaderPacket {
  int _fieldCount;
  int _extra;
  Log log;
  
  int get fieldCount() => _fieldCount;
  
  ResultSetHeaderPacket(Buffer buffer) {
    log = new Log("ResultSetHeaderPacket");
    _fieldCount = buffer.readLengthCodedBinary();
    if (buffer.canReadMore()) {
      _extra = buffer.readLengthCodedBinary();
    }
  }
  
  String toString() {
    log.debug("Field count: $_fieldCount, Extra: $_extra");
  }
}

class FieldPacket implements Field {
  String _catalog;
  String _db;
  String _table;
  String _orgTable;
  String _name;
  String _orgName;
  int _characterSet;
  int _length;
  int _type;
  int _flags;
  int _decimals;
  int _defaultValue;
  
  String get name() => _name;
  String get table() => _table;
  String get catalog() => _catalog;
  String get orgName() => _orgName;
  String get orgTable() => _orgTable;
  String get db() => _db;
  int get characterSet() => _characterSet;
  int get length() => _length;
  int get type() => _type;
  int get flags() => _flags;
  int get decimals() => _decimals;
  int get defaultValue() => _defaultValue;
  
  FieldPacket(Buffer buffer) {
    _catalog = buffer.readLengthCodedString();
    _db = buffer.readLengthCodedString();
    _table = buffer.readLengthCodedString();
    _orgTable = buffer.readLengthCodedString();
    _name = buffer.readLengthCodedString();
    _orgName = buffer.readLengthCodedString();
    buffer.skip(1);
    _characterSet = buffer.readInt16();
    _length = buffer.readInt32();
    _type = buffer.readByte();
    _flags = buffer.readInt16();
    _decimals = buffer.readByte();
    buffer.skip(2);
    if (buffer.canReadMore()) {
      _defaultValue = buffer.readLengthCodedBinary();
    }
  }
  
  String toString() {
    return "Catalog: $_catalog, DB: $_db, Table: $_table, Org Table: $_orgTable, " 
       "Name: $_name, Org Name: $_orgName, Character Set: $_characterSet, "
       "Length: $_length, Type: $_type, Flags: $_flags, Decimals: $_decimals, "
       "Default Value: $_defaultValue";
  }
}

class DataPacket {
  List<String> _values;
  
  DataPacket(Buffer buffer, int fieldCount) {
    _values = new List<String>(fieldCount);
    for (int i = 0; i < fieldCount; i++) {
      _values[i] = buffer.readLengthCodedString();
    }
  }
  
  String toString() {
    return "Value: $_values";
  }
}

class QueryHandler extends Handler {
  static final int STATE_HEADER_PACKET = 0;
  static final int STATE_FIELD_PACKETS = 1;
  static final int STATE_ROW_PACKETS = 2;
  String _sql;
  int _state = STATE_HEADER_PACKET;
  
  OkPacket _okPacket;
  ResultSetHeaderPacket _resultSetHeaderPacket;
  List<FieldPacket> _fieldPackets;
  List<DataPacket> _dataPackets;
  
  QueryHandler(String this._sql) {
    log = new Log("QueryHandler");
    _fieldPackets = new List<FieldPacket>();
    _dataPackets = new List<DataPacket>();
  }
  
  Buffer createRequest() {
    Buffer buffer = new Buffer(_sql.length + 1);
    buffer.writeByte(COM_QUERY);
    buffer.writeString(_sql);
    return buffer;
  }
  
  //TODO: Handle binary data packets (where are they found?)
  Dynamic processResponse(Buffer response) {
    log.debug("Query processing response");
    var packet = checkResponse(response);
    if (packet == null) {
      if (response[0] == PACKET_EOF) {
        if (_state == STATE_FIELD_PACKETS) {
          _state = STATE_ROW_PACKETS;
        } else if (_state == STATE_ROW_PACKETS){
          _finished = true;
          
          return new ResultsImpl(_okPacket, _resultSetHeaderPacket, _fieldPackets, _dataPackets);
        }
      } else {
        switch (_state) {
        case STATE_HEADER_PACKET:
          _resultSetHeaderPacket = new ResultSetHeaderPacket(response);
          log.debug (_resultSetHeaderPacket.toString());
          _state = STATE_FIELD_PACKETS;
          break;
        case STATE_FIELD_PACKETS:
          FieldPacket fieldPacket = new FieldPacket(response);
          log.debug(fieldPacket.toString());
          _fieldPackets.add(fieldPacket);
          break;
        case STATE_ROW_PACKETS:
          DataPacket dataPacket = new DataPacket(response, _resultSetHeaderPacket.fieldCount);
          log.debug(dataPacket.toString());
          _dataPackets.add(dataPacket);
          break;
        }
      } 
    } else if (packet is OkPacket) {
      _okPacket = packet;
    }
  }
}