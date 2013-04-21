part of sqljocky;

class _PrepareHandler extends _Handler {
  final String _sql;
  _PrepareOkPacket _okPacket;
  int _parametersToRead;
  int _columnsToRead;
  List<Field> _parameters;
  List<Field> _columns;
  
  String get sql => _sql;
  _PrepareOkPacket get okPacket => _okPacket;
  List<Field> get parameters => _parameters;
  List<Field> get columns => _columns;
  
  _PrepareHandler(String this._sql) {
    log = new Logger("PrepareHandler");
  }
  
  _Buffer createRequest() {
    var buffer = new _Buffer(_sql.length + 1);
    buffer.writeByte(COM_STMT_PREPARE);
    buffer.writeString(_sql);
    return buffer;
  }
  
  dynamic processResponse(_Buffer response) {
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
          var fieldPacket = new Field._(response);
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
          var fieldPacket = new Field._(response);
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
      return new _PreparedQuery(this);
    }
  }
}
