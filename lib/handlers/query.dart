
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
