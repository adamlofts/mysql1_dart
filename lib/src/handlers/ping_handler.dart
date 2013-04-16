part of sqljocky;

class _PingHandler extends _Handler {
  _PingHandler() {
    log = new Logger("PingHandler");
  }
  
  _Buffer createRequest() {
    var buffer = new _Buffer(1);
    buffer.writeByte(COM_PING);
    return buffer;
  }
  
  dynamic processResponse(_Buffer response) {
    checkResponse(response);
    _finished = true;
  }
}
