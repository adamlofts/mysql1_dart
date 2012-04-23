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
  final String _sql;
  final List<FieldPacket> _parameters;
  final List<FieldPacket> _columns;
  final int _statementHandlerId;

  int get statementHandlerId() => _statementHandlerId;
  List<FieldPacket> get parameters() => _parameters;
  List<FieldPacket> get columns() => _columns;

  PreparedQuery(PrepareHandler handler) :
      _sql = handler.sql,
      _parameters = handler.parameters,
      _columns = handler.columns,
      _statementHandlerId = handler.okPacket.statementHandlerId;
}

class PrepareHandler extends Handler {
  final String _sql;
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
      log.debug('Not an OK packet, params to read: $_parametersToRead');
      if (_parametersToRead > -1) {
        if (response[0] == PACKET_EOF) {
          log.debug("EOF");
          if (_parametersToRead != 0) {
            throw "Unexpected EOF packet";
          }
        } else {
          FieldPacket fieldPacket = new FieldPacket(response);
          log.debug("field packet: $fieldPacket");
          _parameters[_okPacket.parameterCount - _parametersToRead] = fieldPacket;
        }
        _parametersToRead--;
      } else if (_columnsToRead > -1) {
        if (response[0] == PACKET_EOF) {
          log.debug("EOF");
          if (_columnsToRead != 0) {
            throw "Unexpected EOF packet";
          }
        } else {
          FieldPacket fieldPacket = new FieldPacket(response);
          log.debug("field packet (column): $fieldPacket");
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
      log.debug("finished");
      return new PreparedQuery(this);
    }
  }
}

class CloseStatementHandler extends Handler {
  final int _handle;

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
  static final int STATE_HEADER_PACKET = 0;
  static final int STATE_FIELD_PACKETS = 1;
  static final int STATE_ROW_PACKETS = 2;
  
  int _state = STATE_HEADER_PACKET;

  ResultSetHeaderPacket _resultSetHeaderPacket;
  List<FieldPacket> _fieldPackets;
  List<BinaryDataPacket> _dataPackets;

  final PreparedQuery _preparedQuery;
  final List<Dynamic> _values;
  OkPacket _okPacket;
  bool _executed;
  
