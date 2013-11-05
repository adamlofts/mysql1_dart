part of sqljocky;

class _UseDbHandler extends _Handler {
  final String _dbName;
  
  _UseDbHandler(String this._dbName) {
    log = new Logger("UseDbHandler");
  }
  
  Buffer createRequest() {
    var encoded = UTF8.encode(_dbName);
    var buffer = new Buffer(encoded.length + 1);
    buffer.writeByte(COM_INIT_DB);
    buffer.writeList(encoded);
    return buffer;
  }
}
