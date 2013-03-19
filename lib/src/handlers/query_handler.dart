part of handlers_lib;

class ResultSetHeaderPacket {
  int _fieldCount;
  int _extra;
  Logger log;
  
  int get fieldCount => _fieldCount;
  
  ResultSetHeaderPacket(Buffer buffer) {
    log = new Logger("ResultSetHeaderPacket");
    _fieldCount = buffer.readLengthCodedBinary();
    if (buffer.canReadMore()) {
      _extra = buffer.readLengthCodedBinary();
    }
  }
  
  String toString() => "Field count: $_fieldCount, Extra: $_extra";
}

class Field {
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
  
  String get name => _name;
  String get table => _table;
  String get catalog => _catalog;
  String get orgName => _orgName;
  String get orgTable => _orgTable;
  String get db => _db;
  int get characterSet => _characterSet;
  int get length => _length;
  int get type => _type;
  int get flags => _flags;
  int get decimals => _decimals;
  int get defaultValue => _defaultValue;

  Field._forTests(this._type);

  Field(Buffer buffer) {
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



abstract class DataPacket {
  List<dynamic> get values;
  DataPacket(Buffer buffer, List<Field> fieldPackets);
}

class StandardDataPacket implements DataPacket {
  final List<dynamic> _values;
  
  List<dynamic> get values => _values;
  
  StandardDataPacket(Buffer buffer, List<Field> fieldPackets) :
      _values = new List<dynamic>(fieldPackets.length) {
    for (var i = 0; i < fieldPackets.length; i++) {
      var s = buffer.readLengthCodedString();
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
          _values[i] = int.parse(s);
          break;
        case FIELD_TYPE_NEWDECIMAL: // decimal
        case FIELD_TYPE_FLOAT: // float
        case FIELD_TYPE_DOUBLE: // double
          _values[i] = double.parse(s);
          break;
        case FIELD_TYPE_BIT: // bit
          var value = 0;
          for (var num in s.codeUnits) {
            value = (value << 8) + num;
          }
          _values[i] = value;
          break;
        case FIELD_TYPE_DATE: // date
        case FIELD_TYPE_DATETIME: // datetime
        case FIELD_TYPE_TIMESTAMP: // timestamp
          _values[i] = DateTime.parse(s);
          break;
        case FIELD_TYPE_TIME: // time
          var parts = s.split(":");
          _values[i] = new Duration(days: 0, hours: int.parse(parts[0]),
            minutes: int.parse(parts[1]), seconds: int.parse(parts[2]), 
            milliseconds: 0);
          break;
        case FIELD_TYPE_YEAR: // year
          _values[i] = int.parse(s);
          break;
        case FIELD_TYPE_STRING: // char/binary/enum/set
        case FIELD_TYPE_VAR_STRING: // varchar/varbinary
          _values[i] = s;
          break;
        case FIELD_TYPE_BLOB: // tinytext/text/mediumtext/longtext/tinyblob/mediumblob/blob/longblob
          var b = new Uint8List(s.length);
          b.setRange(0, s.length, s.codeUnits);
          _values[i] = new Blob.fromString(s);
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
  static const int STATE_HEADER_PACKET = 0;
  static const int STATE_FIELD_PACKETS = 1;
  static const int STATE_ROW_PACKETS = 2;
  final String _sql;
  int _state = STATE_HEADER_PACKET;
  
  OkPacket _okPacket;
  ResultSetHeaderPacket _resultSetHeaderPacket;
  List<Field> _fieldPackets;
  List<DataPacket> _dataPackets;
  
  QueryHandler(String this._sql) {
    log = new Logger("QueryHandler");
    _fieldPackets = <Field>[];
    _dataPackets = <DataPacket>[];
  }
  
  Buffer createRequest() {
    var buffer = new Buffer(_sql.length + 1);
    buffer.writeByte(COM_QUERY);
    buffer.writeString(_sql);
    return buffer;
  }
  
  dynamic processResponse(Buffer response) {
    log.fine("Processing query response");
    var packet = checkResponse(response);
    if (packet == null) {
      if (response[0] == PACKET_EOF) {
        if (_state == STATE_FIELD_PACKETS) {
          _state = STATE_ROW_PACKETS;
        } else if (_state == STATE_ROW_PACKETS){
          _finished = true;
          
          return new Results(_okPacket, _resultSetHeaderPacket, _fieldPackets, _dataPackets);
        }
      } else {
        switch (_state) {
        case STATE_HEADER_PACKET:
          _resultSetHeaderPacket = new ResultSetHeaderPacket(response);
          log.fine (_resultSetHeaderPacket.toString());
          _state = STATE_FIELD_PACKETS;
          break;
        case STATE_FIELD_PACKETS:
          var fieldPacket = new Field(response);
          log.fine(fieldPacket.toString());
          _fieldPackets.add(fieldPacket);
          break;
        case STATE_ROW_PACKETS:
          var dataPacket = new StandardDataPacket(response, _fieldPackets);
          log.fine(dataPacket.toString());
          _dataPackets.add(dataPacket);
          break;
        }
      } 
    } else if (packet is OkPacket) {
      _okPacket = packet;
      if ((packet.serverStatus & SERVER_MORE_RESULTS_EXISTS) == 0) {
        _finished = true;
      }
      
      return new Results(_okPacket, _resultSetHeaderPacket, _fieldPackets, _dataPackets);
    }
  }
}
