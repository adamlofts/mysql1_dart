part of sqljocky;

class _CloseStatementHandler extends Handler {
  final int _handle;

  _CloseStatementHandler(int this._handle) : super(new Logger("CloseStatementHandler"));

  Buffer createRequest() {
    var buffer = new Buffer(5);
    buffer.writeByte(COM_STMT_CLOSE);
    buffer.writeUint32(_handle);
    return buffer;
  }
}
