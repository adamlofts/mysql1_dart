part of sqljocky;

class _CloseStatementHandler extends _Handler {
  final int _handle;

  _CloseStatementHandler(int this._handle) {
    log = new Logger("CloseStatementHandler");
  }
  
  Buffer createRequest() {
    var buffer = new Buffer(5);
    buffer.writeByte(COM_STMT_CLOSE);
    buffer.writeInt32(_handle);
    return buffer;
  }

  _HandlerResponse processResponse(Buffer response) {
    var result = checkResponse(response);
    return new _HandlerResponse(finished: true, result: result);
  }
}
