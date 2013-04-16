part of sqljocky;

class _QueryHandler extends _Handler {
  static const int STATE_HEADER_PACKET = 0;
  static const int STATE_FIELD_PACKETS = 1;
  static const int STATE_ROW_PACKETS = 2;
  final String _sql;
  int _state = STATE_HEADER_PACKET;
  
  _OkPacket _okPacket;
  _ResultSetHeaderPacket _resultSetHeaderPacket;
  List<Field> _fieldPackets;
  List<_DataPacket> _dataPackets;
  
  _QueryHandler(String this._sql) {
    log = new Logger("QueryHandler");
    _fieldPackets = <Field>[];
    _dataPackets = <_DataPacket>[];
  }
  
  _Buffer createRequest() {
    var buffer = new _Buffer(_sql.length + 1);
    buffer.writeByte(COM_QUERY);
    buffer.writeString(_sql);
    return buffer;
  }
  
  dynamic processResponse(_Buffer response) {
    log.fine("Processing query response");
    var packet = checkResponse(response);
    if (packet == null) {
      if (response[0] == PACKET_EOF) {
        if (_state == STATE_FIELD_PACKETS) {
          _state = STATE_ROW_PACKETS;
        } else if (_state == STATE_ROW_PACKETS){
          _finished = true;
          
          return new Results._(_okPacket, _resultSetHeaderPacket, _fieldPackets, _dataPackets);
        }
      } else {
        switch (_state) {
        case STATE_HEADER_PACKET:
          _resultSetHeaderPacket = new _ResultSetHeaderPacket(response);
          log.fine (_resultSetHeaderPacket.toString());
          _state = STATE_FIELD_PACKETS;
          break;
        case STATE_FIELD_PACKETS:
          var fieldPacket = new Field._(response);
          log.fine(fieldPacket.toString());
          _fieldPackets.add(fieldPacket);
          break;
        case STATE_ROW_PACKETS:
          var dataPacket = new _StandardDataPacket(response, _fieldPackets);
          log.fine(dataPacket.toString());
          _dataPackets.add(dataPacket);
          break;
        }
      } 
    } else if (packet is _OkPacket) {
      _okPacket = packet;
      if ((packet.serverStatus & SERVER_MORE_RESULTS_EXISTS) == 0) {
        _finished = true;
      }
      
      return new Results._(_okPacket, _resultSetHeaderPacket, _fieldPackets, _dataPackets);
    }
  }
}
