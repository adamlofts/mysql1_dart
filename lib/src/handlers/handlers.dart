part of handlers_lib;

// not using this one yet
class ParameterPacket {
  int _type;
  int _flags;
  int _decimals;
  int _length;
  
  int get type => _type;
  int get flags => _flags;
  int get decimals => _decimals;
  int get length => _length;
  
  ParameterPacket(Buffer buffer) {
    _type = buffer.readInt16();
    _flags = buffer.readInt16();
    _decimals = buffer.readByte();
    _length = buffer.readInt32();
  }
}

class OkPacket {
  int _affectedRows;
  int _insertId;
  int _serverStatus;
  String _message;
  
  int get affectedRows => _affectedRows;
  int get insertId => _insertId;
  int get serverStatus => _serverStatus;
  String get message => _message;
  
  OkPacket(Buffer buffer) {
    buffer.seek(1);
    _affectedRows = buffer.readLengthCodedBinary();
    _insertId = buffer.readLengthCodedBinary();
    _serverStatus = buffer.readInt16();
    _message = buffer.readStringToEnd();
  }
  
  String toString() => "OK: affected rows: $affectedRows, insert id: $insertId, server status: $serverStatus, message: $message";
}

class MySqlError {
  int _errorNumber;
  String _sqlState;
  String _message;
  
  int get errorNumber => _errorNumber;
  String get sqlState => _sqlState;
  String get message => _message;
  
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
  
  String toString() => "Error $errorNumber ($sqlState): $message";
}

/**
 * Each command which the mysql protocol implements is handled with a [Handler] object.
 * A handler is created with the appropriate parameters when the command is invoked
 * from the connection. The transport is then responsible for sending the
 * request which the handler creates, and then parsing the result returned by 
 * the mysql server, either synchronously or asynchronously.
 */
abstract class Handler {
  Logger log;
  bool _finished = false;
  
  /**
   * Returns a [Buffer] containing the command packet.
   */
  Buffer createRequest();
  
  /**
   * Parses a [Buffer] containing the response to the command.
   * Returns a [Handler] if that handler should take over and
   * process subsequent packets from the server, otherwise the
   * result is returned in the [Future], either in one of the
   * Connection methods, or Transport.connect() 
   */
  dynamic processResponse(Buffer response);
  
  /**
   * Parses the response packet to recognise Ok and Error packets.
   * Returns an [OkPacket] if the packet was an Ok packet, throws
   * a [MySqlError] if it was an Error packet, or returns [:null:] 
   * if the packet has not been handled by this method.
   */
  dynamic checkResponse(Buffer response, [bool prepareStmt=false]) {
    if (response[0] == PACKET_OK) {
      if (prepareStmt) {
        var okPacket = new PrepareOkPacket(response);
        log.fine(okPacket.toString());
        return okPacket;
      } else {
        var okPacket = new OkPacket(response);
        log.fine(okPacket.toString());
        return okPacket;
      }
    } else if (response[0] == PACKET_ERROR) {
      throw new MySqlError(response);
    }
    return null;
  }

  /**
   * When [finished] is true, this handler has finished processing responses.
   */
  bool get finished => _finished;
}

class UseDbHandler extends Handler {
  final String _dbName;
  
  UseDbHandler(String this._dbName) {
    log = new Logger("UseDbHandler");
  }
  
  Buffer createRequest() {
    var buffer = new Buffer(_dbName.length + 1);
    buffer.writeByte(COM_INIT_DB);
    buffer.writeString(_dbName);
    return buffer;
  }
  
  dynamic processResponse(Buffer response) {
    checkResponse(response);
    _finished = true;
  }
}

class PingHandler extends Handler {
  PingHandler() {
    log = new Logger("PingHandler");
  }
  
  Buffer createRequest() {
    var buffer = new Buffer(1);
    buffer.writeByte(COM_PING);
    return buffer;
  }
  
  dynamic processResponse(Buffer response) {
    checkResponse(response);
    _finished = true;
  }
}

class DebugHandler extends Handler {
  DebugHandler() {
    log = new Logger("DebugHandler");
  }
  
  Buffer createRequest() {
    var buffer = new Buffer(1);
    buffer.writeByte(COM_DEBUG);
    return buffer;
  }
  
  dynamic processResponse(Buffer response) {
    checkResponse(response);
    _finished = true;
  }
}

class QuitHandler extends Handler {
  QuitHandler() {
    log = new Logger("QuitHandler");
  }
  
  Buffer createRequest() {
    var buffer = new Buffer(1);
    buffer.writeByte(COM_QUIT);
    return buffer;
  }
  
  dynamic processResponse(Buffer response) {
    throw "No response expected";
  }
}