  ExecuteQueryHandler(PreparedQuery this._preparedQuery, bool this._executed,
    List<Dynamic> this._values) {
    _fieldPackets = <FieldPacket>[];
    _dataPackets = <BinaryDataPacket>[];
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
    
    //TODO do this properly
    List<int> types = <int>[];
    List<int> values = <int>[];
    for (int i = 0; i < _values.length; i++) {
      log.debug("field $i ${_preparedQuery._parameters[i].type}");
      Dynamic value = _values[i];
      if (value != null) {
        if (value is int) {
//          if (value < 128 && value > -127) {
//            log.debug("TINYINT: value");
//            types.add(FIELD_TYPE_TINY);
//            types.add(0);
//            values.add(value & 0xFF);
//          } else {
            log.debug("LONG: $value");
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
//          }
        } else if (value is double) {
          log.debug("DOUBLE: $value");

          String s = value.toString();
          types.add(FIELD_TYPE_VARCHAR);
          types.add(0);
          values.add(s.length);
          values.addAll(s.charCodes());
          
          // TODO: if you send a double value for a decimal field, it doesn't like it
//          types.add(FIELD_TYPE_FLOAT);
//          types.add(0);
//          values.addAll(doubleToList(value));
        } else if (value is Date) {
          log.debug("DATE: $value");
          types.add(FIELD_TYPE_DATETIME);
          types.add(0);
          values.add(11);
          values.add(value.year & 0xFF);
          values.add(value.year >> 8 & 0xFF);
          values.add(value.month);
          values.add(value.day);
          values.add(value.hours);
          values.add(value.minutes);
          values.add(value.seconds);
          int billionths = value.milliseconds * 1000000;
          values.add(billionths & 0xFF); 
          values.add(billionths >> 8 & 0xFF); 
          values.add(billionths >> 16 & 0xFF); 
          values.add(billionths >> 24 & 0xFF); 
        } else if (value is bool) {
          log.debug("BOOL: $value");
          types.add(FIELD_TYPE_TINY);
          types.add(0);
          values.add(value ? 1 : 0);
        } else if (value is List<int>) {
          log.debug("LIST: $value");
          types.add(FIELD_TYPE_BLOB);
          types.add(0);
          values.add(value.length);
          values.addAll(value);
        } else {
          log.debug("STRING: $value");
          String s = value.toString();
          types.add(FIELD_TYPE_VARCHAR);
          types.add(0);
          values.add(s.length);
          values.addAll(s.charCodes());
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
    log.debug(buffer._list);
    return buffer;
  }
  
  Dynamic processResponse(Buffer response) {
    var packet;
    if (_state == STATE_HEADER_PACKET) {
      packet = checkResponse(response);
    }
    if (packet == null) {
      if (response[0] == PACKET_EOF) {
        log.debug('Got an EOF');
        if (_state == STATE_FIELD_PACKETS) {
          _state = STATE_ROW_PACKETS;
        } else if (_state == STATE_ROW_PACKETS){
          _finished = true;
          
          return new ResultsImpl(_okPacket, _resultSetHeaderPacket, _fieldPackets, _dataPackets);
        }
      } else {
        switch (_state) {
        case STATE_HEADER_PACKET:
          log.debug('Got a header packet');
          _resultSetHeaderPacket = new ResultSetHeaderPacket(response);
          log.debug(_resultSetHeaderPacket.toString());
          _state = STATE_FIELD_PACKETS;
          break;
        case STATE_FIELD_PACKETS:
          log.debug('Got a field packet');
          FieldPacket fieldPacket = new FieldPacket(response);
          log.debug(fieldPacket.toString());
          _fieldPackets.add(fieldPacket);
          break;
        case STATE_ROW_PACKETS:
          log.debug('Got a row packet');
          BinaryDataPacket dataPacket = new BinaryDataPacket(response, _fieldPackets);
          log.debug(dataPacket.toString());
          _dataPackets.add(dataPacket);
          break;
        }
      }
    } else if (packet is OkPacket) {
      _okPacket = packet;
      if ((packet.serverStatus & SERVER_MORE_RESULTS_EXISTS) == 0) {
        _finished = true;
        
        return new ResultsImpl(_okPacket, null, null, null);
      }
    }
  }
}

class BinaryDataPacket implements DataPacket {
  List<Dynamic> _values;
  final Log log;
  
  List<Dynamic> get values() => _values;
  
  BinaryDataPacket(Buffer buffer, List<FieldPacket> fields) :
      log = new Log("BinaryDataPacket") {
    buffer.skip(1);
    List<int> nulls = buffer.readList(((fields.length + 7 + 2) / 8).floor().toInt());
    log.debug("Nulls: $nulls");
    List<bool> nullMap = new List<bool>(fields.length);
    int shift = 2;
    int byte = 0;
    for (int i = 0; i < fields.length; i++) {
      int mask = 1 << shift;
      nullMap[i] = (nulls[byte] & mask) != 0;
      shift++;
      if (shift > 7) {
        shift = 0;
        byte++;
      }
    }
    
    _values = new List<Dynamic>(fields.length);
    for (int i = 0; i < fields.length; i++) {
      log.debug("$i: ${fields[i].name}");
      if (nullMap[i]) {
        log.debug("Value: null");
        _values[i] = null;
        continue;
      }
      switch (fields[i].type) {
        case FIELD_TYPE_BLOB:
          log.debug("BLOB");
          int len = buffer.readByte();
          _values[i] = buffer.readList(len);
          log.debug("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_TINY:
          log.debug("TINY");
          _values[i] = buffer.readByte();
          log.debug("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_SHORT:
          log.debug("SHORT");
          _values[i] = buffer.readInt16();
          log.debug("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_INT24:
          log.debug("INT24");
          _values[i] = buffer.readInt32();
          log.debug("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_LONG:
          log.debug("LONG");
          _values[i] = buffer.readInt32();
          log.debug("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_LONGLONG:
          log.debug("LONGLONG");
          _values[i] = buffer.readInt64();
          log.debug("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_NEWDECIMAL:
          log.debug("NEWDECIMAL");
          int len = buffer.readByte();
          String num = buffer.readString(len);
           _values[i] = Math.parseDouble(num);
          log.debug("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_FLOAT:
          log.debug("FLOAT");
          _values[i] = buffer.readFloat();
          log.debug("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_DOUBLE:
          log.debug("DOUBLE");
          _values[i] = buffer.readDouble();
          log.debug("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_BIT:
          log.debug("BIT");
          int len = buffer.readByte();
          // TODO should this be returned as a list, or an arbitrarily long number?
          _values[i] = buffer.readList(len);
          log.debug("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_DATETIME:
        case FIELD_TYPE_DATE:
        case FIELD_TYPE_TIMESTAMP:
          log.debug("DATE/DATETIME");
          int len = buffer.readByte();
          List<int> date = buffer.readList(len);
          int year = 0;
          int month = 0;
          int day = 0;
          int hours = 0;
          int minutes = 0;
          int seconds = 0;
          int billionths = 0;
          
          if (date.length > 0) {
            year = date[0] + (date[1] << 8);
            month = date[2];
            day = date[3];
            if (date.length > 4) {
              hours = date[4];
              minutes = date[5];
              seconds = date[6];
              if (date.length > 7) {
                billionths = date[7] + (date[8] << 8)
                    + (date[9] << 16) + (date[10] << 24);
              }
            }
          }
          
          _values[i] = new Date(year, month, day, hours, minutes, seconds, (billionths / 1000000).toInt());
          log.debug("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_TIME:
          log.debug("TIME");
          int len = buffer.readByte();
          List<int> time = buffer.readList(len);
          
          int sign = 1;
          int days = 0;
          int hours = 0;
          int minutes = 0;
          int seconds = 0;
          int billionths = 0;
          
          log.debug("time: $time");
          if (time.length > 0) {
            sign = time[0] == 1 ? -1 : 1;
            days = time[1] + (time[2] << 8) + (time[3] << 16) + (time[4] << 24);
            hours = time[5];
            minutes = time[6];
            seconds = time[7];
            if (time.length > 8) {
              billionths = time[8] + (time[9] << 8) + (time[10] << 16) + (time[11] << 24);
            }
          }
          _values[i] = new Duration(days * sign, hours * sign, minutes * sign, seconds * sign, (billionths / 1000000).toInt() * sign);
          break;
        case FIELD_TYPE_YEAR:
          log.debug("YEAR");
          _values[i] = buffer.readInt16();
          log.debug("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_STRING:
          log.debug("STRING");
          _values[i] = buffer.readLengthCodedString();
          log.debug("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_VAR_STRING:
          log.debug("STRING");
          _values[i] = buffer.readLengthCodedString();
          log.debug("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_GEOMETRY:
          log.debug("GEOMETRY - not implemented");
          int len = buffer.readByte();
          //TODO
          _values[i] = buffer.readList(len);
          break;
        case FIELD_TYPE_NEWDATE:
        case FIELD_TYPE_DECIMAL:
          //TODO pre 5.0.3 will return old decimal values
        case FIELD_TYPE_SET:
        case FIELD_TYPE_ENUM:
        case FIELD_TYPE_TINY_BLOB:
        case FIELD_TYPE_MEDIUM_BLOB:
        case FIELD_TYPE_LONG_BLOB:
        case FIELD_TYPE_VARCHAR:
          //Are there any other types a mysql server can return?
          log.debug("Field type not implemented yet ${fields[i].type}");
          log.debug(buffer.readList(8));
          break;
        default:
          log.debug("Unsupported field type ${fields[i].type}");
          break;
      }
    }
  }
  
  String toString() => "Value: $_values";
}
