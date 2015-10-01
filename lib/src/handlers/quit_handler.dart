part of sqljocky;

class _QuitHandler extends Handler {
  _QuitHandler() : super(new Logger("QuitHandler"));

  Buffer createRequest() {
    var buffer = new Buffer(1);
    buffer.writeByte(COM_QUIT);
    return buffer;
  }

  dynamic processResponse(Buffer response) {
    throw createMySqlProtocolError("Shouldn't have received a response after sending a QUIT message");
  }
}
