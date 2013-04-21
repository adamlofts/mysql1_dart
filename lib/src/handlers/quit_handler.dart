part of sqljocky;

class _QuitHandler extends _Handler {
  _QuitHandler() {
    log = new Logger("QuitHandler");
  }
  
  _Buffer createRequest() {
    var buffer = new _Buffer(1);
    buffer.writeByte(COM_QUIT);
    return buffer;
  }
  
  dynamic processResponse(_Buffer response) {
    throw new MySqlProtocolError("Shouldn't have received a response after sending a QUIT message");
  }
}
