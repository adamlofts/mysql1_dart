part of sqljocky;

class _CloseStatementHandler extends _Handler {
  final int _handle;

  _CloseStatementHandler(int this._handle) {
    log = new Logger("CloseStatementHandler");
  }
  
  _Buffer createRequest() {
    var buffer = new _Buffer(5);
    buffer.writeByte(COM_STMT_CLOSE);
    buffer.writeInt32(_handle);
    return buffer;
  }
  
  dynamic processResponse(_Buffer response) {
    checkResponse(response);
    _finished = true;
  }
}
