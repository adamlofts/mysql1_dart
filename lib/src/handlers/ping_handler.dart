part of sqljocky;

class _PingHandler extends Handler {
  _PingHandler() : super(new Logger("PingHandler"));

  Buffer createRequest() {
    log.finest("Creating buffer for PingHandler");
    var buffer = new Buffer(1);
    buffer.writeByte(COM_PING);
    return buffer;
  }
}
