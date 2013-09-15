part of sqljocky;

class _ExecuteQueryHandler extends _Handler {
  static const int STATE_HEADER_PACKET = 0;
  static const int STATE_FIELD_PACKETS = 1;
  static const int STATE_ROW_PACKETS = 2;
  
  int _state = STATE_HEADER_PACKET;

  _ResultSetHeaderPacket _resultSetHeaderPacket;
  List<_FieldImpl> _fieldPackets;
  StreamController<Row> _streamController;

  final _PreparedQuery _preparedQuery;
  final List _values;
  _OkPacket _okPacket;
  bool _executed;
  
  _ExecuteQueryHandler(_PreparedQuery this._preparedQuery, bool this._executed,
    List this._values) {
    _fieldPackets = <_FieldImpl>[];
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
    var values = new ListWriter(<int>[]);
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
          var encoded = encodeUtf8(s);
          values.writeLengthCodedBinary(encoded.length);
          values.writeList(encoded);
          
          // TODO: if you send a double value for a decimal field, it doesn't like it
//          types.add(FIELD_TYPE_FLOAT);
//          types.add(0);
//          values.addAll(doubleToList(value));
        } else if (value is DateTime) { // TODO remove Date eventually
          log.fine("DATE: $value");
          types.add(FIELD_TYPE_DATETIME);
          types.add(0);
          values.add(7);
          values.add(value.year >> 0x00 & 0xFF);
          values.add(value.year >> 0x08 & 0xFF);
          values.add(value.month);
          values.add(value.day);
          values.add(value.hour);
          values.add(value.minute);
          values.add(value.second);
//          var billionths = value.millisecond * 1000000;
//          values.add(billionths >> 0x00 & 0xFF); 
//          values.add(billionths >> 0x08 & 0xFF); 
//          values.add(billionths >> 0x10 & 0xFF); 
//          values.add(billionths >> 0x18 & 0xFF);
        } else if (value is bool) {
          log.fine("BOOL: $value");
          types.add(FIELD_TYPE_TINY);
          types.add(0);
          values.add(value ? 1 : 0);
        } else if (value is List<int>) {
          log.fine("LIST: $value");
          types.add(FIELD_TYPE_BLOB);
          types.add(0);
          values.writeLengthCodedBinary(value.length);
          values.writeList(value);
        } else if (value is Blob) {
          log.fine("BLOB: $value");
          var bytes = (value as Blob).toBytes();
          types.add(FIELD_TYPE_BLOB);
          types.add(0);
          values.writeLengthCodedBinary(bytes.length);
          values.writeList(bytes);
        } else {
          log.fine("STRING: $value");
          var s = value.toString();
          types.add(FIELD_TYPE_VARCHAR);
          types.add(0);
          var encoded = encodeUtf8(s);
          values.writeLengthCodedBinary(encoded.length);
          values.writeList(encoded);
        }
      } else {
        types.add(FIELD_TYPE_NULL);
        types.add(0);
      }
    }
    
    var buffer = new Buffer(10 + nullMap.length + 1 + _values.length * 2 + values.list.length);
    buffer.writeByte(COM_STMT_EXECUTE);
    buffer.writeUint32(_preparedQuery.statementHandlerId);
    buffer.writeByte(0);
    buffer.writeUint32(1);
    buffer.writeList(nullMap);
    if (!_executed) {
      buffer.writeByte(1);
      buffer.writeList(types);
      buffer.writeList(values.list);
    } else {
      buffer.writeByte(0);      
    }
//    log.fine(Buffer.listChars(buffer._list));
    return buffer;
  }

  _HandlerResponse processResponse(Buffer response) {
    var packet;
    if (_state == STATE_HEADER_PACKET) {
      packet = checkResponse(response);
    }
    if (packet == null) {
      if (response[0] == PACKET_EOF) {
        log.fine('Got an EOF');
        if (_state == STATE_FIELD_PACKETS) {
          _state = STATE_ROW_PACKETS;
          _streamController = new StreamController<Row>();
          return new _HandlerResponse(result: new _ResultsImpl(null, null, _fieldPackets, stream: _streamController.stream));
        } else if (_state == STATE_ROW_PACKETS){
          _streamController.close();
          return new _HandlerResponse(finished: true);
        }
      } else {
        switch (_state) {
        case STATE_HEADER_PACKET:
          log.fine('Got a header packet');
          _resultSetHeaderPacket = new _ResultSetHeaderPacket(response);
          log.fine(_resultSetHeaderPacket.toString());
          _state = STATE_FIELD_PACKETS;
          break;
        case STATE_FIELD_PACKETS:
          log.fine('Got a field packet');
          var fieldPacket = new _FieldImpl._(response);
          log.fine(fieldPacket.toString());
          _fieldPackets.add(fieldPacket);
          break;
        case STATE_ROW_PACKETS:
          log.fine('Got a row packet');
          var dataPacket = new _BinaryDataPacket(response, _fieldPackets);
          log.fine(dataPacket.toString());
          _streamController.add(dataPacket);
          break;
        }
      }
    } else if (packet is _OkPacket) {
      _okPacket = packet;
      if ((packet.serverStatus & SERVER_MORE_RESULTS_EXISTS) == 0) {
        return new _HandlerResponse(finished: true, result: new _ResultsImpl(_okPacket.insertId, _okPacket.affectedRows, null));
      }
    }
    return _HandlerResponse.notFinished;
  }
}
