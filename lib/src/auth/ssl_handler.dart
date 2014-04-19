part of sqljocky;

class _SSLHandler extends _Handler {
  final int _clientFlags;
  final int _maxPacketSize;
  final int _characterSet;
  final _Handler _handler;
  
  _Handler get nextHandler => _handler;
  
  _SSLHandler(this._clientFlags, this._maxPacketSize, this._characterSet, this._handler) {
    log = new Logger("SSLHandler");
  }
  
  Buffer createRequest() {
    var buffer = new Buffer(32);
    buffer.seekWrite(0);
    buffer.writeUint32(_clientFlags);
    buffer.writeUint32(_maxPacketSize);
    buffer.writeByte(_characterSet);
    buffer.fill(23, 0);
    
    return buffer;
  }
}
