part of sqljocky;

class _ResultSetHeaderPacket {
  int _fieldCount;
  int _extra;
  Logger log;
  
  int get fieldCount => _fieldCount;
  
  _ResultSetHeaderPacket(Buffer buffer) {
    log = new Logger("ResultSetHeaderPacket");
    _fieldCount = buffer.readLengthCodedBinary();
    if (buffer.canReadMore()) {
      _extra = buffer.readLengthCodedBinary();
    }
  }
  
  String toString() => "Field count: $_fieldCount, Extra: $_extra";
}
