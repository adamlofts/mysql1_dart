part of sqljocky;

class _PrepareHandler extends _Handler {
  final String _sql;
  _PrepareOkPacket _okPacket;
  int _parametersToRead;
  int _columnsToRead;
  List<_FieldImpl> _parameters;
  List<_FieldImpl> _columns;
  
  String get sql => _sql;
  _PrepareOkPacket get okPacket => _okPacket;
  List<_FieldImpl> get parameters => _parameters;
  List<_FieldImpl> get columns => _columns;
  
  _PrepareHandler(String this._sql) {
    log = new Logger("PrepareHandler");
  }
  
  Buffer createRequest() {
    var encoded = UTF8.encode(_sql);
    var buffer = new Buffer(encoded.length + 1);
    buffer.writeByte(COM_STMT_PREPARE);
    buffer.writeList(encoded);
    return buffer;
  }

  _HandlerResponse processResponse(Buffer response) {
    log.fine("Prepare processing response");
    var packet = checkResponse(response, true);
    if (packet == null) {
      log.fine('Not an OK packet, params to read: $_parametersToRead');
      if (_parametersToRead > -1) {
        if (response[0] == PACKET_EOF) {
          log.fine("EOF");
          if (_parametersToRead != 0) {
            throw new MySqlProtocolError._("Unexpected EOF packet; was expecting another $_parametersToRead parameter(s)");
          }
        } else {
          var fieldPacket = new _FieldImpl._(response);
          log.fine("field packet: $fieldPacket");
          _parameters[_okPacket.parameterCount - _parametersToRead] = fieldPacket;
        }
        _parametersToRead--;
      } else if (_columnsToRead > -1) {
        if (response[0] == PACKET_EOF) {
          log.fine("EOF");
          if (_columnsToRead != 0) {
            throw new MySqlProtocolError._("Unexpected EOF packet; was expecting another $_columnsToRead column(s)");
          }
        } else {
          var fieldPacket = new _FieldImpl._(response);
          log.fine("field packet (column): $fieldPacket");
          _columns[_okPacket.columnCount - _columnsToRead] = fieldPacket;
        }
        _columnsToRead--;
      }
    } else if (packet is _PrepareOkPacket) {
      log.fine(packet.toString());
      _okPacket = packet;
      _parametersToRead = packet.parameterCount;
      _columnsToRead = packet.columnCount;
      _parameters = new List<_FieldImpl>(_parametersToRead);
      _columns = new List<_FieldImpl>(_columnsToRead);
      if (_parametersToRead == 0) {
        _parametersToRead = -1;
      }
      if (_columnsToRead == 0) {
        _columnsToRead = -1;
      }
    }
    
    if (_parametersToRead == -1 && _columnsToRead == -1) {
      log.fine("finished");
      return new _HandlerResponse(finished: true, result: new _PreparedQuery(this));
    }
    return _HandlerResponse.notFinished;
  }
}
