part of sqljocky;

class _DebugHandler extends Handler {
  _DebugHandler() : super(new Logger("DebugHandler"));

  Buffer createRequest() {
    var buffer = new Buffer(1);
    buffer.writeByte(COM_DEBUG);
    return buffer;
  }
}
