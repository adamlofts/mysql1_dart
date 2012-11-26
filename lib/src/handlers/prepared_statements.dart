part of handlers_lib;

class PrepareOkPacket {
  int _statementHandlerId;
  int _columnCount;
  int _parameterCount;
  int _warningCount;

  int get statementHandlerId => _statementHandlerId;
  int get columnCount => _columnCount;
  int get parameterCount => _parameterCount;
  int get warningCount => _warningCount;
  
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
  final String sql;
  final List<Field> parameters;
  final List<Field> columns;
  final int statementHandlerId;
  dynamic cnx; // should be a Connection

  PreparedQuery(PrepareHandler handler) :
      sql = handler.sql,
      parameters = handler.parameters,
      columns = handler.columns,
      
      statementHandlerId = handler.okPacket.statementHandlerId;
}

class PrepareHandler extends Handler {
  final String _sql;
  PrepareOkPacket _okPacket;
  int _parametersToRead;
  int _columnsToRead;
  List<Field> _parameters;
  List<Field> _columns;
  
  String get sql => _sql;
  PrepareOkPacket get okPacket => _okPacket;
  List<Field> get parameters => _parameters;
  List<Field> get columns => _columns;
  
  PrepareHandler(String this._sql) {
    log = new Logger("PrepareHandler");
  }
  
  Buffer createRequest() {
    Buffer buffer = new Buffer(_sql.length + 1);
    buffer.writeByte(COM_STMT_PREPARE);
    buffer.writeString(_sql);
    return buffer;
  }
  
  dynamic processResponse(Buffer response) {
    log.fine("Prepare processing response");
    var packet = checkResponse(response, true);
    if (packet == null) {
      log.fine('Not an OK packet, params to read: $_parametersToRead');
      if (_parametersToRead > -1) {
        if (response[0] == PACKET_EOF) {
          log.fine("EOF");
          if (_parametersToRead != 0) {
            throw "Unexpected EOF packet";
          }
        } else {
          Field fieldPacket = new Field(response);
          log.fine("field packet: $fieldPacket");
          _parameters[_okPacket.parameterCount - _parametersToRead] = fieldPacket;
        }
        _parametersToRead--;
      } else if (_columnsToRead > -1) {
        if (response[0] == PACKET_EOF) {
          log.fine("EOF");
          if (_columnsToRead != 0) {
            throw "Unexpected EOF packet";
          }
        } else {
          Field fieldPacket = new Field(response);
          log.fine("field packet (column): $fieldPacket");
          _columns[_okPacket.columnCount - _columnsToRead] = fieldPacket;
        }
        _columnsToRead--;
      }
    } else if (packet is PrepareOkPacket) {
      log.fine(packet.toString());
      _okPacket = packet;
      _parametersToRead = packet.parameterCount;
      _columnsToRead = packet.columnCount;
      _parameters = new List<Field>(_parametersToRead);
      _columns = new List<Field>(_columnsToRead);
      if (_parametersToRead == 0) {
        _parametersToRead = -1;
      }
      if (_columnsToRead == 0) {
        _columnsToRead = -1;
      }
    }
    
    if (_parametersToRead == -1 && _columnsToRead == -1) {
      _finished = true;
      log.fine("finished");
      return new PreparedQuery(this);
    }
  }
}

class CloseStatementHandler extends Handler {
  final int _handle;

  CloseStatementHandler(int this._handle) {
    log = new Logger("CloseStatementHandler");
  }
  
  Buffer createRequest() {
    Buffer buffer = new Buffer(5);
    buffer.writeByte(COM_STMT_CLOSE);
    buffer.writeInt32(_handle);
    return buffer;
  }
  
  dynamic processResponse(Buffer response) {
    checkResponse(response);
    _finished = true;
  }
}

class ExecuteQueryHandler extends Handler {
  static const int STATE_HEADER_PACKET = 0;
  static const int STATE_FIELD_PACKETS = 1;
  static const int STATE_ROW_PACKETS = 2;
  
  int _state = STATE_HEADER_PACKET;

  ResultSetHeaderPacket _resultSetHeaderPacket;
  List<Field> _fieldPackets;
  List<BinaryDataPacket> _dataPackets;

  final PreparedQuery _preparedQuery;
  final List<dynamic> _values;
  OkPacket _okPacket;
  bool _executed;
  
