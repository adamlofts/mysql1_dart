part of sqljocky;

class _UseDbHandler extends _Handler {
  final String _dbName;
  
  _UseDbHandler(String this._dbName) {
    log = new Logger("UseDbHandler");
  }
  
  Buffer createRequest() {
    var buffer = new Buffer(_dbName.length + 1);
    buffer.writeByte(COM_INIT_DB);
    buffer.writeString(_dbName);
    return buffer;
  }

  _HandlerResponse processResponse(Buffer response) {
    var result = checkResponse(response);
    return new _HandlerResponse(true, null, result);
  }
}
