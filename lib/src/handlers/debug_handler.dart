part of sqljocky;

class _DebugHandler extends _Handler {
  _DebugHandler() {
    log = new Logger("DebugHandler");
  }
  
  _Buffer createRequest() {
    var buffer = new _Buffer(1);
    buffer.writeByte(COM_DEBUG);
    return buffer;
  }
  
  dynamic processResponse(_Buffer response) {
    checkResponse(response);
    _finished = true;
  }
}