  ExecuteQueryHandler(PreparedQuery this._preparedQuery, bool this._executed,
    List<dynamic> this._values) {
    _fieldPackets = <Field>[];
    _dataPackets = <BinaryDataPacket>[];
    log = new Logger("ExecuteQueryHandler");
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
      log.fine("field $i ${_preparedQuery.parameters[i].type}");
      var value = _values[i];
      if (value != null) {
        if (value is int) {
//          if (value < 128 && value > -127) {
//            log.fine("TINYINT: value");
//            types.add(FIELD_TYPE_TINY);
//            types.add(0);
//            values.add(value & 0xFF);
//          } else {
            log.fine("LONG: $value");
            types.add(FIELD_TYPE_LONGLONG);
            types.add(0);
            values.add(value >> 0x00 & 0xFF);
            values.add(value >> 0x08 & 0xFF);
            values.add(value >> 0x10 & 0xFF);
            values.add(value >> 0x18 & 0xFF);
            values.add(value >> 0x20 & 0xFF);
            values.add(value >> 0x28 & 0xFF);
            values.add(value >> 0x30 & 0xFF);
            values.add(value >> 0x38 & 0xFF);
//          }
        } else if (value is double) {
          log.fine("DOUBLE: $value");

          String s = value.toString();
          types.add(FIELD_TYPE_VARCHAR);
          types.add(0);
          values.add(s.length);
          values.addAll(s.charCodes);
          
          // TODO: if you send a double value for a decimal field, it doesn't like it
//          types.add(FIELD_TYPE_FLOAT);
//          types.add(0);
//          values.addAll(doubleToList(value));
        } else if (value is Date) {
          log.fine("DATE: $value");
          types.add(FIELD_TYPE_DATETIME);
          types.add(0);
          values.add(11);
          values.add(value.year >> 0x00 & 0xFF);
          values.add(value.year >> 0x08 & 0xFF);
          values.add(value.month);
          values.add(value.day);
          values.add(value.hour);
          values.add(value.minute);
          values.add(value.second);
          int billionths = value.millisecond * 1000000;
          values.add(billionths >> 0x00 & 0xFF); 
          values.add(billionths >> 0x08 & 0xFF); 
          values.add(billionths >> 0x10 & 0xFF); 
          values.add(billionths >> 0x18 & 0xFF); 
        } else if (value is bool) {
          log.fine("BOOL: $value");
          types.add(FIELD_TYPE_TINY);
          types.add(0);
          values.add(value ? 1 : 0);
        } else if (value is List<int>) {
          log.fine("LIST: $value");
          types.add(FIELD_TYPE_BLOB);
          types.add(0);
          values.add(value.length);
          values.addAll(value);
        } else {
          log.fine("STRING: $value");
          String s = value.toString();
          types.add(FIELD_TYPE_VARCHAR);
          types.add(0);
          values.add(s.length);
          values.addAll(s.charCodes);
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
//    log.fine(Buffer.listChars(buffer._list));
    return buffer;
  }
  
  dynamic processResponse(Buffer response) {
    var packet;
    if (_state == STATE_HEADER_PACKET) {
      packet = checkResponse(response);
    }
    if (packet == null) {
      if (response[0] == PACKET_EOF) {
        log.fine('Got an EOF');
        if (_state == STATE_FIELD_PACKETS) {
          _state = STATE_ROW_PACKETS;
        } else if (_state == STATE_ROW_PACKETS){
          _finished = true;
          
          return new Results(_okPacket, _resultSetHeaderPacket, _fieldPackets, _dataPackets);
        }
      } else {
        switch (_state) {
        case STATE_HEADER_PACKET:
          log.fine('Got a header packet');
          _resultSetHeaderPacket = new ResultSetHeaderPacket(response);
          log.fine(_resultSetHeaderPacket.toString());
          _state = STATE_FIELD_PACKETS;
          break;
        case STATE_FIELD_PACKETS:
          log.fine('Got a field packet');
          Field fieldPacket = new Field(response);
          log.fine(fieldPacket.toString());
          _fieldPackets.add(fieldPacket);
          break;
        case STATE_ROW_PACKETS:
          log.fine('Got a row packet');
          BinaryDataPacket dataPacket = new BinaryDataPacket(response, _fieldPackets);
          log.fine(dataPacket.toString());
          _dataPackets.add(dataPacket);
          break;
        }
      }
    } else if (packet is OkPacket) {
      _okPacket = packet;
      if ((packet.serverStatus & SERVER_MORE_RESULTS_EXISTS) == 0) {
        _finished = true;
        
        return new Results(_okPacket, null, null, null);
      }
    }
  }
}

class BinaryDataPacket implements DataPacket {
  List<dynamic> _values;
  final Logger log;
  
  List<dynamic> get values => _values;
  
  BinaryDataPacket(Buffer buffer, List<Field> fields) :
      log = new Logger("BinaryDataPacket") {
    buffer.skip(1);
    List<int> nulls = buffer.readList(((fields.length + 7 + 2) / 8).floor().toInt());
    log.fine("Nulls: $nulls");
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
    
    _values = new List<dynamic>(fields.length);
    for (int i = 0; i < fields.length; i++) {
      log.fine("$i: ${fields[i].name}");
      if (nullMap[i]) {
        log.fine("Value: null");
        _values[i] = null;
        continue;
      }
      switch (fields[i].type) {
        case FIELD_TYPE_BLOB:
          log.fine("BLOB");
          int len = buffer.readByte();
          _values[i] = buffer.readList(len);
          log.fine("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_TINY:
          log.fine("TINY");
          _values[i] = buffer.readByte();
          log.fine("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_SHORT:
          log.fine("SHORT");
          _values[i] = buffer.readInt16();
          log.fine("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_INT24:
          log.fine("INT24");
          _values[i] = buffer.readInt32();
          log.fine("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_LONG:
          log.fine("LONG");
          _values[i] = buffer.readInt32();
          log.fine("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_LONGLONG:
          log.fine("LONGLONG");
          _values[i] = buffer.readInt64();
          log.fine("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_NEWDECIMAL:
          log.fine("NEWDECIMAL");
          int len = buffer.readByte();
          String num = buffer.readString(len);
           _values[i] = double.parse(num);
          log.fine("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_FLOAT:
          log.fine("FLOAT");
          _values[i] = buffer.readFloat();
          log.fine("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_DOUBLE:
          log.fine("DOUBLE");
          _values[i] = buffer.readDouble();
          log.fine("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_BIT:
          log.fine("BIT");
          int len = buffer.readByte();
          // TODO should this be returned as a list, or an arbitrarily long number?
          _values[i] = buffer.readList(len);
          log.fine("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_DATETIME:
        case FIELD_TYPE_DATE:
        case FIELD_TYPE_TIMESTAMP:
          log.fine("DATE/DATETIME");
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
            year = date[0] + (date[1] << 0x08);
            month = date[2];
            day = date[3];
            if (date.length > 4) {
              hours = date[4];
              minutes = date[5];
              seconds = date[6];
              if (date.length > 7) {
                billionths = date[7] + (date[8] << 0x08)
                    + (date[9] << 0x10) + (date[10] << 0x18);
              }
            }
          }
          
          _values[i] = new Date(year, month, day, hours, minutes, seconds, (billionths / 1000000).toInt());
          log.fine("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_TIME:
          log.fine("TIME");
          int len = buffer.readByte();
          List<int> time = buffer.readList(len);
          
          int sign = 1;
          int days = 0;
          int hours = 0;
          int minutes = 0;
          int seconds = 0;
          int billionths = 0;
          
          log.fine("time: $time");
          if (time.length > 0) {
            sign = time[0] == 1 ? -1 : 1;
            days = time[1] + (time[2] << 0x08) + (time[3] << 0x10) + (time[4] << 0x18);
            hours = time[5];
            minutes = time[6];
            seconds = time[7];
            if (time.length > 8) {
              billionths = time[8] + (time[9] << 0x08) + (time[10] << 0x10) + (time[11] << 0x18);
            }
          }
          _values[i] = new Duration(days: days * sign, hours: hours * sign, minutes: minutes * sign, 
              seconds: seconds * sign, milliseconds: (billionths / 1000000).toInt() * sign);
          break;
        case FIELD_TYPE_YEAR:
          log.fine("YEAR");
          _values[i] = buffer.readInt16();
          log.fine("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_STRING:
          log.fine("STRING");
          _values[i] = buffer.readLengthCodedString();
          log.fine("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_VAR_STRING:
          log.fine("STRING");
          _values[i] = buffer.readLengthCodedString();
          log.fine("Value: ${_values[i]}");
          break;
        case FIELD_TYPE_GEOMETRY:
          log.fine("GEOMETRY - not implemented");
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
          log.fine("Field type not implemented yet ${fields[i].type}");
          log.fine(buffer.readList(8).toString());
          break;
        default:
          log.fine("Unsupported field type ${fields[i].type}");
          break;
      }
    }
  }
  
  String toString() => "Value: $_values";
}
