part of sqljocky;

class _StandardDataPacket implements _DataPacket {
  final List<dynamic> _values;
  
  List<dynamic> get values => _values;
  
  _StandardDataPacket(_Buffer buffer, List<Field> fieldPackets) :
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
