
class PreparedQuery {
  PrepareHandler _handler;
  
  PreparedQuery(PrepareHandler this._handler);
}

class PrepareHandler extends Handler {
  String _sql;
  PrepareOkPacket _okPacket;
  int _parametersToRead;
  int _columnsToRead;
  List<FieldPacket> _parameters;
  List<FieldPacket> _columns;
  
  PrepareHandler(String this._sql) {
    log = new Log("PrepareHandler");
  }
  
  Buffer createRequest() {
    Buffer buffer = new Buffer(_sql.length + 1);
    buffer.writeByte(COM_STMT_PREPARE);
    buffer.writeString(_sql);
    return buffer;
  }
  
  Dynamic processResponse(Buffer response) {
    log.debug("Prepare processing response");
    var packet = checkResponse(response, true);
    if (packet == null) {
      if (_parametersToRead > -1) {
        if (response[0] == PACKET_EOF) {
          if (_parametersToRead != 0) {
            throw "Unexpected EOF packet";
          }
        } else {
          FieldPacket fieldPacket = new FieldPacket(response);
          log.debug(fieldPacket.toString());
          _parameters[_okPacket.parameterCount - _parametersToRead] = fieldPacket;
        }
        _parametersToRead--;
      } else if (_columnsToRead > -1) {
        if (response[0] == PACKET_EOF) {
          if (_columnsToRead != 0) {
            throw "Unexpected EOF packet";
          }
        } else {
          FieldPacket fieldPacket = new FieldPacket(response);
          log.debug(fieldPacket.toString());
          _columns[_okPacket.columnCount - _columnsToRead] = fieldPacket;
        }
        _columnsToRead--;
      }
    } else if (packet is PrepareOkPacket) {
      log.debug(packet.toString);
      _okPacket = packet;
      _parametersToRead = packet.parameterCount;
      _columnsToRead = packet.columnCount;
      _parameters = new List<FieldPacket>(_parametersToRead);
      _columns = new List<FieldPacket>(_columnsToRead);
      if (_parametersToRead == 0) {
        _parametersToRead = -1;
      }
      if (_columnsToRead == 0) {
        _columnsToRead = -1;
      }
    }
    
    if (_parametersToRead == -1 && _columnsToRead == -1) {
      _finished = true;
      return new PreparedQuery(this);
    }
  }
}

class CloseStatementHandler extends Handler {
  int _handle;
  
  CloseStatementHandler(int this._handle) {
    log = new Log("CloseStatementHandler");
  }
  
  Buffer createRequest() {
    Buffer buffer = new Buffer(5);
    buffer.writeByte(COM_STMT_CLOSE);
    buffer.writeInt32(_handle);
    return buffer;
  }
  
  Dynamic processResponse(Buffer response) {
    checkResponse(response);
    _finished = true;
  }
}

