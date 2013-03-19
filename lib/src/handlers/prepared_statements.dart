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
    var buffer = new Buffer(_sql.length + 1);
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
          var fieldPacket = new Field(response);
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
          var fieldPacket = new Field(response);
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
    var buffer = new Buffer(5);
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
    var bytes = ((_values.length + 7) / 8).floor().toInt();
    var nullMap = new List<int>(bytes);
    var byte = 0;
    var bit = 0;
    for (var i = 0; i < _values.length; i++) {
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
    var types = <int>[];
    var values = <int>[];
    for (var i = 0; i < _values.length; i++) {
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

          var s = value.toString();
          types.add(FIELD_TYPE_VARCHAR);
          types.add(0);
          values.add(s.length);
          values.addAll(s.codeUnits);
          
          // TODO: if you send a double value for a decimal field, it doesn't like it
//          types.add(FIELD_TYPE_FLOAT);
//          types.add(0);
//          values.addAll(doubleToList(value));
        } else if (value is DateTime) { // TODO remove Date eventually
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
          var billionths = value.millisecond * 1000000;
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
        } else if (value is Blob) {
          log.fine("BLOB: $value");
          var bytes = (value as Blob).toBytes();
          types.add(FIELD_TYPE_BLOB);
          types.add(0);
          values.add(bytes.length);
          values.addAll(bytes);
        } else {
          log.fine("STRING: $value");
          var s = value.toString();
          types.add(FIELD_TYPE_VARCHAR);
          types.add(0);
          values.add(s.length);
          values.addAll(s.codeUnits);
        }
      }
    }
    
    var buffer = new Buffer(10 + nullMap.length + 1 + _values.length * 2 + values.length);
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
          var fieldPacket = new Field(response);
          log.fine(fieldPacket.toString());
          _fieldPackets.add(fieldPacket);
          break;
        case STATE_ROW_PACKETS:
          log.fine('Got a row packet');
          var dataPacket = new BinaryDataPacket(response, _fieldPackets);
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

  BinaryDataPacket._forTests() : log = new Logger("BinaryDataPacket");

  BinaryDataPacket(Buffer buffer, List<Field> fields) :
      log = new Logger("BinaryDataPacket") {
    buffer.skip(1);
    var nulls = buffer.readList(((fields.length + 7 + 2) / 8).floor().toInt());
    log.fine("Nulls: $nulls");
    var nullMap = new List<bool>(fields.length);
    var shift = 2;
    var byte = 0;
    for (var i = 0; i < fields.length; i++) {
      var mask = 1 << shift;
      nullMap[i] = (nulls[byte] & mask) != 0;
      shift++;
      if (shift > 7) {
        shift = 0;
        byte++;
      }
    }
    
    _values = new List<dynamic>(fields.length);
    for (var i = 0; i < fields.length; i++) {
      log.fine("$i: ${fields[i].name}");
      if (nullMap[i]) {
        log.fine("Value: null");
        _values[i] = null;
        continue;
      }
      var field = fields[i];
      _values[i] = _readField(field, buffer);
    }
  }

  _readField(Field field, Buffer buffer) {
    switch (field.type) {
      case FIELD_TYPE_BLOB:
        log.fine("BLOB");
        var len = buffer.readByte();
        var value = new Blob.fromBytes(buffer.readList(len));
        log.fine("Value: ${value}");
        return value;
      case FIELD_TYPE_TINY:
        log.fine("TINY");
        var value = buffer.readByte();
        log.fine("Value: ${value}");
        return value;
      case FIELD_TYPE_SHORT:
        log.fine("SHORT");
        var value = buffer.readInt16();
        log.fine("Value: ${value}");
        return value;
      case FIELD_TYPE_INT24:
        log.fine("INT24");
        var value = buffer.readInt32();
        log.fine("Value: ${value}");
        return value;
      case FIELD_TYPE_LONG:
        log.fine("LONG");
        var value = buffer.readInt32();
        log.fine("Value: ${value}");
        return value;
      case FIELD_TYPE_LONGLONG:
        log.fine("LONGLONG");
        var value = buffer.readInt64();
        log.fine("Value: ${value}");
        return value;
      case FIELD_TYPE_NEWDECIMAL:
        log.fine("NEWDECIMAL");
        var len = buffer.readByte();
        var num = buffer.readString(len);
        var value = double.parse(num);
        log.fine("Value: ${value}");
        return value;
      case FIELD_TYPE_FLOAT:
        log.fine("FLOAT");
        var value = buffer.readFloat();
        log.fine("Value: ${value}");
        return value;
      case FIELD_TYPE_DOUBLE:
        log.fine("DOUBLE");
        var value = buffer.readDouble();
        log.fine("Value: ${value}");
        return value;
      case FIELD_TYPE_BIT:
        log.fine("BIT");
        var len = buffer.readByte();
        var list = buffer.readList(len);
        var value = 0;
        for (var num in list) {
          value = (value << 8) + num;
        }
        log.fine("Value: ${value}");
        return value;
      case FIELD_TYPE_DATETIME:
      case FIELD_TYPE_DATE:
      case FIELD_TYPE_TIMESTAMP:
        log.fine("DATE/DATETIME");
        var len = buffer.readByte();
        var date = buffer.readList(len);
        var year = 0;
        var month = 0;
        var day = 0;
        var hours = 0;
        var minutes = 0;
        var seconds = 0;
        var billionths = 0;

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

        var value = new DateTime(year, month, day, hours, minutes, seconds, billionths ~/ 1000000);
        log.fine("Value: ${value}");
        return value;
      case FIELD_TYPE_TIME:
        log.fine("TIME");
        var len = buffer.readByte();
        var time = buffer.readList(len);

        var sign = 1;
        var days = 0;
        var hours = 0;
        var minutes = 0;
        var seconds = 0;
        var billionths = 0;

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
        var value = new Duration(
            days: days * sign,
            hours: hours * sign,
            minutes: minutes * sign,
            seconds: seconds * sign,
            milliseconds: (billionths ~/ 1000000) * sign);
        return value;
      case FIELD_TYPE_YEAR:
        log.fine("YEAR");
        var value = buffer.readInt16();
        log.fine("Value: ${value}");
        return value;
      case FIELD_TYPE_STRING:
        log.fine("STRING");
        var value = buffer.readLengthCodedString();
        log.fine("Value: ${value}");
        return value;
      case FIELD_TYPE_VAR_STRING:
        log.fine("STRING");
        var value = buffer.readLengthCodedString();
        log.fine("Value: ${value}");
        return value;
      case FIELD_TYPE_GEOMETRY:
        log.fine("GEOMETRY - not implemented");
        var len = buffer.readByte();
        //TODO
        var value = buffer.readList(len);
        return value;
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
        log.fine("Field type not implemented yet ${field.type}");
        log.fine(buffer.readList(8).toString());
        break;
      default:
        log.fine("Unsupported field type ${field.type}");
        break;
    }
    return null;
  }

  String toString() => "Value: $_values";
}
