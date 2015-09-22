part of sqljocky;

class _StandardDataPacket extends Row {
  final List<dynamic> values;
  final Map<Symbol, int> _fieldIndex;

  _StandardDataPacket(Buffer buffer, List<_FieldImpl> fieldPackets, this._fieldIndex)
      : values = new List<dynamic>(fieldPackets.length) {
    for (var i = 0; i < fieldPackets.length; i++) {
      var list;
      int length = buffer.readLengthCodedBinary();
      if (length != null) {
        list = buffer.readList(length);
      } else {
        values[i] = null;
        continue;
      }
      switch (fieldPackets[i].type) {
        case FIELD_TYPE_TINY: // tinyint/bool
        case FIELD_TYPE_SHORT: // smallint
        case FIELD_TYPE_INT24: // mediumint
        case FIELD_TYPE_LONGLONG: // bigint/serial
        case FIELD_TYPE_LONG: // int
          var s = UTF8.decode(list);
          values[i] = int.parse(s);
          break;
        case FIELD_TYPE_NEWDECIMAL: // decimal
        case FIELD_TYPE_FLOAT: // float
        case FIELD_TYPE_DOUBLE: // double
          var s = UTF8.decode(list);
          values[i] = double.parse(s);
          break;
        case FIELD_TYPE_BIT: // bit
          var value = 0;
          for (var num in list) {
            value = (value << 8) + num;
          }
          values[i] = value;
          break;
        case FIELD_TYPE_DATE: // date
        case FIELD_TYPE_DATETIME: // datetime
        case FIELD_TYPE_TIMESTAMP: // timestamp
          var s = UTF8.decode(list);
          values[i] = DateTime.parse(s);
          break;
        case FIELD_TYPE_TIME: // time
          var s = UTF8.decode(list);
          var parts = s.split(":");
          values[i] = new Duration(
              days: 0,
              hours: int.parse(parts[0]),
              minutes: int.parse(parts[1]),
              seconds: int.parse(parts[2]),
              milliseconds: 0);
          break;
        case FIELD_TYPE_YEAR: // year
          var s = UTF8.decode(list);
          values[i] = int.parse(s);
          break;
        case FIELD_TYPE_STRING: // char/binary/enum/set
        case FIELD_TYPE_VAR_STRING: // varchar/varbinary
          var s = UTF8.decode(list);
          values[i] = s;
          break;
        case FIELD_TYPE_BLOB: // tinytext/text/mediumtext/longtext/tinyblob/mediumblob/blob/longblob
          values[i] = new Blob.fromBytes(list);
          break;
        case FIELD_TYPE_GEOMETRY: // geometry
          var s = UTF8.decode(list);
          values[i] = s;
          break;
      }
    }
  }

  _StandardDataPacket._forTests(this.values, this._fieldIndex);

  int get length => values.length;

  dynamic operator [](int index) => values[index];

  void operator []=(int index, dynamic value) {
    throw new UnsupportedError("Cannot modify row");
  }

  void set length(int newLength) {
    throw new UnsupportedError("Cannot set length of results");
  }

  noSuchMethod(Invocation invocation) {
    var name = invocation.memberName;
    if (invocation.isGetter) {
      var i = _fieldIndex[name];
      if (i != null) {
        return values[i];
      }
    }
    return super.noSuchMethod(invocation);
  }

  String toString() => "Value: $values";
}
