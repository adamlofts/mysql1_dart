part of sqljocky;

class _UseDbHandler extends _Handler {
  final String _dbName;
  
  _UseDbHandler(String this._dbName) {
    log = new Logger("UseDbHandler");
  }
  
  _Buffer createRequest() {
    var buffer = new _Buffer(_dbName.length + 1);
    buffer.writeByte(COM_INIT_DB);
    buffer.writeString(_dbName);
    return buffer;
  }
  
  dynamic processResponse(_Buffer response) {
    checkResponse(response);
    _finished = true;
  }
}
