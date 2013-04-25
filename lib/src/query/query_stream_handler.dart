part of sqljocky;

class _QueryStreamHandler extends _Handler {
  static const int STATE_HEADER_PACKET = 0;
  static const int STATE_FIELD_PACKETS = 1;
  static const int STATE_ROW_PACKETS = 2;
  final String _sql;
  int _state = STATE_HEADER_PACKET;
  
  _OkPacket _okPacket;
  _ResultSetHeaderPacket _resultSetHeaderPacket;
  List<_FieldImpl> _fieldPackets;

  StreamController<Row> _streamController;
  
  _QueryStreamHandler(String this._sql) {
    log = new Logger("QueryStreamHandler");
    _fieldPackets = <_FieldImpl>[];
  }
  
  Buffer createRequest() {
    var buffer = new Buffer(_sql.length + 1);
    buffer.writeByte(COM_QUERY);
    buffer.writeString(_sql);
    return buffer;
  }

  _HandlerResponse processResponse(Buffer response) {
    log.fine("Processing query response");
    var packet = checkResponse(response);
    if (packet == null) {
      if (response[0] == PACKET_EOF) {
        if (_state == STATE_FIELD_PACKETS) {
          _state = STATE_ROW_PACKETS;
          _streamController = new StreamController<Row>();
          return new _HandlerResponse(false, null, new _ResultsImpl._(null, null, _fieldPackets, null, _streamController.stream));
        } else if (_state == STATE_ROW_PACKETS) {
          _streamController.close();
          return new _HandlerResponse(true, null);
        }
      } else {
        switch (_state) {
        case STATE_HEADER_PACKET:
          _resultSetHeaderPacket = new _ResultSetHeaderPacket(response);
          log.fine (_resultSetHeaderPacket.toString());
          _state = STATE_FIELD_PACKETS;
          break;
        case STATE_FIELD_PACKETS:
          var fieldPacket = new _FieldImpl._(response);
          log.fine(fieldPacket.toString());
          _fieldPackets.add(fieldPacket);
          break;
        case STATE_ROW_PACKETS:
          var dataPacket = new _StandardDataPacket(response, _fieldPackets);
          log.fine(dataPacket.toString());
          _streamController.add(dataPacket);
          break;
        }
      } 
    } else if (packet is _OkPacket) {
      _okPacket = packet;
      var finished = false;
      if ((packet.serverStatus & SERVER_MORE_RESULTS_EXISTS) == 0) {
        finished = true;
      }

      //TODO is this finished value right?
      return new _HandlerResponse(finished, null, new _ResultsImpl._(_okPacket.insertId, _okPacket.affectedRows, _fieldPackets, null));
    }
    return _HandlerResponse.notFinished;
  }
}
