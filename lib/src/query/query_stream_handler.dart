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
    var encoded = encodeUtf8(_sql);
    var buffer = new Buffer(encoded.length + 1);
    buffer.writeByte(COM_QUERY);
    buffer.writeList(encoded);
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
          return new _HandlerResponse(result: new _ResultsImpl(null, null, _fieldPackets, stream: _streamController.stream));
        } else if (_state == STATE_ROW_PACKETS) {
          // the connection's _handler field needs to have been nulled out before the stream is closed,
          // otherwise the stream will be reused in an unfinished state.
          // TODO: can we use Future.delayed elsewhere, to make reusing connections nicer?
          new Future.delayed(new Duration(seconds: 0), _streamController.close);
          return new _HandlerResponse(finished: true);
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
      // TODO: I think this is to do with multiple queries. Will probably break.
      if ((packet.serverStatus & SERVER_MORE_RESULTS_EXISTS) == 0) {
        finished = true;
      }

      //TODO is this finished value right?
      return new _HandlerResponse(finished: finished, result: new _ResultsImpl(_okPacket.insertId, _okPacket.affectedRows, _fieldPackets));
    }
    return _HandlerResponse.notFinished;
  }
}
