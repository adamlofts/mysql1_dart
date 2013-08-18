part of sqljocky;

class _OkPacket {
  int _affectedRows;
  int _insertId;
  int _serverStatus;
  String _message;
  
  int get affectedRows => _affectedRows;
  int get insertId => _insertId;
  int get serverStatus => _serverStatus;
  String get message => _message;
  
  _OkPacket(Buffer buffer) {
    buffer.seek(1);
    _affectedRows = buffer.readLengthCodedBinary();
    _insertId = buffer.readLengthCodedBinary();
    _serverStatus = buffer.readUint16();
    _message = buffer.readStringToEnd();
  }
  
  String toString() => "OK: affected rows: $affectedRows, insert id: $insertId, server status: $serverStatus, message: $message";
}
