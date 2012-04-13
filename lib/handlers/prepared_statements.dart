class PrepareOkPacket {
  int _statementHandlerId;
  int _columnCount;
  int _parameterCount;
  int _warningCount;

  int get statementHandlerId() => _statementHandlerId;
  int get columnCount() => _columnCount;
  int get parameterCount() => _parameterCount;
  int get warningCount() => _warningCount;
  
  PrepareOkPacket(Buffer buffer) {
    buffer.seek(1);
    _statementHandlerId = buffer.readInt32();
    _columnCount = buffer.readInt16();
    _parameterCount = buffer.readInt16();
    buffer.skip(1);
    _warningCount = buffer.readInt16();
  }
  
  String toString() {
    return "OK: statement handler id: $_statementHandlerId, columns: $_columnCount, "
    "parameters: $_parameterCount, warnings: $_warningCount";
  }
}

class PreparedQuery {
  String _sql;
  List<FieldPacket> _parameters;
  List<FieldPacket> _columns;
  int _statementHandlerId;

  int get statementHandlerId() => _statementHandlerId;
  List<FieldPacket> get parameters() => _parameters;
  List<FieldPacket> get columns() => _columns;

  PreparedQuery(PrepareHandler handler) {
    _sql = handler.sql;
    _parameters = handler.parameters;
    _columns = handler.columns;
    _statementHandlerId = handler.okPacket.statementHandlerId;
  }
}

class PrepareHandler extends Handler {
  String _sql;
  PrepareOkPacket _okPacket;
  int _parametersToRead;
  int _columnsToRead;
  List<FieldPacket> _parameters;
  List<FieldPacket> _columns;
  
  String get sql() => _sql;
  PrepareOkPacket get okPacket() => _okPacket;
  List<FieldPacket> get parameters() => _parameters;
  List<FieldPacket> get columns() => _columns;
  
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
      log.debug(packet.toString());
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

class ExecuteQueryHandler extends Handler {
  PreparedQuery _preparedQuery;
  List<Dynamic> _values;
  bool _executed;
  
  ExecuteQueryHandler(PreparedQuery this._preparedQuery, bool this._executed,
    List<Dynamic> this._values) {
    log = new Log("ExecuteQueryHandler");
  }
  
  Buffer createRequest() {
    int bytes = ((_values.length + 7) / 8).floor().toInt();
    List<int> nullMap = new List<int>(bytes);
    int byte = 0;
    int bit = 0;
    for (int i = 0; i < _values.length; i++) {
      if (nullMap[byte] == null) {
        nullMap[byte] = 0;
      }
      if (_values[i] == null) {
        nullMap[byte] = nullMap[byte] + (1 << bit);
      }
      bit++;
      if (bit > 7) {
        bit = 0;
        byte++;
      }
    };
    
//    FieldWriter fields = new FieldWriter();
//    for (int i = 0; i < _values.length; i++) {
//      Dynamic value = _values[i];
//      if (value != null) {
//        fields.write(value, _preparedQuery.parameters[i].type);
//      }
//    }
//    List<int> values = fields.list;
    
    List<int> types = new List<int>();
    List<int> values = new List<int>();
    for (int i = 0; i < _values.length; i++) {
      Dynamic value = _values[i];
      if (value != null) {
        if (value is num) {
          types.add(FIELD_TYPE_LONGLONG);
          types.add(0);
          values.add(value & 0xFF);
          values.add(value >> 8 & 0xFF);
          values.add(value >> 16 & 0xFF);
          values.add(value >> 24 & 0xFF);
          values.add(value >> 32 & 0xFF);
          values.add(value >> 40 & 0xFF);
          values.add(value >> 48 & 0xFF);
          values.add(value >> 56 & 0xFF);
        } else if (value is String) {
          types.add(FIELD_TYPE_VARCHAR);
          types.add(0);
          values.add(value.length);
          values.addAll(value);
        }
      }
    }
    
    Buffer buffer = new Buffer(10 + nullMap.length + 1 + _values.length * 2 + values.length);
    buffer.writeByte(COM_STMT_EXECUTE);
    buffer.writeInt32(_preparedQuery.statementHandlerId);
    buffer.writeByte(0);
    buffer.writeInt32(1);
    buffer.writeList(nullMap);
    if (!_executed) {
      buffer.writeByte(1);
      buffer.writeList(types);
      buffer.writeList(values);
    } else {
      buffer.writeByte(0);      
    }
    
    return buffer;
  }
  
  Dynamic processResponse(Buffer response) {
    checkResponse(response);
    _finished = true;
  }
}