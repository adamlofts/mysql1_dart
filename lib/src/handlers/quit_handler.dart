part of sqljocky;

class _QuitHandler extends _Handler {
  _QuitHandler() {
    log = new Logger("QuitHandler");
  }
  
  Buffer createRequest() {
    var buffer = new Buffer(1);
    buffer.writeByte(COM_QUIT);
    return buffer;
  }
  
  dynamic processResponse(Buffer response) {
    throw new MySqlProtocolError._("Shouldn't have received a response after sending a QUIT message");
  }
}
