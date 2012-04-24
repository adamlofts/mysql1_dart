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
  
  String toString() => "Field count: $_fieldCount, Extra: $_extra";
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
  
  String toString() => "Catalog: $_catalog, DB: $_db, Table: $_table, Org Table: $_orgTable, " 
       "Name: $_name, Org Name: $_orgName, Character Set: $_characterSet, "
       "Length: $_length, Type: $_type, Flags: $_flags, Decimals: $_decimals, "
       "Default Value: $_defaultValue";
}



interface DataPacket default DataPacketImpl {
  List<Dynamic> get values();
  DataPacket(Buffer buffer, List<FieldPacket> fieldPackets);
}

class DataPacketImpl implements DataPacket {
  final List<Dynamic> _values;
  
  List<Dynamic> get values() => _values;
  
  DataPacketImpl(Buffer buffer, List<FieldPacket> fieldPackets) :
      _values = new List<Dynamic>(fieldPackets.length) {
    for (int i = 0; i < fieldPackets.length; i++) {
      String s = buffer.readLengthCodedString();
      if (s == null) {
        _values[i] = null;
        continue;
      }
      switch (fieldPackets[i].type) {
        case FIELD_TYPE_TINY: // tinyint/bool
        case FIELD_TYPE_SHORT: // smallint
        case FIELD_TYPE_INT24: // mediumint
        case FIELD_TYPE_LONGLONG: // bigint/serial
        case FIELD_TYPE_LONG: // int
          _values[i] = Math.parseInt(s);
          break;
        case FIELD_TYPE_NEWDECIMAL: // decimal
        case FIELD_TYPE_FLOAT: // float
        case FIELD_TYPE_DOUBLE: // double
          _values[i] = Math.parseDouble(s);
          break;
        case FIELD_TYPE_BIT: // bit
          ByteArray b = new ByteArray(s.length);
          b.setRange(0, s.length, s.charCodes());
          _values[i] = b;
          break;
        case FIELD_TYPE_DATE: // date
        case FIELD_TYPE_DATETIME: // datetime
        case FIELD_TYPE_TIMESTAMP: // timestamp
          _values[i] = new Date.fromString(s);
          break;
        case FIELD_TYPE_TIME: // time
          List<String> parts = s.split(":");
          _values[i] = new Duration(0, Math.parseInt(parts[0]),
            Math.parseInt(parts[1]), Math.parseInt(parts[2]), 0);
          break;
        case FIELD_TYPE_YEAR: // year
          _values[i] = Math.parseInt(s);
          break;
        case FIELD_TYPE_STRING: // char/binary/enum/set
        case FIELD_TYPE_VAR_STRING: // varchar/varbinary
          _values[i] = s;
          break;
        case FIELD_TYPE_BLOB: // tinytext/text/mediumtext/longtext/tinyblob/mediumblob/blob/longblob
          ByteArray b = new ByteArray(s.length);
          b.setRange(0, s.length, s.charCodes());
          _values[i] = b;
          break;
        case FIELD_TYPE_GEOMETRY: // geometry
          _values[i] = s;
          break;
      }
    }
  }
  
  String toString() => "Value: $_values";
}

class QueryHandler extends Handler {
  static final int STATE_HEADER_PACKET = 0;
  static final int STATE_FIELD_PACKETS = 1;
  static final int STATE_ROW_PACKETS = 2;
  final String _sql;
  int _state = STATE_HEADER_PACKET;
  
  OkPacket _okPacket;
  ResultSetHeaderPacket _resultSetHeaderPacket;
  List<FieldPacket> _fieldPackets;
  List<DataPacket> _dataPackets;
  
  QueryHandler(String this._sql) {
    log = new Log("QueryHandler");
    _fieldPackets = <FieldPacket>[];
    _dataPackets = <DataPacket>[];
  }
  
  Buffer createRequest() {
    Buffer buffer = new Buffer(_sql.length + 1);
    buffer.writeByte(COM_QUERY);
    buffer.writeString(_sql);
    return buffer;
  }
  
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
          DataPacket dataPacket = new DataPacket(response, _fieldPackets);
          log.debug(dataPacket.toString());
          _dataPackets.add(dataPacket);
          break;
        }
      } 
    } else if (packet is OkPacket) {
      _okPacket = packet;
      if ((packet.serverStatus & SERVER_MORE_RESULTS_EXISTS) == 0) {
        _finished = true;
      }
    }
  }
}
